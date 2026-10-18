import 'dart:convert';

import 'package:flourish/core/ai/ai_client.dart';
import 'package:flourish/core/ai/ai_screenshot_reader.dart';
import 'package:flourish/core/ai/prompts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'the screenshot goes as an image part and the text comes back',
    () async {
      late Map<String, dynamic> sent;
      final mock = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'text': 'تم خصم 250.00 جنيه من بطاقتك 1234 لدى كارفور',
                  }),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = AiClient(
        httpClient: mock,
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'k',
        model: 'vision',
      );

      final text = await AiScreenshotReader(
        client,
      ).read([1, 2, 3], mimeType: AiScreenshotReader.mimeTypeFor('shot.PNG'));

      expect(text, contains('كارفور'));
      expect(sent['messages'][0]['content'], AiPrompts.screenshotSystem);
      final parts = sent['messages'][1]['content'] as List;
      expect(parts.first, {
        'type': 'text',
        'text': 'Transcribe this screenshot.',
      });
      expect(parts.last, {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/png;base64,${base64Encode([1, 2, 3])}',
        },
      });
    },
  );

  test('text-only requests keep a plain string content', () async {
    late Map<String, dynamic> sent;
    final client = AiClient(
      httpClient: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{}'},
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'k',
      model: 'm',
    );
    await client.completeJson(system: 's', user: 'u');
    expect(sent['messages'][1]['content'], 'u');
  });

  test('oversized images are refused before sending', () {
    final client = AiClient(
      httpClient: MockClient((_) async => fail('nothing should be sent')),
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'k',
      model: 'm',
    );
    expect(
      AiScreenshotReader(
        client,
      ).read(List.filled(AiScreenshotReader.maxBytes + 1, 0)),
      throwsA(isA<AiException>()),
    );
  });
}
