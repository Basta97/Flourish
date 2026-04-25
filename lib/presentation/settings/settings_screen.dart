import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:bastasaving/core/theme/app_colors.dart';
import 'package:bastasaving/core/theme/app_text_styles.dart';
import 'package:bastasaving/core/constants/enums.dart';
import 'package:bastasaving/core/constants/app_constants.dart';
import 'package:bastasaving/presentation/providers/theme_providers.dart';
import 'package:bastasaving/presentation/providers/database_provider.dart';
import 'package:bastasaving/presentation/providers/account_providers.dart';
import 'package:bastasaving/presentation/providers/category_providers.dart';
import 'package:bastasaving/shared/widgets/category_icon_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final autoIncome = ref.watch(monthlyAutoIncomeProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(title: 'Appearance'),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: themeMode.name[0].toUpperCase() + themeMode.name.substring(1),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_auto, size: 16)),
                ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16)),
              ],
              selected: {themeMode},
              onSelectionChanged: (v) => ref.read(appThemeModeProvider.notifier).state = v.first,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
                selectedForegroundColor: AppColors.primary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              items: AppConstants.currencies.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) {
                if (v != null) ref.read(defaultCurrencyProvider.notifier).state = v;
              },
            ),
          ),
          const SizedBox(height: 24),

          _Section(title: 'Monthly Auto Income'),
          _SettingTile(
            icon: Icons.schedule,
            title: 'Auto Monthly Income',
            subtitle: autoIncome ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: autoIncome,
              activeColor: AppColors.primary,
              onChanged: (v) => ref.read(monthlyAutoIncomeProvider.notifier).state = v,
            ),
          ),
          if (autoIncome) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _incomeAmountController,
              decoration: const InputDecoration(
                labelText: 'Monthly Income Amount',
                hintText: 'e.g. 5000',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final amt = double.tryParse(v) ?? 0;
                ref.read(monthlyIncomeAmountProvider.notifier).state = amt;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incomeDayController,
              decoration: const InputDecoration(
                labelText: 'Day of Month',
                hintText: '1-28',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final day = int.tryParse(v) ?? 1;
                ref.read(monthlyIncomeDayProvider.notifier).state = day.clamp(1, 28);
              },
            ),
            const SizedBox(height: 12),
            Text('Income Account', style: AppTextStyles.label),
            const SizedBox(height: 4),
            accountsAsync.when(
              data: (accounts) {
                final selectedId = ref.watch(monthlyIncomeAccountIdProvider);
                return DropdownButtonFormField<int>(
                  value: selectedId ?? (accounts.isNotEmpty ? accounts.first.id : null),
                  decoration: const InputDecoration(hintText: 'Select account'),
                  items: accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(monthlyIncomeAccountIdProvider.notifier).state = v;
                  },
                );
              },
              loading: () => const SizedBox(height: 60),
              error: (_, __) => const SizedBox(height: 60),
            ),
            const SizedBox(height: 12),
            Text('Income Category', style: AppTextStyles.label),
            const SizedBox(height: 4),
            categoriesAsync.when(
              data: (cats) {
                final incomeCats = cats.where((c) => c.type == 'income').toList();
                final selectedId = ref.watch(monthlyIncomeCategoryIdProvider);
                return DropdownButtonFormField<int>(
                  value: selectedId ?? (incomeCats.isNotEmpty ? incomeCats.first.id : null),
                  decoration: const InputDecoration(hintText: 'Select category'),
                  items: incomeCats.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        CategoryIconWidget(iconName: c.icon, color: Color(c.color), size: 28, iconSize: 14),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(monthlyIncomeCategoryIdProvider.notifier).state = v;
                  },
                );
              },
              loading: () => const SizedBox(height: 60),
              error: (_, __) => const SizedBox(height: 60),
            ),
          ],
          const SizedBox(height: 24),

          _Section(title: 'Data'),
          _SettingTile(
            icon: Icons.file_download_outlined,
            title: 'Export Data',
            subtitle: 'Save your data as JSON',
            onTap: () => _exportData(ref),
          ),
          _SettingTile(
            icon: Icons.delete_outline,
            title: 'Reset All Data',
            subtitle: 'Delete all accounts, transactions, and budgets',
            titleColor: AppColors.danger,
            onTap: () => _confirmReset(context, ref),
          ),
          const SizedBox(height: 24),

          _Section(title: 'About'),
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
    );
  }

  void _exportData(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final accounts = await db.getAllAccounts();
    final categories = await db.getAllCategories();
    final transactions = await db.getAllTransactions();

    final data = {
      'accounts': accounts.map((a) => {
        'id': a.id, 'name': a.name, 'type': a.type, 'balance': a.balance,
        'currency': a.currency, 'color': a.color, 'icon': a.icon,
      }).toList(),
      'categories': categories.map((c) => {
        'id': c.id, 'name': c.name, 'icon': c.icon, 'color': c.color,
        'type': c.type, 'isDefault': c.isDefault,
      }).toList(),
      'transactions': transactions.map((t) => {
        'id': t.id, 'accountId': t.accountId, 'categoryId': t.categoryId,
        'amount': t.amount, 'type': t.type, 'note': t.note,
        'transactionDate': t.transactionDate.toIso8601String(),
      }).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/bastasaving_backup.json');
    await file.writeAsString(data.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'BastaSaving Backup');
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text('This will delete all your accounts, transactions, budgets, and settings. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.delete(db.accounts).go();
              await db.delete(db.transactions).go();
              await db.delete(db.categories).go();
              await db.delete(db.budgets).go();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppTextStyles.label.copyWith(
        color: AppColors.primary,
        fontSize: 12,
        letterSpacing: 1,
      )),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        color: titleColor,
                      )),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      )),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (onTap != null && trailing == null)
                  Icon(Icons.chevron_right, size: 20, color: isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                      : AppColors.textSecondaryLight.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
