import 'package:csv/csv.dart' as csv;
import '../../core/finance/payment_methods.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/finance_providers.dart';
import '../providers/account_providers.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import '../providers/theme_providers.dart';
import '../../core/finance/backup_service.dart';
import '../../core/ai/ai_column_mapper.dart';
import '../../core/finance/import/import_sources.dart';
import '../../core/utils/error_text.dart';
import '../providers/ai_providers.dart';
import 'import_review_screen.dart';
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
        title: const Text('Import from other apps'),
        subtitle: const Text(
          'Money Manager, Wallet, Monefy, Spendee, YNAB, bank CSV, OFX, QIF '
          'or Excel · review before anything is added',
        ),
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
  final db = ref.read(databaseProvider);
  // The currency defines every stored amount, so it can only change before
  // anything has been recorded against the account.
  final currencyLocked = await db.accountHasHistory(a.id);
  if (!context.mounted) return;
  await financeForm(
    context,
    title: 'Manage ${a.name}',
    fields: [
      FinanceField('name', 'Account name', initial: a.name),
      if (!currencyLocked)
        FinanceField(
          'currency',
          'Currency',
          initial: a.currency,
          options: currencies,
        ),
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
      FinanceField(
        'balance',
        a.type == 'credit'
            ? 'Amount owed per statement (optional)'
            : 'Reconciled balance (optional)',
        required: false,
        numeric: true,
      ),
      const FinanceField('reason', 'Reconciliation reason', required: false),
    ],
    save: (j) async {
      final store = ref.read(financeStoreProvider);
      await db.transaction(() async {
        final current = await db.getAccountById(a.id);
        if (current == null) throw StateError('Account no longer exists');
        await db.updateAccount(current.copyWith(name: j['name']));
        if (j['currency'] case final currency?
            when currency != current.currency) {
          await db.changeAccountCurrency(a.id, currency);
        }
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
                  initial: 'USD' == ref.read(defaultCurrencyProvider)
                      ? 'EUR'
                      : 'USD',
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
      categories = ref.read(pickableCategoriesProvider).valueOrNull ?? [];
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
  final categories = ref.read(pickableCategoriesProvider).valueOrNull ?? [];
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
    save: (j) async {
      final child = int.parse(j['child']!), parent = int.tryParse(j['parent']!);
      final store = ref.read(financeStoreProvider);
      if (parent == null) {
        await store.remove('categoryParents', '$child');
        return;
      }
      if (child == parent ||
          categories.firstWhere((c) => c.id == child).type !=
              categories.firstWhere((c) => c.id == parent).type) {
        throw ArgumentError('Choose different categories of the same type');
      }
      final relationships = await store.list('categoryParents');
      var cursor = parent;
      final seen = {child};
      while (true) {
        if (!seen.add(cursor)) {
          throw ArgumentError('Category hierarchy cannot contain a cycle');
        }
        final next =
            relationships
                    .where((r) => r['child'] == cursor)
                    .firstOrNull?['parent']
                as int?;
        if (next == null) break;
        cursor = next;
      }
      await store.put('categoryParents', '$child', {
        'child': child,
        'parent': parent,
      });
    },
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
      // Added after the original seven columns so older importers still
      // read the file.
      'Merchant',
      'Paid with',
      'Original amount',
      'Original currency',
    ],
  ];
  final rows = await db.getAllTransactions();
  final details = await ref
      .read(financeStoreProvider)
      .transactionDetailsFor(rows.map((t) => t.id));
  final instruments = {
    for (final i in await db.getPaymentInstruments()) i.id: i,
  };
  for (final t in rows) {
    final d = details[t.id];
    final original = d?['original'] as Map?;
    lines.add([
      t.transactionDate.toIso8601String(),
      t.type,
      accounts[t.accountId]?.name,
      categories[t.categoryId]?.name,
      d?['amount'] ?? t.amount,
      accounts[t.accountId]?.currency,
      t.note,
      t.merchant,
      instruments[t.paymentInstrumentId]?.label ??
          (t.paymentMethod == null
              ? null
              : PaymentMethods.label(t.paymentMethod!)),
      original?['amount'],
      original?['currency'],
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
    // iOS only offers files whose type it knows, and OFX/QIF have no system
    // type, so the picker is unfiltered and the extension is checked here.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final filePath = picked?.files.single.path;
    if (filePath == null || !context.mounted) return;
    final name = path.basename(filePath);
    final lower = name.toLowerCase();
    if (!RegExp(r'\.(csv|txt|tsv|xlsx|ofx|qfx|qif)$').hasMatch(lower)) {
      throw const FormatException(
        'Choose a CSV, Excel (.xlsx), OFX/QFX or QIF file',
      );
    }
    final legacy = SpreadsheetImportService(ref.read(financialLedgerProvider));
    final options = ImportOptions(
      defaultCurrency: ref.read(defaultCurrencyProvider),
    );

    // Spreadsheets are read as CSV so app presets recognise them too.
    List<List<String>>? matrix;
    String content;
    if (lower.endsWith('.xlsx')) {
      final sheets = await legacy.read(File(filePath));
      if (sheets.isEmpty || !context.mounted) return;
      var selected = sheets.keys.first;
      if (sheets.length > 1) {
        final chosen = await financeForm(
          context,
          title: 'Choose worksheet',
          fields: [
            FinanceField(
              'sheet',
              'Worksheet',
              initial: selected,
              options: {for (final n in sheets.keys) n: n},
            ),
          ],
          save: (j) async => selected = j['sheet']!,
        );
        if (chosen != true || !context.mounted) return;
      }
      matrix = sheets[selected]!;
      content = csv.csv.encode(matrix);
    } else {
      content = utf8.decode(
        await File(filePath).readAsBytes(),
        allowMalformed: true,
      );
    }

    final source = ImportSources.detect(
      lower.endsWith('.xlsx') ? 'sheet.csv' : name,
      content,
    );
    if (!context.mounted) return;
    if (source != null) {
      await _openImportReview(
        context,
        source.parse(content, options: options),
        source.name,
      );
      return;
    }
    if (RegExp(r'\.(ofx|qfx|qif)$').hasMatch(lower)) {
      throw const FormatException('This file could not be read');
    }
    matrix ??= csv.csv
        .decode(content)
        .map((r) => r.map((v) => v?.toString() ?? '').toList())
        .toList();
    if (!context.mounted) return;
    await _manualImport(context, ref, matrix, legacy);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import: ${describeError(e)}')));
    }
  }
}

Future<void> _openImportReview(
  BuildContext context,
  ImportParseResult parsed,
  String sourceName,
) async {
  if (parsed.rows.isEmpty) {
    throw FormatException(
      parsed.errors.isEmpty
          ? 'No transactions found in this file'
          : parsed.errors.first.toString(),
    );
  }
  if (!context.mounted) return;
  // Above the tab shell, so the floating tab bar does not cover the button.
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<bool>(
      builder: (_) => ImportReviewScreen(parsed: parsed, sourceName: sourceName),
    ),
  );
}

/// A file no preset recognises: the person maps the columns (optionally
/// pre-filled by the AI), then reviews like any other import.
Future<void> _manualImport(
  BuildContext context,
  WidgetRef ref,
  List<List<String>> matrix,
  SpreadsheetImportService legacy,
) async {
  if (matrix.isEmpty) throw const FormatException('The file is empty');
  var header = 0;
  final headerChosen = await financeForm(
    context,
    title: 'Which row has the column names?',
    fields: const [
      FinanceField('header', 'Header row number', initial: '1', numeric: true),
    ],
    save: (j) async {
      header = int.parse(j['header']!) - 1;
      if (header < 0 || header >= matrix.length) {
        throw ArgumentError('Invalid header row');
      }
    },
  );
  if (headerChosen != true || !context.mounted) return;
  final names = matrix[header];
  final body = matrix.skip(header + 1).toList();
  final columns = {
    for (var i = 0; i < names.length; i++)
      '$i': names[i].isEmpty ? 'Column ${i + 1}' : names[i],
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

  AiColumnMapping? ai;
  final client = await ref.read(aiClientProvider.future);
  if (client != null && context.mounted) {
    final ask = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Map the columns with AI?'),
        content: const Text(
          'Sends the column names and 5 rows, with account numbers, phones '
          'and emails masked. You can change every choice afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Map myself'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use AI'),
          ),
        ],
      ),
    );
    if (ask == true) {
      try {
        ai = await AiColumnMapper(
          client,
          usage: ref.read(aiUsageTrackerProvider),
        ).map(names, body);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI mapping unavailable: ${describeError(e)}')),
          );
        }
      }
    }
  }
  if (!context.mounted) return;

  String initialFor(String key) {
    final fromAi = ai?.columns[key];
    if (fromAi != null) return '$fromAi';
    return columns.entries
            .where((c) => aliases[key]!.contains(c.value.toLowerCase().trim()))
            .firstOrNull
            ?.key ??
        '-1';
  }

  ImportParseResult? parsed;
  await financeForm(
    context,
    title: ai == null ? 'Map columns' : 'Map columns (suggested by AI)',
    fields: [
      for (final key in aliases.keys)
        FinanceField(
          key,
          key,
          initial: initialFor(key),
          options: {'-1': 'Not mapped', ...columns},
        ),
      FinanceField(
        'sign',
        'Amount convention',
        initial: ai?.signedAmounts == true ? 'signed' : 'typed',
        options: const {
          'typed': 'Positive amounts with a Type column',
          'signed': 'Signed bank amounts: negative = expense',
        },
      ),
      FinanceField(
        'decimal',
        'Decimal separator',
        initial: ai?.decimalSeparator ?? '.',
        options: const {'.': 'Period (1,234.56)', ',': 'Comma (1.234,56)'},
      ),
      FinanceField(
        'pattern',
        'Date format for non-ISO dates',
        initial: ai?.dateFormat ?? 'dd/MM/yyyy',
      ),
    ],
    submit: 'Review',
    save: (j) async {
      final mapping = {for (final key in aliases.keys) key: int.parse(j[key]!)};
      if ([
        'date',
        if (j['sign'] != 'signed') 'type',
        'account',
        'amount',
      ].any((k) => mapping[k] == -1)) {
        throw ArgumentError('Map date, type, account, and amount');
      }
      final preview = await legacy.preview(
        body,
        mapping,
        fallbackCurrency: ref.read(defaultCurrencyProvider),
        datePattern: j['pattern']!,
        signedAmounts: j['sign'] == 'signed',
        decimalSeparator: j['decimal']!,
      );
      parsed = legacy.toParseResult(preview, firstLine: header + 2);
    },
  );
  final result = parsed;
  if (result == null || !context.mounted) return;
  await _openImportReview(context, result, 'Spreadsheet');
}
