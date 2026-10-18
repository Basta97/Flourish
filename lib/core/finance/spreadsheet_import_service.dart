import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart' as csv;
import 'package:excel/excel.dart' as xlsx;
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../../domain/finance/models.dart';
import '../../data/database/database.dart';
import 'financial_ledger_service.dart';
import '../utils/fingerprint.dart' as fp;
import 'import/import_source.dart';

class ImportPreview {
  final List<Json> rows;
  final List<String> errors;
  final int duplicates;
  const ImportPreview(this.rows, this.errors, this.duplicates);
}

class SpreadsheetImportService {
  final FinancialLedgerService ledger;
  SpreadsheetImportService(this.ledger);
  Future<Map<String, List<List<String>>>> read(File file) async {
    if (file.path.toLowerCase().endsWith('.xlsx')) {
      final workbook = xlsx.Excel.decodeBytes(await file.readAsBytes());
      return {
        for (final table in workbook.tables.entries)
          table.key: table.value.rows
              .map((row) => row.map((c) => c?.value?.toString() ?? '').toList())
              .toList(),
      };
    }
    final rows = csv.csv.decode(await file.readAsString());
    return {
      'CSV': rows
          .map((r) => r.map((v) => v?.toString() ?? '').toList())
          .toList(),
    };
  }

  static DateTime parseDate(String input, String pattern) {
    final normalized = input.trim();
    final iso = DateTime.tryParse(normalized);
    if (iso != null && RegExp(r'^\d{4}-').hasMatch(normalized)) return iso;
    return DateFormat(pattern).parseStrict(normalized);
  }

  Future<ImportPreview> preview(
    List<List<String>> rows,
    Map<String, int> mapping, {
    required String fallbackCurrency,
    String datePattern = 'dd/MM/yyyy',
    bool signedAmounts = false,
    String decimalSeparator = '.',
  }) async {
    final output = <Json>[], errors = <String>[];
    var duplicates = 0;
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((v) => v.trim().isEmpty)) continue;
      String field(String key) {
        final index = mapping[key];
        return index == null || index < 0 || index >= row.length
            ? ''
            : row[index].trim();
      }

      try {
        final date = parseDate(field('date'), datePattern);
        var raw = field('amount').replaceAll(RegExp(r'[^0-9,.\-]'), '');
        raw = decimalSeparator == ','
            ? raw.replaceAll('.', '').replaceAll(',', '.')
            : raw.replaceAll(',', '');
        final signed = Amount(raw);
        if (!signedAmounts && signed < Amount.zero) {
          throw const FormatException(
            'Negative amount: select signed bank amounts or review the refund type',
          );
        }
        final amount = signed.abs;
        ledger.positive(amount);
        final typeRaw = field('type').toLowerCase();
        final type = signedAmounts
            ? (signed < Amount.zero ? 'expense' : 'income')
            : typeRaw.contains('transfer')
            ? 'transfer'
            : typeRaw.contains('income') || typeRaw == 'in'
            ? 'income'
            : typeRaw.contains('expense') || typeRaw == 'out'
            ? 'expense'
            : throw const FormatException(
                'Type must be income, expense, or transfer',
              );
        final account = field('account');
        if (account.isEmpty) throw const FormatException('Missing account');
        final currency = field('currency').isEmpty
            ? fallbackCurrency
            : field('currency').toUpperCase();
        if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
          throw const FormatException('Invalid currency code');
        }
        if (type == 'transfer' && field('destination').isEmpty) {
          throw const FormatException(
            'Transfer requires destination account mapping',
          );
        }
        final data = <String, dynamic>{
          'date': date.toIso8601String(),
          'amount': '$amount',
          'type': type,
          'account': account,
          'category': field('category').isEmpty ? 'Other' : field('category'),
          'currency': currency,
          'note': field('note'),
          'destination': field('destination'),
        };
        final fingerprint = await fp.fingerprint(jsonEncode(data));
        if (!seen.add(fingerprint) ||
            await ledger.store.get('imports', fingerprint) != null) {
          duplicates++;
          continue;
        }
        data['fingerprint'] = fingerprint;
        output.add(data);
      } catch (e) {
        errors.add('Row ${i + 2}: $e');
      }
    }
    return ImportPreview(output, errors, duplicates);
  }

  /// The manually mapped rows of [preview] in the shape every import source
  /// produces, so they go through the same review and duplicate checks.
  ImportParseResult toParseResult(ImportPreview preview, {int firstLine = 2}) {
    String? text(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return ImportParseResult(
      'csv.manual',
      [
        for (final (i, row) in preview.rows.indexed)
          RawImportRow(
            date: dateOf(row['date']),
            amount: amountOf(row['amount']),
            type: row['type'] as String,
            account: text(row['account']),
            destinationAccount: text(row['destination']),
            category: text(row['category']),
            note: text(row['note']),
            currency: text(row['currency']),
            sourceLine: firstLine + i,
          ),
      ],
      errors: [for (final e in preview.errors) ImportIssue(0, e)],
    );
  }

  Future<int> apply(ImportPreview preview) => ledger.db.transaction(() async {
    if (preview.errors.isNotEmpty) {
      throw StateError('Fix invalid rows before importing');
    }
    var count = 0;
    for (final row in preview.rows) {
      final fingerprint = row['fingerprint'] as String;
      if (await ledger.store.get('imports', fingerprint) != null) continue;
      final accounts = await ledger.db.getAllAccounts();
      final matching = accounts.where((a) => a.name == row['account']).toList();
      if (matching.any((a) => a.currency != row['currency'])) {
        throw StateError('Account ${row['account']} uses another currency');
      }
      final accountId =
          matching.firstOrNull?.id ??
          await ledger.db.insertAccount(
            AccountsCompanion.insert(
              name: row['account'],
              type: 'bank',
              color: 0xFF4F46E5,
              icon: 'account_balance',
              currency: Value(row['currency']),
            ),
          );
      if (row['type'] == 'transfer') {
        final destination = accounts
            .where(
              (a) =>
                  a.name == row['destination'] && a.currency == row['currency'],
            )
            .firstOrNull;
        if (destination == null) {
          throw StateError(
            'Create destination ${row['destination']} in ${row['currency']} first; import cross-currency transfers manually',
          );
        }
        await ledger.transfer(
          fromAccountId: accountId,
          toAccountId: destination.id,
          amount: amountOf(row['amount']),
          date: dateOf(row['date']),
          note: row['note'],
        );
      } else {
        final categories = await ledger.db.getAllCategories();
        final categoryId =
            categories
                .where(
                  (c) => c.name == row['category'] && c.type == row['type'],
                )
                .firstOrNull
                ?.id ??
            await ledger.db.insertCategory(
              CategoriesCompanion.insert(
                name: row['category'],
                icon: 'category',
                color: 0xFF4F46E5,
                type: row['type'],
              ),
            );
        await ledger.recordCash(
          accountId: accountId,
          amount: amountOf(row['amount']),
          type: row['type'],
          categoryId: categoryId,
          note: row['note'],
          date: dateOf(row['date']),
        );
      }
      await ledger.store.put('imports', fingerprint, {
        'date': DateTime.now().toIso8601String(),
      });
      count++;
    }
    return count;
  });
}
