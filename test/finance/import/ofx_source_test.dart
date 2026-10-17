import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/ofx_source.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  const ofx = OfxSource();

  test('reads an OFX 1.x SGML statement with unclosed tags', () {
    final result = ofx.parse(fixture('bank_sgml.ofx'));
    expect(result.rows, hasLength(3));
    expect(result.errors, hasLength(2));
    expect(result.errors.map((e) => e.message), [
      contains('Invalid OFX date'),
      contains('TRNAMT'),
    ]);
    expect(result.errors.first.line, greaterThan(50));

    final coffee = result.rows.first;
    expect(coffee.date, DateTime(2024, 1, 5, 12));
    expect(coffee.amount, Amount('42.50'));
    expect(coffee.type, 'expense');
    expect(coffee.payee, 'COFFEE & CO');
    expect(coffee.note, 'Card 1234');
    expect(coffee.account, '1234567890');
    expect(coffee.currency, 'USD');
    expect(coffee.externalId, '2024010501');

    expect(result.rows[1].type, 'income');
    expect(result.rows[1].date, DateTime(2024, 1, 15));
    expect(result.rows[2].date, DateTime(2024, 1, 20));
    expect(total(result, 'expense'), Amount('242.5'));
    expect(total(result, 'income'), Amount('2500'));
    expect(result.rows.map((r) => r.externalId), [
      '2024010501',
      '2024011502',
      '2024012003',
    ]);
  });

  test('reads OFX 2.x XML with bank and card statements', () {
    final result = ofx.parse(fixture('multi_xml.qfx'));
    expect(result.errors, isEmpty);
    expect(result.rows, hasLength(3));
    final bakery = result.rows[0];
    expect(bakery.amount, Amount('12.5'));
    expect(bakery.payee, 'Bäckerei');
    expect(bakery.note, isNull);
    expect(bakery.account, 'DE89370400440532013000');
    expect(bakery.currency, 'EUR');

    final refund = result.rows[1];
    expect(refund.type, 'income');
    expect(refund.payee, 'Refund Shop');
    expect(refund.currency, 'USD');
    expect(refund.date, DateTime(2024, 2, 10, 9, 30));

    final card = result.rows[2];
    expect(card.account, 'XXXX-4321');
    expect(card.type, 'expense');
    expect(card.amount, Amount('75.25'));
    expect(card.externalId, 'CC-1');
  });

  test('default account and currency fill the gaps', () {
    const body =
        '<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>'
        '<STMTTRN><DTPOSTED>20240101<TRNAMT>5<FITID>1</STMTTRN>'
        '</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>';
    final result = ofx.parse(
      body,
      options: const ImportOptions(
        defaultAccount: 'Main',
        defaultCurrency: 'EGP',
      ),
    );
    expect(result.rows.single.account, 'Main');
    expect(result.rows.single.currency, 'EGP');
  });

  test('garbage is an error, not a crash', () {
    expect(ofx.parse('hello').errors, hasLength(1));
    expect(ofx.parse('<OFX><STMTRS><BANKTRANLIST><STMTTRN>').rows, isEmpty);
    expect(ofx.canRead('statement.QFX', ''), isTrue);
    expect(ofx.canRead('x.txt', 'OFXHEADER:100'), isTrue);
    expect(ofx.canRead('x.csv', 'Date,Amount'), isFalse);
  });

  test('OFX dates', () {
    expect(OfxSource.parseDate('20240229'), DateTime(2024, 2, 29));
    expect(
      OfxSource.parseDate('20240229235959.123[-8:PST]'),
      DateTime(2024, 2, 29, 23, 59, 59),
    );
    expect(() => OfxSource.parseDate('20230229'), throwsFormatException);
  });
}
