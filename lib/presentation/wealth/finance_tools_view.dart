import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/detection/category_store.dart';
import '../providers/finance_providers.dart';
import '../providers/account_providers.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import '../providers/theme_providers.dart';
import '../../core/finance/backup_service.dart';
import '../../core/finance/spreadsheet_import_service.dart';
import '../../core/services/preferences_service.dart';
import '../../data/database/database.dart';
import 'finance_form.dart';
import 'holdings_view.dart';
import 'finance_runtime.dart';

class FinanceToolsView extends ConsumerWidget {
  const FinanceToolsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
    children: [
      ListTile(
        leading: const Icon(Icons.currency_exchange),
        title: const Text('Exchange rates'),
        subtitle: const Text('Sources, dates, and manual overrides'),
        onTap: () => exchangeRates(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.account_balance),
        title: const Text('Manage accounts'),
        subtitle: const Text('Edit, group, archive, and reconcile balances'),
        onTap: () => manageAccounts(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.bookmark_outline),
        title: const Text('Saved transaction templates'),
        onTap: () => templates(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: const Text('Subcategories'),
        onTap: () => subcategory(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.receipt_long),
        title: const Text('Receipt attachments'),
        onTap: () => receipts(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.calendar_month),
        title: const Text('Reporting month starts on'),
        subtitle: Text(
          'Day ${PreferencesService.getInt('month_start_day', defaultValue: 1)}',
        ),
        onTap: () => financeForm(
          context,
          title: 'Reporting month',
          fields: [
            const FinanceField(
              'day',
              'Start day (1–28)',
              initial: '1',
              numeric: true,
            ),
          ],
          save: (j) async {
            final day = int.parse(j['day']!);
            if (day < 1 || day > 28) {
              throw ArgumentError('Choose a day from 1 to 28');
            }
            await PreferencesService.setInt('month_start_day', day);
            ref.read(databaseProvider).notifyFinanceChanged();
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Payment reminders'),
        subtitle: const Text(
          'Local notifications for expected payments and maturities',
        ),
        onTap: () async {
          try {
            await ref.read(remindersProvider).enable();
            await ref
                .read(remindersProvider)
                .schedule(ref.read(financeStoreProvider));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment reminders enabled')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Device authentication lock'),
        subtitle: Text(
          PreferencesService.getBool('app_lock_enabled')
              ? 'Enabled · tap to disable'
              : 'Disabled · tap to enable',
        ),
        onTap: () async {
          try {
            final auth = LocalAuthentication();
            if (!await auth.isDeviceSupported()) {
              throw StateError('Set up your device passcode first');
            }
            if (await auth.authenticate(
              localizedReason: 'Change Flourish app lock',
            )) {
              await PreferencesService.setBool(
                'app_lock_enabled',
                !PreferencesService.getBool('app_lock_enabled'),
              );
              ref.read(databaseProvider).notifyFinanceChanged();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.vpn_key_outlined),
        title: const Text('Stock quote API key'),
        subtitle: const Text(
          'Optional Alpha Vantage key · stored securely on this device',
        ),
        onTap: () => financeForm(
          context,
          title: 'Alpha Vantage API key',
          fields: [const FinanceField('key', 'Personal API key', secret: true)],
          save: (j) => ref
              .read(secureStorageProvider)
              .write(key: 'alpha_vantage_key', value: j['key']),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: const Text('Export encrypted backup'),
        subtitle: const Text(
          'Includes holdings, contracts, activity, settings, and receipts',
        ),
        onTap: () => exportEncrypted(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text('Restore encrypted backup'),
        onTap: () => restoreEncrypted(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Automatic backup history'),
        subtitle: const Text(
          'Seven local daily backups · remain on this device',
        ),
        onTap: () => backupHistory(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.table_chart_outlined),
        title: const Text('Import CSV / Excel'),
        subtitle: const Text('Map columns, preview rows, and skip duplicates'),
        onTap: () => importSpreadsheet(context, ref),
      ),
      ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Export transactions as CSV'),
        onTap: () => exportCsv(context, ref),
      ),
    ],
  );
}

Future<void> manageAccounts(BuildContext context, WidgetRef ref) async {
  final accounts = await ref.read(databaseProvider).getAllAccounts();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Accounts'),
      content: SizedBox(
        width: 440,
        height: 400,
        child: ListView(
          children: [
            for (final a in accounts)
              ListTile(
                title: Text(a.name),
                subtitle: Text('${a.balance.toStringAsFixed(2)} ${a.currency}'),
                onTap: () {
                  Navigator.pop(ctx);
                  editAccount(context, ref, a);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> editAccount(BuildContext context, WidgetRef ref, Account a) async {
  final stored = await ref
      .read(financeStoreProvider)
      .get('accountDetails', '${a.id}');
  if (!context.mounted) return;
  await financeForm(
    context,
    title: 'Manage ${a.name}',
    fields: [
      FinanceField('name', 'Account name', initial: a.name),
      FinanceField(
        'institution',
        'Institution',
        initial: stored?['institution'] ?? '',
        required: false,
      ),
      FinanceField(
        'group',
        'Group',
        initial: stored?['group'] ?? '',
        required: false,
      ),
      FinanceField(
        'archived',
        'Archived',
        initial: stored?['archived'] == true ? 'yes' : 'no',
        options: const {'no': 'Active', 'yes': 'Archived'},
      ),
      FinanceField(
        'included',
        'Include in wealth totals',
        initial: stored?['included'] == false ? 'no' : 'yes',
        options: const {'yes': 'Include', 'no': 'Exclude'},
      ),
      const FinanceField(
        'balance',
        'Reconciled balance (optional)',
        required: false,
        numeric: true,
      ),
      const FinanceField('reason', 'Reconciliation reason', required: false),
    ],
    save: (j) async {
      final store = ref.read(financeStoreProvider),
          db = ref.read(databaseProvider);
      await db.transaction(() async {
        final current = await db.getAccountById(a.id);
        if (current == null) throw StateError('Account no longer exists');
        await db.updateAccount(current.copyWith(name: j['name']));
        if (j['balance']!.isNotEmpty) {
          await ref
              .read(financialLedgerProvider)
              .reconcile(a.id, number(j, 'balance'), j['reason']!);
        }
        await store.put(
          'accountDetails',
          '${a.id}',
          AccountDetails(
            a.id,
            institution: j['institution']!,
            group: j['group']!,
            archived: j['archived'] == 'yes',
            included: j['included'] == 'yes',
          ).toJson(),
        );
      });
      ref.invalidate(accountByIdProvider(a.id));
    },
  );
  if (!context.mounted) return;
  final history = (await ref.read(financeStoreProvider).list('adjustments'))
      .where((j) => j['accountId'] == a.id)
      .toList();
  if (!context.mounted || history.isEmpty) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reconciliation history'),
      content: SizedBox(
        width: 440,
        height: 300,
        child: ListView(
          children: [
            for (final j in history)
              ListTile(
                title: Text('${j['before']} → ${j['after']} ${a.currency}'),
                subtitle: Text('${j['reason']}\n${j['date']}'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> exchangeRates(BuildContext context, WidgetRef ref) async {
  final store = ref.read(financeStoreProvider),
      valuation = ref.read(valuationProvider);
  final rows = (await store.list(
    'fx',
  )).map(MarketObservation.fromJson).toList();
  final keys = rows.map((r) => r.key).toSet().toList()..sort();
  final active = <MarketObservation>[];
  for (final key in keys) {
    final value = await valuation.observation('fx', key);
    if (value != null) active.add(value);
  }
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Exchange rates'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: ListView(
          children: [
            for (final r in active)
              ListTile(
                title: Text('${r.key} · ${r.value}'),
                subtitle: Text(
                  '${r.source}${r.manual ? ' · manual override' : ''}\n${r.effectiveAt.toIso8601String().substring(0, 10)}',
                ),
                trailing: r.manual
                    ? IconButton(
                        tooltip: 'Resume automatic rate',
                        icon: const Icon(Icons.clear),
                        onPressed: () async {
                          for (final j in await store.list('fx')) {
                            if (j['key'] == r.key && j['manual'] == true) {
                              await store.remove(
                                'fx',
                                '${j['key']}:manual:${j['effectiveAt']}',
                              );
                            }
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      )
                    : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            financeForm(
              context,
              title: 'Manual exchange rate',
              fields: [
                FinanceField(
                  'base',
                  'From',
                  initial: 'USD',
                  options: currencies,
                ),
                FinanceField(
                  'quote',
                  'To',
                  initial: 'EGP',
                  options: currencies,
                ),
                const FinanceField(
                  'rate',
                  'One source unit equals',
                  numeric: true,
                ),
                FinanceField(
                  'date',
                  'Effective date',
                  initial: today(),
                  date: true,
                ),
              ],
              save: (j) async {
                if (j['base'] == j['quote']) {
                  throw ArgumentError('Choose different currencies');
                }
                await ref
                    .read(marketDataProvider)
                    .save(
                      'fx',
                      MarketObservation(
                        key: '${j['base']}/${j['quote']}',
                        currency: j['quote']!,
                        source: 'Manual reference override',
                        value: number(j, 'rate'),
                        effectiveAt: DateTime.parse(j['date']!),
                        retrievedAt: DateTime.now(),
                        manual: true,
                      ),
                    );
              },
            );
          },
          child: const Text('Add override'),
        ),
      ],
    ),
  );
}

Future<void> templates(BuildContext context, WidgetRef ref) async {
  final store = ref.read(financeStoreProvider),
      rows = await ref.read(financeStoreProvider).list('templates');
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Transaction templates'),
      content: SizedBox(
        width: 440,
        height: 350,
        child: ListView(
          children: [
            for (final j in rows)
              ListTile(
                title: Text(j['name']),
                subtitle: Text('${j['type']} · ${j['amount']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await store.remove('templates', j['id']);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _templateForm(context, ref, j);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _templateForm(context, ref, null);
          },
          child: const Text('New template'),
        ),
      ],
    ),
  );
}

Future<void> _templateForm(BuildContext context, WidgetRef ref, Json? j) async {
  final accounts = ref.read(accountsProvider).valueOrNull ?? [],
      categories = ref.read(categoriesProvider).valueOrNull ?? [];
  await financeForm(
    context,
    title: j == null ? 'Save template' : 'Review template transaction',
    fields: [
      FinanceField('name', 'Template name', initial: j?['name'] ?? ''),
      FinanceField(
        'type',
        'Type',
        initial: j?['type'] ?? 'expense',
        options: const {'expense': 'Expense', 'income': 'Income'},
      ),
      FinanceField(
        'account',
        'Account',
        initial: j?['account'] ?? '',
        options: {
          for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
        },
      ),
      FinanceField(
        'category',
        'Category',
        initial: j?['category'] ?? '',
        options: {
          for (final c in categories) '${c.id}': '${c.name} (${c.type})',
        },
      ),
      FinanceField(
        'amount',
        'Amount in account currency',
        initial: j?['amount'] ?? '',
        numeric: true,
      ),
      FinanceField('note', 'Note', initial: j?['note'] ?? '', required: false),
    ],
    submit: j == null ? 'Save template' : 'Record transaction',
    save: (data) async {
      if (j == null) {
        ref.read(financialLedgerProvider).positive(number(data, 'amount'));
        final id = ref.read(financialLedgerProvider).newId();
        await ref.read(financeStoreProvider).put('templates', id, {
          'id': id,
          ...data,
        });
      } else {
        await ref
            .read(financialLedgerProvider)
            .recordCash(
              accountId: int.parse(data['account']!),
              categoryId: int.parse(data['category']!),
              amount: number(data, 'amount'),
              type: data['type']!,
              note: data['note'],
            );
      }
    },
  );
}

Future<void> subcategory(BuildContext context, WidgetRef ref) async {
  final categories = ref.read(categoriesProvider).valueOrNull ?? [];
  await financeForm(
    context,
    title: 'Assign subcategory',
    fields: [
      FinanceField(
        'child',
        'Child category',
        options: {
          for (final c in categories) '${c.id}': '${c.name} (${c.type})',
        },
      ),
      FinanceField(
        'parent',
        'Parent category',
        options: {
          'none': 'No parent',
          for (final c in categories) '${c.id}': '${c.name} (${c.type})',
        },
      ),
    ],
    save: (j) => CategoryHierarchy.assignParent(
      ref.read(financeStoreProvider),
      categories,
      child: int.parse(j['child']!),
      parent: int.tryParse(j['parent']!),
    ),
  );
}

Future<void> receipts(BuildContext context, WidgetRef ref) async {
  final rows = await ref.read(financeStoreProvider).list('attachments');
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Receipts'),
      content: SizedBox(
        width: 440,
        height: 350,
        child: ListView(
          children: [
            for (final r in rows)
              ListTile(
                title: Text('Transaction ${r['transactionId']}'),
                subtitle: Text(r['date']),
                onTap: () => showDialog(
                  context: ctx,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.file(File(r['path'])),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final file = await FilePicker.platform.pickFiles(
              type: FileType.image,
            );
            if (file?.files.single.path == null || !context.mounted) return;
            final transactions = await ref
                .read(databaseProvider)
                .getAllTransactions();
            if (!context.mounted) return;
            await financeForm(
              context,
              title: 'Attach receipt',
              fields: [
                FinanceField(
                  'transaction',
                  'Transaction',
                  options: {
                    for (final t in transactions)
                      '${t.id}':
                          '${t.transactionDate.toIso8601String().substring(0, 10)} · ${t.amount} · ${t.note ?? t.type}',
                  },
                ),
              ],
              save: (j) async {
                final id = ref.read(financialLedgerProvider).newId(),
                    dir = await getApplicationDocumentsDirectory();
                final target = await File(file!.files.single.path!).copy(
                  path.join(
                    dir.path,
                    'receipt-$id${path.extension(file.files.single.path!)}',
                  ),
                );
                await ref.read(financeStoreProvider).put('attachments', id, {
                  'id': id,
                  'path': target.path,
                  'transactionId': int.parse(j['transaction']!),
                  'date': DateTime.now().toIso8601String(),
                });
              },
            );
          },
          child: const Text('Attach receipt'),
        ),
      ],
    ),
  );
}

Future<void> exportEncrypted(BuildContext context, WidgetRef ref) =>
    financeForm(
      context,
      title: 'Encrypted backup',
      fields: [
        const FinanceField(
          'password',
          'Password (10+ characters)',
          secret: true,
        ),
      ],
      submit: 'Export',
      save: (j) async {
        final text = await BackupService(
          ref.read(databaseProvider),
        ).encrypt(j['password']!);
        final file = File(
          path.join(
            (await getTemporaryDirectory()).path,
            'flourish-${DateTime.now().millisecondsSinceEpoch}.encrypted.json',
          ),
        );
        await file.writeAsString(text, flush: true);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Flourish encrypted backup');
      },
    ).then((_) {});
Future<void> restoreEncrypted(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (picked?.files.single.path == null || !context.mounted) return;
  await financeForm(
    context,
    title: 'Replace current finances from backup',
    fields: [
      const FinanceField('password', 'Backup password', secret: true),
      const FinanceField('confirm', 'Type RESTORE to replace all current data'),
    ],
    submit: 'Restore',
    save: (j) async {
      if (j['confirm'] != 'RESTORE') {
        throw ArgumentError('Type RESTORE to confirm replacement');
      }
      final service = BackupService(ref.read(databaseProvider)),
          text = await File(picked!.files.single.path!).readAsString();
      final data = await service.decrypt(text, j['password']!);
      await service.automaticBackup();
      await service.restore(data);
      invalidateFinance(ref);
    },
  );
}

void invalidateFinance(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(defaultCurrencyProvider);
  ref.invalidate(appThemeModeProvider);
  ref.read(databaseProvider).notifyFinanceChanged();
}

Future<void> backupHistory(BuildContext context, WidgetRef ref) async {
  final dir = Directory(
    path.join((await getApplicationDocumentsDirectory()).path, 'backups'),
  );
  final files = await dir.exists()
      ? await dir.list().where((f) => f.path.endsWith('.json')).toList()
      : <FileSystemEntity>[];
  files.sort((a, b) => b.path.compareTo(a.path));
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Local backup history'),
      content: SizedBox(
        width: 440,
        height: 350,
        child: ListView(
          children: [
            for (final file in files)
              ListTile(
                title: Text(path.basename(file.path)),
                onTap: () {
                  Navigator.pop(ctx);
                  financeForm(
                    context,
                    title: 'Restore this local backup',
                    fields: [
                      const FinanceField(
                        'confirm',
                        'Type RESTORE to replace current data',
                      ),
                    ],
                    save: (j) async {
                      if (j['confirm'] != 'RESTORE') {
                        throw ArgumentError('Type RESTORE to confirm');
                      }
                      final data =
                          jsonDecode(await File(file.path).readAsString())
                              as Json;
                      await BackupService(
                        ref.read(databaseProvider),
                      ).restore(data);
                      invalidateFinance(ref);
                    },
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> exportCsv(BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider),
      accounts = {
        for (final a in await ref.read(databaseProvider).getAllAccounts())
          a.id: a,
      },
      categories = {
        for (final c in await ref.read(databaseProvider).getAllCategories())
          c.id: c,
      };
  String quote(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';
  final lines = <List<Object?>>[
    [
      'Date',
      'Income/Expense',
      'Account',
      'Category',
      'Amount',
      'Currency',
      'Note',
    ],
  ];
  for (final t in await db.getAllTransactions()) {
    lines.add([
      t.transactionDate.toIso8601String(),
      t.type,
      accounts[t.accountId]?.name,
      categories[t.categoryId]?.name,
      t.amount,
      accounts[t.accountId]?.currency,
      t.note,
    ]);
  }
  final file = File(
    path.join(
      (await getTemporaryDirectory()).path,
      'flourish-transactions.csv',
    ),
  );
  await file.writeAsString(
    lines.map((r) => r.map(quote).join(',')).join('\r\n'),
  );
  await Share.shareXFiles([XFile(file.path)]);
}

Future<void> importSpreadsheet(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (picked?.files.single.path == null) return;
    final service = SpreadsheetImportService(ref.read(financialLedgerProvider)),
        sheets = await SpreadsheetImportService(
          ref.read(financialLedgerProvider),
        ).read(File(picked!.files.single.path!));
    if (sheets.isEmpty || !context.mounted) return;
    String selected = sheets.keys.first;
    int header = 0;
    final chosen = await financeForm(
      context,
      title: 'Choose spreadsheet table',
      fields: [
        FinanceField(
          'sheet',
          'Worksheet',
          initial: selected,
          options: {for (final name in sheets.keys) name: name},
        ),
        const FinanceField(
          'header',
          'Header row number',
          initial: '1',
          numeric: true,
        ),
      ],
      save: (j) async {
        selected = j['sheet']!;
        header = int.parse(j['header']!) - 1;
        if (header < 0 || header >= sheets[selected]!.length) {
          throw ArgumentError('Invalid header row');
        }
      },
    );
    if (!context.mounted || chosen != true) return;
    final matrix = sheets[selected]!;
    final columns = {
      for (var i = 0; i < matrix[header].length; i++)
        '$i': matrix[header][i].isEmpty ? 'Column ${i + 1}' : matrix[header][i],
    };
    final aliases = {
      'date': ['date'],
      'type': ['income/expense', 'type'],
      'account': ['account'],
      'category': ['category'],
      'amount': ['amount'],
      'currency': ['currency'],
      'note': ['note', 'description'],
      'destination': ['destination', 'to account'],
    };
    await financeForm(
      context,
      title: 'Map columns',
      fields: [
        for (final e in aliases.entries)
          FinanceField(
            e.key,
            e.key,
            initial:
                columns.entries
                    .where(
                      (c) => e.value.contains(c.value.toLowerCase().trim()),
                    )
                    .firstOrNull
                    ?.key ??
                '-1',
            options: {'-1': 'Not mapped', ...columns},
          ),
        const FinanceField(
          'sign',
          'Amount convention',
          initial: 'typed',
          options: {
            'typed': 'Positive amounts with a Type column',
            'signed': 'Signed bank amounts: negative = expense',
          },
        ),
        const FinanceField(
          'decimal',
          'Decimal separator',
          initial: '.',
          options: {'.': 'Period (1,234.56)', ',': 'Comma (1.234,56)'},
        ),
        const FinanceField(
          'pattern',
          'Date format for non-ISO dates',
          initial: 'dd/MM/yyyy',
        ),
      ],
      submit: 'Preview',
      save: (j) async {
        final mapping = {
          for (final key in aliases.keys) key: int.parse(j[key]!),
        };
        if ([
          'date',
          if (j['sign'] != 'signed') 'type',
          'account',
          'amount',
        ].any((k) => mapping[k] == -1)) {
          throw ArgumentError('Map date, type, account, and amount');
        }
        final preview = await service.preview(
          matrix.skip(header + 1).toList(),
          mapping,
          fallbackCurrency: ref.read(defaultCurrencyProvider),
          datePattern: j['pattern']!,
          signedAmounts: j['sign'] == 'signed',
          decimalSeparator: j['decimal']!,
        );
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              '${preview.rows.length} records · ${preview.duplicates} duplicates skipped',
            ),
            content: SizedBox(
              width: 480,
              height: 400,
              child: ListView(
                children: [
                  const Text(
                    'Imported history changes account balances. Reconcile opening balances afterward if necessary.',
                  ),
                  for (final error in preview.errors)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  for (final row in preview.rows.take(50))
                    ListTile(
                      title: Text('${row['date']} · ${row['type']}'),
                      subtitle: Text('${row['account']} · ${row['category']}'),
                      trailing: Text('${row['amount']} ${row['currency']}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: preview.errors.isNotEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );
        if (confirmed != true) throw StateError('Import cancelled');
        await service.apply(preview);
        invalidateFinance(ref);
      },
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import: $e')));
    }
  }
}
