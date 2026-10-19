import 'package:flourish/shared/category_label.dart';
import 'package:csv/csv.dart' as csv;
import '../../core/finance/payment_methods.dart';
import 'dart:async';
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
import '../../core/ai/ai_statement_reader.dart';
import '../../core/finance/import/pdf_statement.dart';
import '../../core/finance/import/pdf_text_reader.dart';
import 'package:pdfrx/pdfrx.dart' show PdfPasswordException;
import '../../core/finance/import/import_sources.dart';
import '../../core/finance/import/import_window.dart';
import '../../core/utils/error_text.dart';
import '../providers/ai_providers.dart';
import 'import_review_screen.dart';
import '../../core/finance/spreadsheet_import_service.dart';
import '../../core/services/preferences_service.dart';
import '../../data/database/database.dart';
import 'finance_form.dart';
import 'holdings_view.dart';
import 'finance_runtime.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/settings_group.dart';

class FinanceToolsView extends ConsumerWidget {
  const FinanceToolsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lockOn = PreferencesService.getBool('app_lock_enabled');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Sp.screenH,
        Sp.md,
        Sp.screenH,
        Sp.bottomNavClear,
      ),
      children: [
        SettingsGroup(
          title: l.toolsMoney,
          children: [
            SettingsTile(
              icon: Icons.currency_exchange,
              title: l.exchangeRates,
              subtitle: l.exchangeRatesSubtitle,
              onTap: () => exchangeRates(context, ref),
            ),
            SettingsTile(
              icon: Icons.account_balance,
              tint: const Color(0xFF5B9DF5),
              title: l.manageAccounts,
              subtitle: l.manageAccountsSubtitle,
              onTap: () => manageAccounts(context, ref),
            ),
            SettingsTile(
              icon: Icons.bookmark_outline,
              tint: const Color(0xFFF5B547),
              title: l.savedTemplates,
              subtitle: l.savedTemplatesSubtitle,
              onTap: () => templates(context, ref),
            ),
            SettingsTile(
              icon: Icons.account_tree_outlined,
              tint: const Color(0xFF3CC8C0),
              title: l.subcategories,
              subtitle: l.subcategoriesSubtitle,
              onTap: () => subcategory(context, ref),
            ),
            SettingsTile(
              icon: Icons.receipt_long,
              tint: const Color(0xFF8B7CF6),
              title: l.receiptAttachments,
              subtitle: l.receiptAttachmentsSubtitle,
              onTap: () => receipts(context, ref),
            ),
            SettingsTile(
              icon: Icons.calendar_month,
              tint: const Color(0xFFEF8A47),
              title: l.reportingMonthStarts,
              subtitle: l.dayNumber(
                PreferencesService.getInt('month_start_day', defaultValue: 1),
              ),
              onTap: () => financeForm(
                context,
                title: l.reportingMonth,
                fields: [
                  FinanceField(
                    'day',
                    l.startDayRange,
                    initial: '1',
                    numeric: true,
                  ),
                ],
                save: (j) async {
                  final day = int.parse(j['day']!);
                  if (day < 1 || day > 28) {
                    throw ArgumentError(l.chooseDayRange);
                  }
                  await PreferencesService.setInt('month_start_day', day);
                  ref.read(databaseProvider).notifyFinanceChanged();
                },
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.toolsImportExport,
          children: [
            SettingsTile(
              icon: Icons.table_chart_outlined,
              title: l.importFromApps,
              subtitle: l.importFromAppsSubtitle,
              onTap: () => importSpreadsheet(context, ref),
            ),
            SettingsTile(
              icon: Icons.file_download_outlined,
              tint: const Color(0xFF5B9DF5),
              title: l.exportCsv,
              subtitle: l.exportCsvSubtitle,
              onTap: () => exportCsv(context, ref),
            ),
          ],
        ),
        SettingsGroup(
          title: l.toolsSecurity,
          children: [
            SettingsTile(
              icon: Icons.notifications_outlined,
              tint: const Color(0xFFF5B547),
              title: l.paymentReminders,
              subtitle: l.paymentRemindersSubtitle,
              onTap: () async {
                try {
                  await ref.read(remindersProvider).enable();
                  await ref
                      .read(remindersProvider)
                      .schedule(ref.read(financeStoreProvider));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.paymentRemindersEnabled)),
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
            SettingsTile(
              icon: Icons.lock_outline,
              tint: const Color(0xFF8B7CF6),
              title: l.deviceLock,
              subtitle: lockOn ? l.deviceLockOn : l.deviceLockOff,
              onTap: () async {
                try {
                  final auth = LocalAuthentication();
                  if (!await auth.isDeviceSupported()) {
                    throw StateError(l.setUpPasscodeFirst);
                  }
                  if (await auth.authenticate(
                    localizedReason: l.changeAppLockReason,
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
            SettingsTile(
              icon: Icons.vpn_key_outlined,
              tint: const Color(0xFF3CC8C0),
              title: l.stockApiKey,
              subtitle: l.stockApiKeySubtitle,
              onTap: () => financeForm(
                context,
                title: l.alphaVantageKey,
                fields: [FinanceField('key', l.personalApiKey, secret: true)],
                save: (j) => ref
                    .read(secureStorageProvider)
                    .write(key: 'alpha_vantage_key', value: j['key']),
              ),
            ),
            SettingsTile(
              icon: Icons.backup_outlined,
              title: l.exportBackup,
              subtitle: l.exportBackupSubtitle,
              onTap: () => exportEncrypted(context, ref),
            ),
            SettingsTile(
              icon: Icons.restore,
              tint: const Color(0xFF5B9DF5),
              title: l.restoreBackup,
              subtitle: l.restoreBackupSubtitle,
              onTap: () => restoreEncrypted(context, ref),
            ),
            SettingsTile(
              icon: Icons.history,
              tint: const Color(0xFFF5B547),
              title: l.backupHistory,
              subtitle: l.backupHistorySubtitle,
              onTap: () => backupHistory(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> manageAccounts(BuildContext context, WidgetRef ref) async {
  final accounts = await ref.read(databaseProvider).getAllAccounts();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.accountsTitle),
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
          child: Text(context.l10n.close),
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
    title: context.l10n.manageNamed(a.name),
    fields: [
      FinanceField('name', context.l10n.accountName, initial: a.name),
      if (!currencyLocked)
        FinanceField(
          'currency',
          context.l10n.currency,
          initial: a.currency,
          options: currencies,
        ),
      FinanceField(
        'institution',
        context.l10n.institution,
        initial: stored?['institution'] ?? '',
        required: false,
      ),
      FinanceField(
        'group',
        context.l10n.group,
        initial: stored?['group'] ?? '',
        required: false,
      ),
      FinanceField(
        'archived',
        context.l10n.archived,
        initial: stored?['archived'] == true ? 'yes' : 'no',
        options: {'no': context.l10n.active, 'yes': context.l10n.archived},
      ),
      FinanceField(
        'included',
        context.l10n.includeInWealth,
        initial: stored?['included'] == false ? 'no' : 'yes',
        options: {'yes': context.l10n.include, 'no': context.l10n.exclude},
      ),
      FinanceField(
        'balance',
        a.type == 'credit'
            ? context.l10n.owedPerStatement
            : context.l10n.reconciledBalance,
        required: false,
        numeric: true,
      ),
      FinanceField(
        'reason',
        context.l10n.reconciliationReason,
        required: false,
      ),
    ],
    save: (j) async {
      final store = ref.read(financeStoreProvider);
      await db.transaction(() async {
        final current = await db.getAccountById(a.id);
        if (current == null) throw StateError(currentL10n.accountGone);
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
      title: Text(context.l10n.reconciliationHistory),
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
          child: Text(context.l10n.close),
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
      title: Text(context.l10n.exchangeRates),
      content: SizedBox(
        width: 480,
        height: 400,
        child: ListView(
          children: [
            for (final r in active)
              ListTile(
                title: Text('${r.key} · ${r.value}'),
                subtitle: Text(
                  '${r.source}${r.manual ? ' · ${context.l10n.manualOverride}' : ''}\n${r.effectiveAt.toIso8601String().substring(0, 10)}',
                ),
                trailing: r.manual
                    ? IconButton(
                        tooltip: context.l10n.resumeAutomaticRate,
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
          child: Text(context.l10n.close),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            financeForm(
              context,
              title: context.l10n.manualExchangeRate,
              fields: [
                FinanceField(
                  'base',
                  context.l10n.from,
                  initial: 'USD' == ref.read(defaultCurrencyProvider)
                      ? 'EUR'
                      : 'USD',
                  options: currencies,
                ),
                FinanceField(
                  'quote',
                  context.l10n.to,
                  initial: 'EGP',
                  options: currencies,
                ),
                FinanceField(
                  'rate',
                  context.l10n.oneSourceUnitEquals,
                  numeric: true,
                ),
                FinanceField(
                  'date',
                  context.l10n.effectiveDate,
                  initial: today(),
                  date: true,
                ),
              ],
              save: (j) async {
                if (j['base'] == j['quote']) {
                  throw ArgumentError(currentL10n.chooseDifferentCurrencies);
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
          child: Text(context.l10n.addOverride),
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
      title: Text(context.l10n.transactionTemplates),
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
          child: Text(context.l10n.close),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _templateForm(context, ref, null);
          },
          child: Text(context.l10n.newTemplate),
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
    title: j == null
        ? context.l10n.saveTemplate
        : context.l10n.reviewTemplateTx,
    fields: [
      FinanceField(
        'name',
        context.l10n.templateName,
        initial: j?['name'] ?? '',
      ),
      FinanceField(
        'type',
        context.l10n.type,
        initial: j?['type'] ?? 'expense',
        options: {
          'expense': context.l10n.expense,
          'income': context.l10n.income,
        },
      ),
      FinanceField(
        'account',
        context.l10n.account,
        initial: j?['account'] ?? '',
        options: {
          for (final a in accounts) '${a.id}': '${a.name} (${a.currency})',
        },
      ),
      FinanceField(
        'category',
        context.l10n.category,
        initial: j?['category'] ?? '',
        options: {
          for (final c in categories) '${c.id}': '${c.displayName} (${c.type})',
        },
      ),
      FinanceField(
        'amount',
        context.l10n.amountInAccountCurrency,
        initial: j?['amount'] ?? '',
        numeric: true,
      ),
      FinanceField(
        'note',
        context.l10n.note,
        initial: j?['note'] ?? '',
        required: false,
      ),
    ],
    submit: j == null
        ? context.l10n.saveTemplate
        : context.l10n.recordTransaction,
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
    title: context.l10n.assignSubcategory,
    fields: [
      FinanceField(
        'child',
        context.l10n.childCategory,
        options: {
          for (final c in categories) '${c.id}': '${c.displayName} (${c.type})',
        },
      ),
      FinanceField(
        'parent',
        context.l10n.parentCategory,
        options: {
          'none': context.l10n.noParent,
          for (final c in categories) '${c.id}': '${c.displayName} (${c.type})',
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
        throw ArgumentError(currentL10n.chooseDifferentCategories);
      }
      final relationships = await store.list('categoryParents');
      var cursor = parent;
      final seen = {child};
      while (true) {
        if (!seen.add(cursor)) {
          throw ArgumentError(currentL10n.categoryCycle);
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
      title: Text(context.l10n.receipts),
      content: SizedBox(
        width: 440,
        height: 350,
        child: ListView(
          children: [
            for (final r in rows)
              ListTile(
                title: Text(
                  context.l10n.transactionNumber('${r['transactionId']}'),
                ),
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
          child: Text(context.l10n.close),
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
              title: context.l10n.attachReceipt,
              fields: [
                FinanceField(
                  'transaction',
                  context.l10n.transaction,
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
          child: Text(context.l10n.attachReceipt),
        ),
      ],
    ),
  );
}

Future<void> exportEncrypted(BuildContext context, WidgetRef ref) =>
    financeForm(
      context,
      title: context.l10n.encryptedBackup,
      fields: [
        FinanceField('password', context.l10n.passwordMin10, secret: true),
      ],
      submit: context.l10n.export,
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
    title: context.l10n.replaceFromBackup,
    fields: [
      FinanceField('password', context.l10n.backupPassword, secret: true),
      FinanceField('confirm', context.l10n.typeRestoreReplaceAll),
    ],
    submit: context.l10n.restore,
    save: (j) async {
      if (j['confirm'] != 'RESTORE') {
        throw ArgumentError(currentL10n.typeRestoreConfirm);
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
      title: Text(context.l10n.localBackupHistory),
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
                    title: context.l10n.restoreLocalBackup,
                    fields: [
                      FinanceField('confirm', context.l10n.typeRestoreReplace),
                    ],
                    save: (j) async {
                      if (j['confirm'] != 'RESTORE') {
                        throw ArgumentError(currentL10n.typeRestoreConfirm);
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
          child: Text(context.l10n.close),
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
    // Headers stay English in every language so the file imports back.
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

/// [since] limits the review to rows on or after that day and switches it
/// to catch-up mode (only payments missing from Flourish are asked about).
Future<void> importSpreadsheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? since,
}) async {
  try {
    // iOS only offers files whose type it knows, and OFX/QIF have no system
    // type, so the picker is unfiltered and the extension is checked here.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final filePath = picked?.files.single.path;
    if (filePath == null || !context.mounted) return;
    final name = path.basename(filePath);
    final lower = name.toLowerCase();
    if (!RegExp(r'\.(csv|txt|tsv|xlsx|ofx|qfx|qif|pdf)$').hasMatch(lower)) {
      throw FormatException(currentL10n.chooseImportFile);
    }
    final legacy = SpreadsheetImportService(ref.read(financialLedgerProvider));
    final options = ImportOptions(
      defaultCurrency: ref.read(defaultCurrencyProvider),
    );
    if (lower.endsWith('.pdf')) {
      await _importPdf(context, ref, filePath, options, since: since);
      return;
    }

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
          title: context.l10n.chooseWorksheet,
          fields: [
            FinanceField(
              'sheet',
              context.l10n.worksheet,
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
        since: since,
      );
      return;
    }
    if (RegExp(r'\.(ofx|qfx|qif)$').hasMatch(lower)) {
      throw FormatException(currentL10n.fileUnreadable);
    }
    matrix ??= csv.csv
        .decode(content)
        .map((r) => r.map((v) => v?.toString() ?? '').toList())
        .toList();
    if (!context.mounted) return;
    await _manualImport(context, ref, matrix, legacy, since: since);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.importError(describeError(e)))),
      );
    }
  }
}

/// A PDF statement: the table heuristic first, then (when it finds nothing
/// and AI is set up) the AI, page by page, after the person agrees.
Future<void> _importPdf(
  BuildContext context,
  WidgetRef ref,
  String filePath,
  ImportOptions options, {
  DateTime? since,
}) async {
  final List<StatementPage> pages;
  try {
    pages = await PdfTextReader.read(
      filePath,
      password: () => _askPdfPassword(context),
    );
  } on PdfPasswordException {
    throw FormatException(currentL10n.pdfPasswordProtected);
  }
  if (!context.mounted) return;
  if (!PdfStatementParser.hasTextLayer(pages)) {
    throw FormatException(currentL10n.pdfNoText);
  }
  final local = PdfStatementParser.parse(pages, options: options);
  if (local.rows.isNotEmpty) {
    await _openImportReview(
      context,
      local,
      context.l10n.pdfStatement,
      since: since,
    );
    return;
  }

  final client = await ref.read(aiClientProvider.future);
  if (client == null) {
    throw FormatException(currentL10n.pdfNoTable);
  }
  if (!context.mounted) return;
  final reader = AiStatementReader(
    client,
    usage: ref.read(aiUsageTrackerProvider),
  );
  final requests = reader.requestCount(pages);
  final provider = ref.read(aiSettingsProvider).preset;
  final ask = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.readStatementAi),
      content: Text(
        '${ctx.l10n.pdfAiBody(pages.length, requests, provider.label)}'
        '${provider.free ? '\n\n${ctx.l10n.freeTiersKeep}' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.useAi),
        ),
      ],
    ),
  );
  if (ask != true || !context.mounted) return;

  final progress = ValueNotifier<String>(
    context.l10n.readingPage(1, pages.length),
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: progress,
                  builder: (_, text, _) => Text(text),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ImportParseResult parsed;
  try {
    parsed = await reader.read(
      pages,
      options: options,
      onProgress: (done, total) => progress.value = currentL10n.readingPart(
        done < total ? done + 1 : total,
        total,
      ),
    );
  } finally {
    navigator.pop();
    progress.dispose();
  }
  if (!context.mounted) return;
  if (parsed.rows.isEmpty) {
    throw FormatException(
      parsed.warnings.isEmpty
          ? context.l10n.aiNoTransactionsPdf
          : parsed.warnings.first.message,
    );
  }
  await _openImportReview(
    context,
    parsed,
    context.l10n.pdfStatementAi,
    since: since,
  );
}

String _columnLabel(AppLocalizations l, String key) => switch (key) {
  'date' => l.date,
  'type' => l.type,
  'account' => l.account,
  'category' => l.category,
  'amount' => l.amount,
  'currency' => l.currency,
  'note' => l.note,
  'destination' => l.toAccount,
  _ => key,
};

Future<String?> _askPdfPassword(BuildContext context) async {
  if (!context.mounted) return null;
  // Not disposed here: the dialog still uses it while it animates out.
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.pdfPassword),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        decoration: InputDecoration(
          labelText: context.l10n.password,
          helperText: context.l10n.pdfPasswordHint,
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(context.l10n.open),
        ),
      ],
    ),
  );
}

Future<void> _openImportReview(
  BuildContext context,
  ImportParseResult parsed,
  String sourceName, {
  DateTime? since,
}) async {
  if (since != null) {
    parsed = parsed.since(
      since,
      olderWarning: (n) => currentL10n.catchUpOlderLeftOut(n),
    );
  }
  if (parsed.rows.isEmpty) {
    throw FormatException(
      parsed.errors.isEmpty
          ? currentL10n.noTransactionsInFile
          : parsed.errors.first.toString(),
    );
  }
  if (!context.mounted) return;
  // Above the tab shell, so the floating tab bar does not cover the button.
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<bool>(
      builder: (_) => ImportReviewScreen(
        parsed: parsed,
        sourceName: sourceName,
        catchUp: since != null,
      ),
    ),
  );
}

/// A file no preset recognises: the person maps the columns (optionally
/// pre-filled by the AI), then reviews like any other import.
Future<void> _manualImport(
  BuildContext context,
  WidgetRef ref,
  List<List<String>> matrix,
  SpreadsheetImportService legacy, {
  DateTime? since,
}) async {
  if (matrix.isEmpty) throw FormatException(currentL10n.fileEmpty);
  var header = 0;
  final headerChosen = await financeForm(
    context,
    title: context.l10n.whichHeaderRow,
    fields: [
      FinanceField(
        'header',
        context.l10n.headerRowNumber,
        initial: '1',
        numeric: true,
      ),
    ],
    save: (j) async {
      header = int.parse(j['header']!) - 1;
      if (header < 0 || header >= matrix.length) {
        throw ArgumentError(currentL10n.invalidHeaderRow);
      }
    },
  );
  if (headerChosen != true || !context.mounted) return;
  final names = matrix[header];
  final body = matrix.skip(header + 1).toList();
  final columns = {
    for (var i = 0; i < names.length; i++)
      '$i': names[i].isEmpty ? context.l10n.columnNumber(i + 1) : names[i],
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
        title: Text(context.l10n.mapColumnsAiTitle),
        content: const Text(
          'Sends the column names and 5 rows, with account numbers, phones '
          'and emails masked. You can change every choice afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.mapMyself),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.useAi),
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
            SnackBar(
              content: Text(
                context.l10n.aiMappingUnavailable(describeError(e)),
              ),
            ),
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
    title: ai == null ? context.l10n.mapColumns : context.l10n.mapColumnsAi,
    fields: [
      for (final key in aliases.keys)
        FinanceField(
          key,
          _columnLabel(context.l10n, key),
          initial: initialFor(key),
          options: {'-1': context.l10n.notMapped, ...columns},
        ),
      FinanceField(
        'sign',
        context.l10n.amountConvention,
        initial: ai?.signedAmounts == true ? 'signed' : 'typed',
        options: {
          'typed': context.l10n.typedAmounts,
          'signed': context.l10n.signedAmounts,
        },
      ),
      FinanceField(
        'decimal',
        context.l10n.decimalSeparator,
        initial: ai?.decimalSeparator ?? '.',
        options: {
          '.': context.l10n.decimalPeriod,
          ',': context.l10n.decimalComma,
        },
      ),
      FinanceField(
        'pattern',
        context.l10n.dateFormatNonIso,
        initial: ai?.dateFormat ?? 'dd/MM/yyyy',
      ),
    ],
    submit: context.l10n.review,
    save: (j) async {
      final mapping = {for (final key in aliases.keys) key: int.parse(j[key]!)};
      if ([
        'date',
        if (j['sign'] != 'signed') 'type',
        'account',
        'amount',
      ].any((k) => mapping[k] == -1)) {
        throw ArgumentError(currentL10n.mapRequiredColumns);
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
  await _openImportReview(
    context,
    result,
    context.l10n.spreadsheet,
    since: since,
  );
}
