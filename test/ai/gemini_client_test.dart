import 'dart:convert';

import 'package:flourish/core/ai/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AiClient gemini(MockClient mock, {String model = 'gemini-flash-latest'}) =>
    AiClient(
      httpClient: mock,
      // The preset's OpenAI-compatible URL: the client still goes native.
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
      apiKey: 'AQ.test-key',
      model: model,
      retryDelay: Duration.zero,
    );

void main() {
  test('Gemini uses generateContent with x-goog-api-key, never Bearer', () async {
    late http.Request sent;
    final client = gemini(
      MockClient((req) async {
        sent = req;
        return json({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '{"ok": '},
                  {'text': 'true}'},
                ],
              },
            },
          ],
          'usageMetadata': {'promptTokenCount': 12, 'candidatesTokenCount': 3},
        });
      }),
      model: 'models/gemini-flash-latest',
    );
    final reply = await client.completeJson(
      system: 'Reply with JSON',
      user: 'ping',
      images: const [AiImage([1, 2, 3], mimeType: 'image/png')],
    );

    expect(
      sent.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
    );
    expect(sent.headers['x-goog-api-key'], 'AQ.test-key');
    expect(sent.headers.containsKey('Authorization'), isFalse);
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['systemInstruction']['parts'][0]['text'], 'Reply with JSON');
    final parts = body['contents'][0]['parts'] as List;
    expect(parts[0]['text'], 'ping');
    expect(parts[1]['inlineData']['mimeType'], 'image/png');
    expect(body['generationConfig']['responseMimeType'], 'application/json');
    expect(body['generationConfig']['temperature'], 0);

    expect(reply.json['ok'], isTrue);
    expect(reply.usage.promptTokens, 12);
    expect(reply.usage.completionTokens, 3);
  });

  test('a retired model explains how to fix it', () async {
    final client = gemini(
      MockClient(
        (_) async => json([
          {
            'error': {'message': 'models/gemini-2.5-flash is not found'},
          },
        ], 404),
      ),
    );
    expect(
      () => client.completeJson(system: 's', user: 'u'),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Choose model'), contains('not found')),
        ),
      ),
    );
  });

  test('a blocked prompt is reported', () async {
    final client = gemini(
      MockClient((_) async => json({'promptFeedback': {'blockReason': 'SAFETY'}})),
    );
    expect(
      () => client.completeJson(system: 's', user: 'u'),
      throwsA(isA<AiException>().having((e) => e.message, 'm', contains('SAFETY'))),
    );
  });

  test('listModels keeps text models that generate content', () async {
    final client = gemini(
      MockClient((req) async {
        expect(req.headers['x-goog-api-key'], 'AQ.test-key');
        return json({
          'models': [
            {
              'name': 'models/gemini-flash-latest',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/text-embedding-004',
              'supportedGenerationMethods': ['embedContent'],
            },
            {
              'name': 'models/gemini-3.6-flash',
              'supportedGenerationMethods': ['generateContent', 'countTokens'],
            },
          ],
        });
      }),
    );
    expect(await client.listModels(), ['gemini-flash-latest', 'gemini-3.6-flash']);
  });

  test('OpenAI-compatible providers list /models with Bearer', () async {
    final client = AiClient(
      httpClient: MockClient((req) async {
        expect(req.url.toString(), 'https://api.deepseek.com/models');
        expect(req.headers['Authorization'], 'Bearer sk-test');
        return json({
          'data': [
            {'id': 'deepseek-chat'},
            {'id': 'deepseek-reasoner'},
          ],
        });
      }),
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-test',
      model: 'deepseek-chat',
    );
    expect(client.isGemini, isFalse);
    expect(await client.listModels(), ['deepseek-reasoner', 'deepseek-chat']);
  });
}
