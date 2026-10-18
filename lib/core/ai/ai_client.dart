import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiException implements Exception {
  const AiException(this.message, {this.statusCode, this.retryable = false});
  final String message;
  final int? statusCode;
  final bool retryable;
  @override
  String toString() => statusCode == null ? message : '$message ($statusCode)';
}

class AiUsage {
  const AiUsage(this.promptTokens, this.completionTokens);
  final int promptTokens, completionTokens;
}

/// A picture sent with the user turn to a vision-capable model.
class AiImage {
  const AiImage(this.bytes, {this.mimeType = 'image/jpeg'});
  final List<int> bytes;
  final String mimeType;

  String get dataUrl => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

class AiReply {
  const AiReply(this.json, this.usage);
  final Map<String, dynamic> json;
  final AiUsage usage;
}

/// Minimal client for any OpenAI-compatible `/chat/completions` endpoint
/// (DeepSeek, OpenRouter, Groq, Gemini's compatibility layer, local servers).
class AiClient {
  AiClient({
    required this.httpClient,
    required String baseUrl,
    required this.apiKey,
    required this.model,
    this.jsonMode = true,
    this.timeout = const Duration(seconds: 25),
    this.retryDelay = const Duration(milliseconds: 1500),
  }) : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final http.Client httpClient;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool jsonMode;
  final Duration timeout;
  final Duration retryDelay;

  Uri get _endpoint => Uri.parse(
    baseUrl.endsWith('/chat/completions')
        ? baseUrl
        : '$baseUrl/chat/completions',
  );

  /// Sends one system + user turn and returns the reply parsed as a JSON
  /// object. Retries once on rate limits and server errors, and once without
  /// JSON mode when a provider rejects `response_format`. [images] go in the
  /// user turn as OpenAI-style `image_url` parts; the model must accept
  /// images. [timeout] overrides the client's for slow, long replies.
  Future<AiReply> completeJson({
    required String system,
    required String user,
    List<AiImage> images = const [],
    Duration? timeout,
  }) async {
    var useJsonMode = jsonMode;
    for (var attempt = 0; ; attempt++) {
      try {
        return await _send(
          system,
          user,
          images,
          useJsonMode,
          timeout ?? this.timeout,
        );
      } on AiException catch (e) {
        if (useJsonMode &&
            e.statusCode == 400 &&
            e.message.contains('response_format')) {
          useJsonMode = false;
          continue;
        }
        if (!e.retryable || attempt >= 1) rethrow;
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  Future<AiReply> _send(
    String system,
    String user,
    List<AiImage> images,
    bool useJsonMode,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              'X-Title': 'Flourish',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0,
              'messages': [
                {'role': 'system', 'content': system},
                {
                  'role': 'user',
                  'content': images.isEmpty
                      ? user
                      : [
                          {'type': 'text', 'text': user},
                          for (final image in images)
                            {
                              'type': 'image_url',
                              'image_url': {'url': image.dataUrl},
                            },
                        ],
                },
              ],
              if (useJsonMode) 'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException('The AI service timed out', retryable: true);
    } on http.ClientException catch (e) {
      throw AiException('Network error: ${e.message}', retryable: true);
    }

    final code = response.statusCode;
    if (code != 200) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final detail = _errorMessage(body);
      throw AiException(
        code == 401 || code == 403
            ? 'The API key was rejected${detail.isEmpty ? '' : ': $detail'}'
            : detail.isEmpty
            ? 'AI request failed'
            : detail,
        statusCode: code,
        retryable: code == 429 || code >= 500,
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const AiException('The AI service returned an unreadable reply');
    }
    final content =
        ((body['choices'] as List?)?.firstOrNull as Map?)?['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiException('The AI reply was empty');
    }
    final usage = body['usage'] as Map<String, dynamic>? ?? const {};
    return AiReply(
      parseJsonObject(content),
      AiUsage(
        (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
        (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Accepts a bare object, an array, or JSON wrapped in ``` fences or prose.
  static Map<String, dynamic> parseJsonObject(String content) {
    var text = content.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();
    final start = text.indexOf(RegExp(r'[\[{]'));
    if (start > 0) text = text.substring(start);
    final end = text.lastIndexOf(RegExp(r'[\]}]'));
    if (end >= 0 && end < text.length - 1) text = text.substring(0, end + 1);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'results': decoded};
    } on FormatException {
      // Fall through.
    }
    throw const AiException('The AI reply was not valid JSON');
  }

  static String _errorMessage(String body) {
    try {
      final j = jsonDecode(body);
      final error = j is Map ? j['error'] : null;
      final message = error is Map ? error['message'] : error;
      if (message is String) {
        return message.length > 160 ? '${message.substring(0, 160)}…' : message;
      }
    } on FormatException {
      // Not JSON.
    }
    return '';
  }
}
