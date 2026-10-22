import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/ai/ai_client.dart';
import 'package:flourish/core/ai/ai_payment_assist.dart';
import 'package:flourish/core/ai/redactor.dart';
import 'package:flourish/core/detection/category_resolver.dart';
import 'package:flourish/core/detection/detection_service.dart';
import 'package:flourish/core/detection/parsed_payment.dart';
import 'package:flourish/core/detection/payment_parser.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final at = DateTime(2026, 10, 15, 12);

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

AiClient client(MockClient mock) => AiClient(
  httpClient: mock,
  baseUrl: 'https://api.example.com/v1/',
  apiKey: 'test-key',
  model: 'm',
  retryDelay: Duration.zero,
);

ParsedPayment local(String text) => PaymentMessageParser.parse(
  RawMessage(text: text, receivedAt: at, source: 'paste'),
);

Json result(Map<String, Object?> fields) => {
  'i': 0,
  'ignore': null,
  'kind': 'purchase',
  'direction': 'expense',
  'confidence': 0.9,
  ...fields,
};

void main() {
  group('AiClient', () {
    test('429 is retried once; 401 explains the key', () async {
      var calls = 0;
      final retry = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{"error":{"message":"slow down"}}', 429)
            : reply({'ok': true});
      });
      final r = await client(retry).completeJson(system: 's', user: 'u');
      expect(r.json['ok'], isTrue);
      expect(calls, 2);

      final denied = MockClient(
        (_) async => http.Response('{"error":{"message":"bad key"}}', 401),
      );
      expect(
        () => client(denied).completeJson(system: 's', user: 'u'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'm',
            contains('rejected'),
          ),
        ),
      );
    });

    test('drops JSON mode when a provider rejects it', () async {
      final bodies = <Json>[];
      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Json;
        bodies.add(body);
        return body.containsKey('response_format')
            ? http.Response(
                '{"error":{"message":"response_format is not supported"}}',
                400,
              )
            : reply({'ok': true});
      });
      await client(mock).completeJson(system: 's', user: 'u');
      expect(bodies, hasLength(2));
      expect(bodies.last.containsKey('response_format'), isFalse);
    });

    test('accepts fenced JSON and rejects prose', () {
      expect(AiClient.parseJsonObject('Sure:\n```json\n{"a":1}\n```')['a'], 1);
      expect(
        () => AiClient.parseJsonObject('sorry, I cannot'),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('AiPaymentAssist.merge', () {
    final categories = [
      Category(
        id: 2,
        name: 'Food & Drinks',
        icon: 'restaurant',
        color: 0,
        type: 'expense',
        isDefault: true,
        sortOrder: 0,
      ),
    ];
    final assist = AiPaymentAssist(client(MockClient((_) async => reply({}))));

    test('a hallucinated amount is never used', () {
      const text = 'POS 45.00 EGP Zed';
      final r = assist.merge(
        AiPaymentRequest(text, local(text)),
        result({'amount': '999.00', 'currency': 'EGP'}),
        categories,
        now: at,
      );
      expect(r!.payment.amount, Amount('45'));
    });

    test('an amount the parser missed is accepted when it is in the text', () {
      const text = 'Spinneys Zayed ٤٥٠ ج.م بطاقة 4521';
      final r = assist.merge(
        AiPaymentRequest(text, const ParsedPayment.ignored('no_amount')),
        result({'amount': '450', 'currency': 'EGP', 'merchant': 'Spinneys'}),
        categories,
        now: at,
      );
      expect(r!.payment.amount, Amount('450'));
      expect(r.payment.ignored, isFalse);
      expect(r.payment.aiAssisted, isTrue);
    });

    test('unknown category ids are dropped; proposals are sanitized', () {
      const text = 'Paid 50.00 EGP at Petsmart';
      final r = assist.merge(
        AiPaymentRequest(text, local(text)),
        result({
          'amount': '50',
          'category': {
            'existing_id': 777,
            'new': {
              'name': '  pet supplies ',
              'icon': 'nope',
              'parent': 'Shopping',
            },
          },
        }),
        categories,
        now: at,
      );
      expect(r!.categoryId, isNull);
      expect(r.proposed!.name, 'Pet Supplies');
      expect(r.proposed!.icon, 'category');
    });

    test('an AI ignore reason marks the payment ignored', () {
      const text = 'Paid 50.00 EGP at Zed';
      final r = assist.merge(
        AiPaymentRequest(text, local(text)),
        {'i': 0, 'ignore': 'promo'},
        categories,
        now: at,
      );
      expect(r!.payment.ignoreReason, 'promo');
    });

    test('amountAppearsIn handles grouping and k', () {
      expect(
        AiPaymentAssist.amountAppearsIn(Amount('1250.5'), 'EGP 1,250.50'),
        isTrue,
      );
      expect(
        AiPaymentAssist.amountAppearsIn(Amount('1500'), 'spent 1.5k'),
        isTrue,
      );
      expect(
        AiPaymentAssist.amountAppearsIn(Amount('12000'), 'EGP 12 000'),
        isTrue,
      );
      expect(
        AiPaymentAssist.amountAppearsIn(Amount('99'), 'EGP 1,250.50'),
        isFalse,
      );
    });

    test('outgoing text is redacted but keeps the amount', () {
      const text =
          'Received EGP 250000 from acct 1234567890123 call +20 100 123 4567 me@mail.com';
      final out = assist.outgoing(AiPaymentRequest(text, local(text)));
      expect(out, contains('250000'));
      expect(out, isNot(contains('1234567890123')));
      expect(out, isNot(contains('me@mail.com')));
      expect(Redactor.redact('ref 99887766'), 'ref ****7766');
    });
  });

  group('DetectionService with AI', () {
    late AppDatabase db;
    late FinancialLedgerService ledger;
    late int bank;
    var calls = 0;
    late Json Function(Json body) answer;
    final sent = <String>[];

    DetectionService service({
      bool newCategories = true,
      bool automatic = true,
      bool redactText = true,
    }) => DetectionService(
      ledger,
      newCategories: newCategories,
      automaticAi: () => automatic,
      assist: () async => AiPaymentAssist(
        client(
          MockClient((req) async {
            calls++;
            sent.add(req.body);
            final body = jsonDecode(req.body) as Json;
            return reply(answer(body));
          }),
        ),
        cache: MemoryAiCache(),
        redactText: redactText,
      ),
    );

    setUp(() async {
      calls = 0;
      sent.clear();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      ledger = FinancialLedgerService(db);
      for (final a in await db.getAllAccounts()) {
        await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
      }
      bank = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'CIB',
          type: 'bank',
          color: 0,
          icon: 'account_balance',
          currency: const Value('EGP'),
        ),
      );
    });
    tearDown(() => db.close());

    RawMessage sms(String text) => RawMessage(
      text: text,
      sender: 'CIB',
      receivedAt: at,
      source: 'android_notification',
    );

    test('rescues a message the parser found no amount in', () async {
      answer = (_) => {
        'results': [
          result({'amount': '450', 'currency': 'EGP', 'merchant': 'Spinneys'}),
        ],
      };
      final row = await service().ingest(
        sms('Spinneys Zayed 450 card 4521 ok'),
      );
      expect(row, isNotNull);
      expect(row!.amount, '450');
      expect(row.merchant, 'Spinneys');
      expect(service().parsedOf(row).aiAssisted, isTrue);
    });

    test('confident messages never reach the AI on ingest', () async {
      answer = (_) => {'results': []};
      await service().ingest(
        sms('Card ending 1234 was charged EGP 250.00 at Talabat'),
      );
      expect(calls, 0);
    });

    test(
      'a proposed category is created on confirm, under its parent',
      () async {
        answer = (_) => {
          'results': [
            result({
              'amount': '120',
              'currency': 'EGP',
              'merchant': 'Petsmart',
              'category': {
                'new': {'name': 'Pets', 'icon': 'pets', 'parent': 'Shopping'},
              },
            }),
          ],
        };
        final s = service();
        final row = (await s.ingest(sms('Petsmart 120 card 1234 done')))!;
        expect(row.categoryId, isNull);
        expect(s.proposalOf(row)!.name, 'Pets');

        final result1 = await s.confirm(
          row.id,
          draft: DetectionDraft(accountId: bank),
        );
        final tx = await db.getTransactionById(result1.transactionId);
        final pets = await db.getCategoryById(tx!.categoryId);
        expect(pets!.name, 'Pets');
        final shopping = (await db.getAllCategories()).firstWhere(
          (c) => c.name == 'Shopping',
        );
        final link = await ledger.store.get('categoryParents', '${pets.id}');
        expect(link?['parent'], shopping.id);
      },
    );

    test('proposals reuse a similar existing category', () async {
      answer = (_) => {
        'results': [
          result({
            'amount': '80',
            'currency': 'EGP',
            'category': {
              'new': {'name': 'Food and drink', 'icon': 'restaurant'},
            },
          }),
        ],
      };
      final s = service();
      final row = (await s.ingest(sms('Qwerty 80 card 1234 done')))!;
      final food = (await db.getAllCategories()).firstWhere(
        (c) => c.name == 'Food & Drinks',
      );
      expect(row.categoryId, food.id);
    });

    test(
      'assistPending updates unclear rows and dismisses AI-ignored ones',
      () async {
        final s = service();
        answer = (_) => {'results': []};
        final unclear = (await s.ingest(sms('EGP 75.00 Qwerty ref ok')))!;
        expect(unclear.kind, isNull, reason: 'no kind, so worth an AI look');

        answer = (_) => {
          'results': [
            {'i': 0, 'ignore': 'promo'},
          ],
        };
        expect(
          await s.assistPending(ids: [unclear.id], userInitiated: true),
          1,
        );
        expect((await s.get(unclear.id))!.status, 'dismissed');
      },
    );

    group('consent to automatic reading', () {
      const unreadable = 'Spinneys Zayed 450 card 4521 ok';
      const unclearText = 'EGP 75.00 Qwerty ref ok';

      test('without consent, captured alerts never reach the AI', () async {
        answer = (_) => {
          'results': [
            result({'amount': '450', 'currency': 'EGP'}),
          ],
        };
        final s = service(automatic: false);
        expect(await s.ingest(sms(unreadable)), isNull);
        final unclear = (await s.ingest(sms(unclearText)))!;
        expect(unclear.kind, isNull);
        expect(await s.assistPending(), 0);
        expect(calls, 0);
      });

      test('a tap still reaches the AI without automatic consent', () async {
        answer = (_) => {'results': []};
        final s = service(automatic: false);
        final unclear = (await s.ingest(sms(unclearText)))!;
        await s.assistPending(ids: [unclear.id], userInitiated: true);
        expect(calls, 1);
      });

      test('pasted text may use the AI; other pending alerts stay', () async {
        answer = (_) => {'results': []};
        final s = service(automatic: false);
        final background = (await s.ingest(sms(unclearText)))!;
        final pasted = (await s.ingest(
          RawMessage(
            text: 'EGP 90.00 Zxcvb ref ok',
            receivedAt: at,
            source: 'paste',
          ),
          userInitiated: true,
        ))!;
        await s.assistPending(
          ids: [pasted.id],
          userInitiated: true,
          unclearOnly: true,
        );
        expect(calls, 1);
        expect(sent.single, contains('Zxcvb'));
        expect(sent.single, isNot(contains('Qwerty')));
        expect(background.id, isNot(pasted.id));
      });

      test('automatic requests are masked even with masking off', () async {
        answer = (_) => {'results': []};
        const text =
            'EGP 75.00 Qwerty acct 1234567890123 me@mail.com +20 100 123 4567';
        final s = service(redactText: false);
        await s.ingest(sms(text));
        await s.assistPending();
        expect(calls, greaterThan(0));
        for (final body in sent) {
          expect(body, isNot(contains('1234567890123')));
          expect(body, isNot(contains('me@mail.com')));
          expect(body, isNot(contains('123 4567')));
        }
      });
    });

    test('an unreachable AI keeps the on-device reading', () async {
      final s = DetectionService(
        ledger,
        assist: () async => AiPaymentAssist(
          client(
            MockClient((_) async => throw http.ClientException('offline')),
          ),
        ),
      );
      final row = await s.ingest(
        sms('Card ending 1234 was charged EGP 250.00 at Talabat'),
      );
      expect(row, isNotNull);
      expect(
        () => s.assistPending(ids: [row!.id], userInitiated: true),
        throwsA(isA<AiException>()),
      );
    });
  });

  test('ProposedCategory JSON round trip', () {
    const p = ProposedCategory(
      name: 'Pets',
      type: 'expense',
      icon: 'pets',
      colorIndex: 3,
      parentName: 'Shopping',
    );
    expect(
      ProposedCategory.fromJson(p.toJson())!.label,
      'Pets (under Shopping)',
    );
  });
}
