import 'dart:convert';

import 'package:flourish/core/ai/ai_client.dart';
import 'package:flourish/core/ai/ai_transaction_extractor.dart';
import 'package:flourish/core/ai/redactor.dart';
import 'package:flourish/core/detection/local_parser.dart';
import 'package:flourish/core/detection/transaction_candidate.dart';
import 'package:flourish/data/database/database.dart' show Category;
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Category cat(int id, String name, [String type = 'expense']) => Category(
  id: id,
  name: name,
  icon: 'more_horiz',
  color: 0,
  type: type,
  isDefault: true,
  sortOrder: id,
);

final categories = [cat(2, 'Food & Drinks'), cat(9, 'Other')];
final now = DateTime(2026, 10, 17);

http.Response reply(Object content, {int status = 200}) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {
          'content': content is String ? content : jsonEncode(content),
        },
      },
    ],
    'usage': {'prompt_tokens': 120, 'completion_tokens': 40},
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AiClient client(MockClient mock, {bool jsonMode = true}) => AiClient(
  httpClient: mock,
  baseUrl: 'https://api.example.com/v1/',
  apiKey: 'test-key',
  model: 'm',
  jsonMode: jsonMode,
  retryDelay: Duration.zero,
);

TransactionCandidate parse(String t) => LocalTransactionParser.parse(t, now: now);

