import '../currencies/currency_picker.dart';
import '../../shared/widgets/global_search_button.dart';
import 'package:flourish/shared/category_label.dart';
import 'package:flourish/core/utils/amount_parser.dart';
import '../../core/finance/backup_service.dart';
import '../../core/finance/data_reset_service.dart';
import '../../core/utils/error_text.dart';
import '../providers/ai_providers.dart';
import '../providers/finance_providers.dart';
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
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/constants/enums.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/providers/locale_providers.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:flourish/shared/widgets/settings_group.dart';
import 'package:flourish/core/services/preferences_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final String? section;
  const SettingsScreen({super.key, this.section});

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
    final locale = ref.watch(appLocaleProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);

    if (widget.section == 'data') {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.data),
          actions: const [GlobalSearchButton()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(Sp.xl),
          children: [_dataGroup()],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
        actions: const [GlobalSearchButton()],
      ),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.sm, Sp.xl, Sp.xxxl),
          children: [
            SettingsGroup(
              title: context.l10n.tools,
              children: [
                SettingsTile(
                  icon: Icons.build_outlined,
                  title: context.l10n.tools,
                  subtitle: context.l10n.toolsSubtitle,
                  onTap: () => context.push('/tools'),
                ),
              ],
            ),
            SettingsGroup(
              title: context.l10n.appearance,
              children: [
                SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: context.l10n.theme,
                  subtitle: context.l10n.themeName(themeMode.name),
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
                SettingsTile(
                  icon: Icons.translate_rounded,
                  tint: const Color(0xFF5B9DF5),
                  title: context.l10n.language,
                  subtitle: _languageName(context, locale),
                  onTap: () => _pickLanguage(context, locale),
                ),
                SettingsTile(
                  icon: hideAmounts
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tint: const Color(0xFF8B7CF6),
                  title: context.l10n.hideAmounts,
                  subtitle: context.l10n.hideAmountsSubtitle,
                  trailing: Switch(
                    value: hideAmounts,
                    onChanged: (_) {
                      Haptics.select();
                      ref.read(hideAmountsProvider.notifier).toggle();
                    },
                  ),
                ),
                SettingsTile(
                  icon: Icons.currency_exchange,
                  title: context.l10n.defaultCurrency,
                  subtitle: currency,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final v = await pickCurrency(context, selected: currency);
                    if (v != null && context.mounted) {
                      ref.read(defaultCurrencyProvider.notifier).state = v;
                      persistSettings(ref);
                    }
                  },
                ),
              ],
            ),

            SettingsGroup(
              title: context.l10n.manage,
              children: [
                SettingsTile(
                  icon: Icons.track_changes_rounded,
                  tint: const Color(0xFFF5B547),
                  title: context.l10n.budgets,
                  subtitle: context.l10n.budgetsSubtitle,
                  // /budgets lives inside the tab shell; pushing it from
                  // here would build a second shell, so switch to it.
                  onTap: () => context.go('/budgets'),
                ),
                SettingsTile(
                  icon: Icons.flag_outlined,
                  tint: const Color(0xFF8B7CF6),
                  title: context.l10n.savingsGoals,
                  subtitle: context.l10n.savingsGoalsSubtitle,
                  onTap: () => context.push('/goals'),
                ),
                SettingsTile(
                  icon: Icons.repeat_rounded,
                  tint: const Color(0xFF3CC8C0),
                  title: context.l10n.recurring,
                  subtitle: context.l10n.recurringSubtitle,
                  onTap: () => context.push('/recurring'),
                ),
                SettingsTile(
                  icon: Icons.credit_card_rounded,
                  tint: const Color(0xFFEF4444),
                  title: context.l10n.cardsWallets,
                  subtitle: context.l10n.cardsWalletsSubtitle,
                  onTap: () => context.push('/payment-methods'),
                ),
                SettingsTile(
                  icon: Icons.category_outlined,
                  title: context.l10n.categories,
                  subtitle: context.l10n.categoriesSubtitle,
                  onTap: () => context.push('/categories/manage'),
                ),
                SettingsTile(
                  icon: Icons.mark_email_unread_outlined,
                  tint: const Color(0xFF5B9DF5),
                  title: context.l10n.paymentDetection,
                  subtitle: context.l10n.paymentDetectionSubtitle,
                  onTap: () => context.push('/settings/detection'),
                ),
                SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  title: context.l10n.smartImport,
                  subtitle: context.l10n.smartImportSubtitle,
                  onTap: () => context.push('/smart-import'),
                ),
              ],
            ),

            SettingsGroup(
              title: context.l10n.monthlyAutoIncome,
              children: [
                SettingsTile(
                  icon: Icons.schedule,
                  title: context.l10n.autoMonthlyIncome,
                  subtitle: autoIncome
                      ? context.l10n.enabled
                      : context.l10n.disabled,
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
                          decoration: InputDecoration(
                            labelText: context.l10n.monthlyIncomeAmount,
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
                          decoration: InputDecoration(
                            labelText: context.l10n.dayOfMonth,
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
                        Text(
                          context.l10n.incomeAccount,
                          style: AppTextStyles.overline,
                        ),
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
                              decoration: InputDecoration(
                                hintText: context.l10n.selectAccount,
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
                        Text(
                          context.l10n.incomeCategory,
                          style: AppTextStyles.overline,
                        ),
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
                              decoration: InputDecoration(
                                hintText: context.l10n.selectCategory,
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
                                          Text(c.displayName),
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

            _dataGroup(),

            SettingsGroup(
              title: context.l10n.about,
              children: [
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: context.l10n.privacyPolicy,
                  subtitle: context.l10n.privacyPolicySubtitle,
                  onTap: _openPrivacyPolicy,
                ),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: context.l10n.version,
                  subtitle: AppConstants.version,
                ),
                SettingsTile(
                  icon: Icons.code,
                  title: context.l10n.builtWith,
                  subtitle: 'Flutter & Drift',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataGroup() => SettingsGroup(
    title: context.l10n.data,
    children: [
      SettingsTile(
        icon: Icons.enhanced_encryption_outlined,
        title: context.l10n.exportBackup,
        subtitle: context.l10n.exportBackupSubtitle,
        onTap: () => exportEncrypted(context, ref),
      ),
      SettingsTile(
        icon: Icons.restore,
        title: context.l10n.restoreBackup,
        subtitle: context.l10n.restoreBackupSubtitle,
        onTap: () => restoreEncrypted(context, ref),
      ),
      SettingsTile(
        icon: Icons.file_download_outlined,
        title: context.l10n.exportData,
        subtitle: context.l10n.exportDataSubtitle,
        onTap: () => _exportData(ref),
      ),
      SettingsTile(
        icon: Icons.file_upload_outlined,
        title: context.l10n.importData,
        subtitle: context.l10n.importDataSubtitle,
        onTap: () => _importData(ref),
      ),
      SettingsTile(
        icon: Icons.delete_outline,
        title: context.l10n.resetAllData,
        subtitle: context.l10n.resetAllDataSubtitle,
        titleColor: AppColors.danger,
        tint: AppColors.danger,
        onTap: () => _confirmReset(context, ref),
      ),
    ],
  );

  String _languageName(BuildContext context, Locale? locale) =>
      switch (locale?.languageCode) {
        'en' => 'English',
        'ar' => 'العربية',
        _ => context.l10n.languageDevice,
      };

  Future<void> _pickLanguage(BuildContext context, Locale? current) async {
    final palette = FlourishPalette.of(context);
    final choice = await showDialog<(Locale?,)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.language),
        children: [
          for (final option in const [null, Locale('en'), Locale('ar')])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xxl),
              title: Text(_languageName(ctx, option)),
              trailing: option?.languageCode == current?.languageCode
                  ? Icon(Icons.check_rounded, color: palette.accent)
                  : null,
              onTap: () => Navigator.pop(ctx, (option,)),
            ),
        ],
      ),
    );
    if (choice == null) return;
    Haptics.select();
    await ref.read(appLocaleProvider.notifier).set(choice.$1);
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.tryParse(AppConstants.privacyPolicyUrl);
    final opened =
        url != null &&
        url.hasScheme &&
        await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.privacyPolicyUnavailable)),
      );
    }
  }

  void _exportData(WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.plainExportTitle),
        content: Text(ctx.l10n.plainExportBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'plain'),
            child: Text(ctx.l10n.exportUnencrypted),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'encrypted'),
            child: Text(ctx.l10n.useEncryptedBackup),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'encrypted') return exportEncrypted(context, ref);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$e'))),
        );
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
      var data = jsonDecode(content) as Map<String, dynamic>;
      if (data['format'] == BackupService.localFormat) {
        // A daily backup copied out of this installation.
        data = await BackupService(
          ref.read(databaseProvider),
        ).openLocal(content);
      }

      final hasData =
          data['format'] == 'flourish-finance' ||
          data['categories'] is List ||
          data['accounts'] is List ||
          data['transactions'] is List;
      if (!hasData) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.invalidBackup)));
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.importBackup),
          content: Text(context.l10n.importBackupWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.importAction),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.backupRestored)));
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
          SnackBar(content: Text(context.l10n.importedRecords(imported))),
        );
      }
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$e'))),
        );
      }
    }
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.resetAllData),
        content: Text(context.l10n.resetAllDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Object? failure;
              try {
                await DataResetService(
                  ref.read(databaseProvider),
                  secureStorage: ref.read(secureStorageProvider),
                  bridge: ref.read(detectionBridgeProvider),
                ).reset();
              } catch (e) {
                failure = e;
              }
              ref.invalidate(aiSettingsProvider);
              ref.invalidate(aiApiKeyProvider);
              invalidateFinance(ref);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      failure == null
                          ? context.l10n.allDataReset
                          : context.l10n.resetFailed(describeError(failure)),
                    ),
                  ),
                );
              }
            },
            child: Text(
              context.l10n.reset,
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
