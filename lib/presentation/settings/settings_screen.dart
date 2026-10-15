import 'package:flourish/core/utils/amount_parser.dart';
import '../../core/finance/backup_service.dart';
import '../../data/finance/finance_store.dart';
import '../wealth/finance_tools_view.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/constants/enums.dart';
import 'package:flourish/core/constants/app_constants.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/shared/widgets/pressable.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:flourish/core/services/preferences_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _incomeAmountController = TextEditingController();
  final _incomeDayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final amount = ref.read(monthlyIncomeAmountProvider);
    final day = ref.read(monthlyIncomeDayProvider);
    if (amount > 0) _incomeAmountController.text = amount.toStringAsFixed(0);
    if (day > 0) _incomeDayController.text = day.toString();
  }

  @override
  void dispose() {
    _incomeAmountController.dispose();
    _incomeDayController.dispose();
    super.dispose();
  }

  String _incomeCurrency() {
    final id = ref.read(monthlyIncomeAccountIdProvider);
    return ref
            .read(accountsProvider)
            .valueOrNull
            ?.where((a) => a.id == id)
            .firstOrNull
            ?.currency ??
        ref.read(defaultCurrencyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final autoIncome = ref.watch(monthlyAutoIncomeProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.sm, Sp.xl, Sp.xxxl),
          children: [
            _Group(
              title: 'Appearance',
              children: [
                _SettingTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  subtitle:
                      themeMode.name[0].toUpperCase() +
                      themeMode.name.substring(1),
                  trailing: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 16),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 16),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (v) {
                      Haptics.select();
                      ref.read(appThemeModeProvider.notifier).state = v.first;
                      persistSettings(ref);
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                _SettingTile(
                  icon: Icons.currency_exchange,
                  title: 'Default Currency',
                  subtitle: currency,
                  trailing: DropdownButton<String>(
                    value: currency,
                    underline: const SizedBox.shrink(),
                    items: AppConstants.currencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(defaultCurrencyProvider.notifier).state = v;
                        persistSettings(ref);
                      }
                    },
                  ),
                ),
              ],
            ),

            _Group(
              title: 'Manage',
              children: [
                _SettingTile(
                  icon: Icons.track_changes_rounded,
                  tint: const Color(0xFFF5B547),
                  title: 'Budgets',
                  subtitle: 'Spending limits by category',
                  // /budgets lives inside the tab shell; pushing it from
                  // here would build a second shell, so switch to it.
                  onTap: () => context.go('/budgets'),
                ),
                _SettingTile(
                  icon: Icons.flag_outlined,
                  tint: const Color(0xFF8B7CF6),
                  title: 'Savings Goals',
                  subtitle: 'Targets and progress',
                  onTap: () => context.push('/goals'),
                ),
                _SettingTile(
                  icon: Icons.repeat_rounded,
                  tint: const Color(0xFF3CC8C0),
                  title: 'Recurring',
                  subtitle: 'Bills, salaries and subscriptions',
                  onTap: () => context.push('/recurring'),
                ),
                _SettingTile(
                  icon: Icons.credit_card_rounded,
                  tint: const Color(0xFFEF4444),
                  title: 'Cards & wallets',
                  subtitle: 'Debit and credit cards, wallets, InstaPay',
                  onTap: () => context.push('/payment-methods'),
                ),
                _SettingTile(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Add, edit, or delete transaction categories',
                  onTap: () => context.push('/categories/manage'),
                ),
                _SettingTile(
                  icon: Icons.mark_email_unread_outlined,
                  tint: const Color(0xFF5B9DF5),
                  title: 'Payment detection',
                  subtitle: 'Find payments in bank and wallet alerts',
                  onTap: () => context.push('/settings/detection'),
                ),
                _SettingTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Smart Import',
                  subtitle: 'Paste bank alerts to create transactions',
                  onTap: () => context.push('/smart-import'),
                ),
              ],
            ),

            _Group(
              title: 'Monthly Auto Income',
              children: [
                _SettingTile(
                  icon: Icons.schedule,
                  title: 'Auto Monthly Income',
                  subtitle: autoIncome ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: autoIncome,
                    onChanged: (v) {
                      Haptics.select();
                      ref.read(monthlyAutoIncomeProvider.notifier).state = v;
                      persistSettings(ref);
                    },
                  ),
                ),
                if (autoIncome)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.lg,
                      Sp.sm,
                      Sp.lg,
                      Sp.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _incomeAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Monthly Income Amount',
                            hintText: 'e.g. 5000',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [AmountInputFormatter()],
                          onChanged: (v) {
                            final amt =
                                AmountParser.parse(
                                  v,
                                  currency: _incomeCurrency(),
                                ).value?.toDouble() ??
                                0;
                            ref
                                    .read(monthlyIncomeAmountProvider.notifier)
                                    .state =
                                amt;
                            PreferencesService.setDouble(
                              'monthly_income_amount',
                              amt,
                            );
                          },
                        ),
                        const SizedBox(height: Sp.md),
                        TextField(
                          controller: _incomeDayController,
                          decoration: const InputDecoration(
                            labelText: 'Day of Month',
                            hintText: '1-31',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final day = int.tryParse(v) ?? 1;
                            final clamped = day.clamp(1, 31).toInt();
                            ref.read(monthlyIncomeDayProvider.notifier).state =
                                clamped;
                            PreferencesService.setInt(
                              'monthly_income_day',
                              clamped,
                            );
                          },
                        ),
                        const SizedBox(height: Sp.md),
                        Text('Income Account', style: AppTextStyles.overline),
                        const SizedBox(height: Sp.xs),
                        accountsAsync.when(
                          data: (accounts) {
                            final selectedId = ref.watch(
                              monthlyIncomeAccountIdProvider,
                            );
                            final validId =
                                selectedId != null &&
                                    accounts.any((a) => a.id == selectedId)
                                ? selectedId
                                : (accounts.isNotEmpty
                                      ? accounts.first.id
                                      : null);
                            return DropdownButtonFormField<int>(
                              initialValue: validId,
                              decoration: const InputDecoration(
                                hintText: 'Select account',
                              ),
                              items: accounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  ref
                                          .read(
                                            monthlyIncomeAccountIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      v;
                                  PreferencesService.setInt(
                                    'monthly_income_account_id',
                                    v,
                                  );
                                }
                              },
                            );
                          },
                          loading: () => const SizedBox(height: 60),
                          error: (error, stackTrace) =>
                              const SizedBox(height: 60),
                        ),
                        const SizedBox(height: Sp.md),
                        Text('Income Category', style: AppTextStyles.overline),
                        const SizedBox(height: Sp.xs),
                        categoriesAsync.when(
                          data: (cats) {
                            final incomeCats = cats
                                .where((c) => c.type == 'income')
                                .toList();
                            final selectedId = ref.watch(
                              monthlyIncomeCategoryIdProvider,
                            );
                            final validId =
                                selectedId != null &&
                                    incomeCats.any((c) => c.id == selectedId)
                                ? selectedId
                                : (incomeCats.isNotEmpty
                                      ? incomeCats.first.id
                                      : null);
                            return DropdownButtonFormField<int>(
                              initialValue: validId,
                              decoration: const InputDecoration(
                                hintText: 'Select category',
                              ),
                              items: incomeCats
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        children: [
                                          CategoryIconWidget(
                                            iconName: c.icon,
                                            color: Color(c.color),
                                            size: 28,
                                            iconSize: 14,
                                          ),
                                          const SizedBox(width: Sp.sm),
                                          Text(c.name),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  ref
                                          .read(
                                            monthlyIncomeCategoryIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      v;
                                  PreferencesService.setInt(
                                    'monthly_income_category_id',
                                    v,
                                  );
                                }
                              },
                            );
                          },
                          loading: () => const SizedBox(height: 60),
                          error: (error, stackTrace) =>
                              const SizedBox(height: 60),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            _Group(
              title: 'Data',
              children: [
                _SettingTile(
                  icon: Icons.file_download_outlined,
                  title: 'Export Data',
                  subtitle: 'Save your data as JSON',
                  onTap: () => _exportData(ref),
                ),
                _SettingTile(
                  icon: Icons.file_upload_outlined,
                  title: 'Import Data',
                  subtitle: 'Restore from a JSON backup',
                  onTap: () => _importData(ref),
                ),
                _SettingTile(
                  icon: Icons.delete_outline,
                  title: 'Reset All Data',
                  subtitle: 'Delete all accounts, transactions, and budgets',
                  titleColor: AppColors.danger,
                  tint: AppColors.danger,
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),

            _Group(
              title: 'About',
              children: [
                _SettingTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
                _SettingTile(
                  icon: Icons.code,
                  title: 'Built with',
                  subtitle: 'Flutter & Drift',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportData(WidgetRef ref) async {
    try {
      final data = await BackupService(ref.read(databaseProvider)).exportData();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/flourish_backup.json');
      await file.writeAsString(jsonEncode(data));
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Flourish Backup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _importData(WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final hasData =
          data['format'] == 'flourish-finance' ||
          data['categories'] is List ||
          data['accounts'] is List ||
          data['transactions'] is List;
      if (!hasData) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or empty backup file.')),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup'),
          content: const Text(
            'This will erase all current data and replace it with the backup. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final db = ref.read(databaseProvider);
      final service = BackupService(db);
      await service.automaticBackup();
      if (data['format'] == 'flourish-finance') {
        await service.restore(data);
        invalidateFinance(ref);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complete backup restored.')),
          );
        }
        return;
      }
      int imported = 0;

      await db.customStatement('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction(() async {
          // A legacy backup replaces the entire portfolio as well.
          await db.customStatement('DELETE FROM finance_records');
          await db.customStatement('DELETE FROM exact_balances');
          await db.customStatement('DELETE FROM transaction_details');
          // Clear existing data in dependency-safe order.
          await db.delete(db.transactions).go();
          await db.delete(db.recurringTransactions).go();
          await db.delete(db.budgets).go();
          await db.delete(db.goals).go();
          await db.delete(db.paymentInstruments).go();
          await db.delete(db.accounts).go();
          await db.delete(db.categories).go();

          // Categories first (no FK dependencies).
          final categoriesRaw = data['categories'];
          if (categoriesRaw is List) {
            for (final item in categoriesRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.categories)
                  .insert(
                    CategoriesCompanion(
                      id: Value(item['id'] as int),
                      name: Value(item['name'] as String),
                      icon: Value(item['icon'] as String),
                      color: Value(item['color'] as int),
                      type: Value(item['type'] as String),
                      isDefault: Value(item['isDefault'] as bool? ?? false),
                      sortOrder: Value(
                        (item['sortOrder'] as num?)?.toInt() ?? 0,
                      ),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }

          // Accounts next.
          final accountsRaw = data['accounts'];
          if (accountsRaw is List) {
            for (final item in accountsRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.accounts)
                  .insert(
                    AccountsCompanion(
                      id: Value(item['id'] as int),
                      name: Value(item['name'] as String),
                      type: Value(item['type'] as String),
                      balance: Value((item['balance'] as num).toDouble()),
                      currency: Value(
                        item['currency'] as String? ??
                            ref.read(defaultCurrencyProvider),
                      ),
                      color: Value(item['color'] as int),
                      icon: Value(item['icon'] as String),
                      createdAt: _dateValue(item['createdAt']),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }

          // Transactions depend on accounts and categories.
          final transactionsRaw = data['transactions'];
          if (transactionsRaw is List) {
            for (final item in transactionsRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.transactions)
                  .insert(
                    TransactionsCompanion(
                      id: Value(item['id'] as int),
                      accountId: Value(item['accountId'] as int),
                      categoryId: Value(item['categoryId'] as int),
                      amount: Value((item['amount'] as num).toDouble()),
                      type: Value(item['type'] as String),
                      note: Value(item['note'] as String?),
                      transactionDate: Value(
                        DateTime.parse(item['transactionDate'] as String),
                      ),
                      linkedTransactionId: Value(
                        item['linkedTransactionId'] as int?,
                      ),
                      createdAt: _dateValue(item['createdAt']),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }

          final budgetsRaw = data['budgets'];
          if (budgetsRaw is List) {
            for (final item in budgetsRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.budgets)
                  .insert(
                    BudgetsCompanion(
                      id: Value(item['id'] as int),
                      categoryId: Value(item['categoryId'] as int),
                      amount: Value((item['amount'] as num).toDouble()),
                      period: Value(item['period'] as String),
                      startDate: Value(
                        DateTime.parse(item['startDate'] as String),
                      ),
                      createdAt: _dateValue(item['createdAt']),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }

          final recurringRaw = data['recurringTransactions'];
          if (recurringRaw is List) {
            for (final item in recurringRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.recurringTransactions)
                  .insert(
                    RecurringTransactionsCompanion(
                      id: Value(item['id'] as int),
                      accountId: Value(item['accountId'] as int),
                      categoryId: Value(item['categoryId'] as int),
                      amount: Value((item['amount'] as num).toDouble()),
                      type: Value(item['type'] as String),
                      note: Value(item['note'] as String?),
                      frequency: Value(item['frequency'] as String),
                      nextDate: Value(
                        DateTime.parse(item['nextDate'] as String),
                      ),
                      isActive: Value(item['isActive'] as bool? ?? true),
                      createdAt: _dateValue(item['createdAt']),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }

          final goalsRaw = data['goals'];
          if (goalsRaw is List) {
            for (final item in goalsRaw.cast<Map<String, dynamic>>()) {
              await db
                  .into(db.goals)
                  .insert(
                    GoalsCompanion(
                      id: Value(item['id'] as int),
                      name: Value(item['name'] as String),
                      targetAmount: Value(
                        (item['targetAmount'] as num).toDouble(),
                      ),
                      currentAmount: Value(
                        (item['currentAmount'] as num?)?.toDouble() ?? 0,
                      ),
                      deadline: Value(
                        DateTime.parse(item['deadline'] as String),
                      ),
                      accountId: Value(item['accountId'] as int),
                      color: Value(item['color'] as int),
                      icon: Value(item['icon'] as String),
                      createdAt: _dateValue(item['createdAt']),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              imported++;
            }
          }
        });
      } finally {
        await db.customStatement('PRAGMA foreign_keys = ON');
      }

      await FinanceStore.create(db);
      invalidateFinance(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $imported records successfully.')),
        );
      }
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will delete all your accounts, transactions, budgets, and settings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.customStatement('DELETE FROM finance_records');
              await db.customStatement('DELETE FROM transaction_details');
              await db.customStatement('DELETE FROM exact_balances');
              await db.delete(db.transactions).go();
              await db.delete(db.budgets).go();
              await db.delete(db.recurringTransactions).go();
              await db.delete(db.goals).go();
              await db.delete(db.paymentInstruments).go();
              await db.delete(db.accounts).go();
              await db.delete(db.categories).go();
              for (final key in BackupService.settings) {
                await PreferencesService.remove(key);
              }
              invalidateFinance(ref);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data has been reset')),
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Value<DateTime> _dateValue(Object? value) {
    if (value == null) return const Value.absent();
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? const Value.absent() : Value(parsed);
  }
}

/// iOS-style inset group: a small caps label above one rounded card whose
/// rows are separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sp.lg, bottom: Sp.sm),
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: palette.stroke),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Rad.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0 && children[i] is _SettingTile)
                      Divider(height: 1, indent: 62, color: palette.stroke),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? tint;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.tint,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final color = tint ?? palette.accent;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: titleColor ?? palette.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: palette.textLow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
          if (onTap != null && trailing == null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.textLow.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
    return onTap == null
        ? row
        : Pressable(onTap: onTap, scale: 0.985, child: row);
  }
}