void main() {
  test('valid answer is merged with a proposed category', () async {
    late Map<String, dynamic> sent;
    final mock = MockClient((req) async {
      expect(req.url.toString(), 'https://api.example.com/v1/chat/completions');
      expect(req.headers['Authorization'], 'Bearer test-key');
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return reply({
        'results': [
          {
            'i': 0,
            'is_transaction': true,
            'kind': 'purchase',
            'type': 'expense',
            'amount': '1250.50',
            'currency': 'EGP',
            'date': '2026-10-15',
            'merchant': 'Spinneys',
            'category': {
              'new': {
                'name': 'Groceries',
                'icon': 'local_grocery_store',
                'parent': 'Food & Drinks',
              },
            },
            'confidence': 0.93,
          },
        ],
      });
    });
    final out = await AiTransactionExtractor(client(mock)).improve(
      [parse('POS SPINNEYS ZAYED 1,250.50 EGP card ****4521')],
      categories,
      now: now,
    );
    expect(sent['temperature'], 0);
    expect(sent['response_format'], {'type': 'json_object'});
    final c = out.single;
    expect(c.amount, Amount('1250.50'));
    expect(c.merchant, 'Spinneys');
    expect(c.date, DateTime(2026, 10, 15));
    expect(c.source, CandidateSource.ai);
    expect(c.aiProposedCategory!.name, 'Groceries');
    expect(c.aiProposedCategory!.parentName, 'Food & Drinks');
  });

  test('a hallucinated amount is rejected', () async {
    final mock = MockClient(
      (_) async => reply({
        'results': [
          {
            'i': 0,
            'is_transaction': true,
            'kind': 'purchase',
            'type': 'expense',
            'amount': '999.00',
            'currency': 'EGP',
            'category': {'existing_id': 2},
            'confidence': 0.9,
          },
        ],
      }),
    );
    final local = parse('Paid 45.00 EGP at Cafe');
    final out = await AiTransactionExtractor(
      client(mock),
    ).improve([local], categories, now: now);
    expect(out.single.amount, Amount('45'));
    expect(out.single.aiCategoryId, 2);
  });

  test('an unknown category id or bad enum is ignored', () async {
    final mock = MockClient(
      (_) async => reply({
        'results': [
          {'i': 0, 'kind': 'nonsense', 'type': 'expense', 'amount': '45'},
          {
            'i': 1,
            'is_transaction': true,
            'kind': 'purchase',
            'type': 'expense',
            'amount': '20',
            'category': {'existing_id': 777},
          },
        ],
      }),
    );
    final out = await AiTransactionExtractor(client(mock)).improve(
      [parse('Paid 45.00 EGP at Cafe'), parse('Spent 20 USD at Qwerty')],
      categories,
      now: now,
    );
    expect(out[0].source, CandidateSource.local);
    expect(out[1].aiCategoryId, isNull);
  });

  test('malformed JSON fails loudly, fenced JSON is accepted', () async {
    final bad = MockClient((_) async => reply('sorry, I cannot'));
    expect(
      () => AiTransactionExtractor(client(bad)).improve(
        [parse('Paid 45 EGP')],
        categories,
        now: now,
      ),
      throwsA(isA<AiException>()),
    );
    final fenced = MockClient(
      (_) async => reply(
        'Here you go:\n```json\n{"results":[{"i":0,"is_transaction":true,"kind":"purchase","type":"expense","amount":"45","category":{"existing_id":2}}]}\n```',
      ),
    );
    final out = await AiTransactionExtractor(
      client(fenced),
    ).improve([parse('Paid 45 EGP')], categories, now: now);
    expect(out.single.aiCategoryId, 2);
  });

  test('429 is retried once, then 401 is reported', () async {
    var calls = 0;
    final mock = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('{"error":{"message":"slow"}}', 429);
      return reply({'results': []});
    });
    await AiTransactionExtractor(
      client(mock),
    ).improve([parse('Paid 45 EGP')], categories, now: now);
    expect(calls, 2);

    final denied = MockClient(
      (_) async => http.Response('{"error":{"message":"bad key"}}', 401),
    );
    expect(
      () => AiTransactionExtractor(
        client(denied),
      ).improve([parse('Paid 45 EGP')], categories, now: now),
      throwsA(
        isA<AiException>().having((e) => e.message, 'message', contains('rejected')),
      ),
    );
  });

  test('providers without JSON mode get a retry without it', () async {
    final bodies = <Map<String, dynamic>>[];
    final mock = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      if (body.containsKey('response_format')) {
        return http.Response(
          '{"error":{"message":"response_format is not supported"}}',
          400,
        );
      }
      return reply({'results': []});
    });
    await AiTransactionExtractor(
      client(mock),
    ).improve([parse('Paid 45 EGP')], categories, now: now);
    expect(bodies, hasLength(2));
    expect(bodies.last.containsKey('response_format'), isFalse);
  });

  test('outgoing text is redacted and answers are cached', () async {
    var calls = 0;
    late String outgoing;
    final mock = MockClient((req) async {
      calls++;
      final user = jsonDecode(
        (jsonDecode(req.body)['messages'] as List)[1]['content'] as String,
      );
      outgoing = (user['messages'] as List).single['text'] as String;
      return reply({
        'results': [
          {
            'i': 0,
            'is_transaction': true,
            'kind': 'transfer_in',
            'type': 'income',
            'amount': '250000',
            'currency': 'EGP',
            'category': {'existing_id': 9},
          },
        ],
      });
    });
    final cache = MemoryAiCache();
    final extractor = AiTransactionExtractor(client(mock), cache: cache);
    final text =
        'Received EGP 250000 from acct 1234567890123 call +20 100 123 4567 or me@mail.com';
    await extractor.improve([parse(text)], categories, now: now);
    expect(outgoing, contains('250000'));
    expect(outgoing, isNot(contains('1234567890123')));
    expect(outgoing, contains('****0123'));
    expect(outgoing, isNot(contains('me@mail.com')));
    expect(outgoing, isNot(contains('4567')));

    await extractor.improve([parse(text)], categories, now: now);
    expect(calls, 1, reason: 'second call is served from cache');
  });

  test('amountAppearsIn handles grouping and k', () {
    expect(
      AiTransactionExtractor.amountAppearsIn(Amount('1250.5'), 'EGP 1,250.50'),
      isTrue,
    );
    expect(
      AiTransactionExtractor.amountAppearsIn(Amount('1500'), 'spent 1.5k'),
      isTrue,
    );
    expect(
      AiTransactionExtractor.amountAppearsIn(Amount('12000'), 'EGP 12 000'),
      isTrue,
    );
    expect(
      AiTransactionExtractor.amountAppearsIn(Amount('99'), 'EGP 1,250.50'),
      isFalse,
    );
  });

  test('redactor keeps amounts and short numbers', () {
    expect(
      Redactor.redact('Paid 1,250.50 EGP card 4521 ref 99887766'),
      'Paid 1,250.50 EGP card 4521 ref ****7766',
    );
  });
}
