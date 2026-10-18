import 'dart:convert';

import 'package:flourish/core/ai/ai_client.dart';
import 'package:flourish/core/ai/ai_statement_reader.dart';
import 'package:flourish/core/ai/prompts.dart';
import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/pdf_statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response reply(Object content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': jsonEncode(content)},
      },
    ],
    'usage': {'prompt_tokens': 300, 'completion_tokens': 80},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AiClient client(MockClient mock) => AiClient(
  httpClient: mock,
  baseUrl: 'https://api.example.com/v1',
  apiKey: 'test-key',
  model: 'm',
  retryDelay: Duration.zero,
);

StatementPage page(int number, List<String> lines) => StatementPage(number, [
  for (final l in lines)
    StatementLine([
      for (final (i, w) in l.split(' ').indexed)
        StatementWord(w, i * 40.0, i * 40.0 + 30),
    ]),
]);

/// An Arabic statement whose columns came out right-to-left: the date ends
/// each line, so the table heuristic finds nothing.
final arabic = [
  page(1, [
    'كشف حساب رقم الحساب 1002003004005',
    'العميل أحمد محمد ahmed@example.com',
    'الرصيد الوصف المبلغ التاريخ',
    '8,749.50 مشتريات كارفور المعادي 1,250.50 02/10/2026',
    '33,749.50 راتب أكتوبر 25,000.00 05/10/2026',
  ]),
  page(2, ['31,599.49 استرداد أمازون 349.99 12/10/2026']),
];

void main() {
  test('the heuristic finds nothing in this layout', () {
    expect(PdfStatementParser.parse(arabic).rows, isEmpty);
  });

  test('pages are masked, sent one by one, and amounts checked', () async {
    final requests = <Map<String, dynamic>>[];
    final mock = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      requests.add(body);
      final user = jsonDecode(body['messages'][1]['content'] as String);
      return reply(switch (user['page']) {
        1 => {
          'transactions': [
            {
              'date': '2026-10-02',
              'description': 'كارفور المعادي',
              'amount': '1250.50',
              'direction': 'expense',
              'currency': 'EGP',
            },
            {
              'date': '2026-10-05',
              'description': 'راتب أكتوبر',
              'amount': '25000',
              'direction': 'income',
              'currency': 'EGP',
            },
            // Not on the page: dropped.
            {
              'date': '2026-10-06',
              'description': 'Invented',
              'amount': '999.00',
              'direction': 'expense',
            },
            // Unreadable date: dropped.
            {
              'date': 'soon',
              'description': 'x',
              'amount': '1,250.50',
              'direction': 'expense',
            },
          ],
        },
        _ => {
          'transactions': [
            {
              'date': '2026-10-12',
              'description': 'استرداد أمازون',
              'amount': 349.99,
              'direction': 'income',
              'currency': 'USD',
            },
          ],
        },
      });
    });

    final progress = <String>[];
    final result = await AiStatementReader(client(mock)).read(
      arabic,
      options: const ImportOptions(defaultCurrency: 'EGP'),
      onProgress: (done, total) => progress.add('$done/$total'),
    );

    expect(requests, hasLength(2));
    expect(progress.last, '2/2');
    final first = requests.first;
    expect(first['messages'][0]['content'], AiPrompts.statementSystem);
    final sent =
        jsonDecode(first['messages'][1]['content'] as String)['text'] as String;
    expect(sent, contains('****4005'));
    expect(sent, isNot(contains('1002003004005')));
    expect(sent, isNot(contains('ahmed@example.com')));
    expect(sent, isNot(contains('أحمد')), reason: 'customer line is not sent');
    expect(sent, contains('1,250.50'), reason: 'amounts are never masked');

    expect(
      [
        for (final r in result.rows)
          '${r.date.day} ${r.type} ${r.amount} ${r.currency} ${r.account} ${r.payee}',
      ],
      [
        '2 expense 1250.5 EGP Account …4005 كارفور المعادي',
        '5 income 25000 EGP Account …4005 راتب أكتوبر',
        '12 income 349.99 EGP Account …4005 استرداد أمازون',
      ],
    );
    expect(result.sourceId, 'pdf.ai');
    expect(result.warnings.single.message, contains('Left out 2 AI rows'));
  });

  test('every request failing is an error, not an empty import', () async {
    final mock = MockClient(
      (_) async => http.Response('{"error":{"message":"bad key"}}', 401),
    );
    expect(
      AiStatementReader(client(mock)).read(arabic),
      throwsA(isA<AiException>()),
    );
  });

  test('long pages are split between lines', () {
    final long = page(1, [
      for (var i = 0; i < 50; i++) '0$i/10/2026 Line $i 10.00',
    ]);
    final parts = AiStatementReader.chunks(long, maxChars: 200);
    expect(parts.length, greaterThan(1));
    expect(parts.every((p) => p.length <= 200), isTrue);
    expect(parts.join('\n').split('\n'), hasLength(50));
  });
}
