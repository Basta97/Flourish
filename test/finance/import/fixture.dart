import 'dart:io';

import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/transfer_legs.dart';
import 'package:flourish/domain/finance/amount.dart';

String fixture(String name) =>
    File('test/fixtures/imports/$name').readAsStringSync();

Amount total(ImportParseResult result, String type) =>
    totalsByType(result.rows)[type] ?? Amount.zero;

List<RawImportRow> ofType(ImportParseResult result, String type) =>
    result.rows.where((r) => r.type == type).toList();
