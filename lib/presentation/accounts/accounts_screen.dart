import 'package:flourish/core/utils/amount_parser.dart';
import 'package:flourish/core/utils/error_text.dart';
import '../providers/finance_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/constants/app_constants.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/presentation/accounts/widgets/account_card.dart';
import 'package:flourish/shared/widgets/pressable.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:drift/drift.dart' hide Column;

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final palette = FlourishPalette.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(title: const Text('Accounts')),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(accountsProvider);
              await ref.read(accountsProvider.future);
              Haptics.success();
            },
          ),
          ...accountsAsync.when(
            data: (allAccounts) {
              final details =
                  ref.watch(accountDetailsProvider).valueOrNull ?? {};
              final accounts = allAccounts
                  .where((a) => details[a.id]?.archived != true)
                  .toList();
              if (accounts.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No accounts yet',
                      subtitle: 'Add your first account to start tracking.',
                      action: FilledButton.icon(
                        onPressed: () => showSpringBottomSheet(
                          context: context,
                          builder: (_) => const AddAccountSheet(),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add an account'),
                      ),
                    ),
                  ),
                ];
              }
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.screenH,
                    0,
                    Sp.screenH,
                    Sp.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${accounts.length} ${accounts.length == 1 ? 'ACCOUNT' : 'ACCOUNTS'}',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: palette.textLow,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.screenH,
                    0,
                    Sp.screenH,
                    Sp.bottomNavClear + Sp.lg,
                  ),
                  sliver: SliverList.separated(
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Sp.lg),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return AnimatedListItem(
                        key: ValueKey(account.id),
                        index: index,
                        child: Pressable(
                          scale: 0.97,
                          semanticLabel: account.name,
                          onTap: () => context.push('/accounts/${account.id}'),
                          child: Hero(
                            tag: accountHeroTag(account.id),
                            child: AccountCard(account: account),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ];
            },
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.lg),
                        child: ShimmerLoading.card(height: 164),
                      ),
                  ],
                ),
              ),
            ],
            error: (error, stackTrace) => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error loading accounts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});

  @override
  ConsumerState<AddAccountSheet> createState() => AddAccountSheetState();
}

class AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _type = 'bank';
  late String _currency;
  int _color = AppColors.primary.toARGB32();
  String _icon = 'account_balance';
  bool _isSubmitting = false;
  String? _nameError;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(defaultCurrencyProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetScaffold(
      title: 'Add Account',
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Account Name',
            hintText: 'e.g. Main Bank',
            errorText: _nameError,
          ),
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _balanceController,
          decoration: InputDecoration(
            labelText: _type == 'credit'
                ? 'Amount you owe now'
                : 'Current balance',
            helperText: _type == 'credit'
                ? 'Enter debt as a positive number; 0 for a paid-off card'
                : 'Leave empty for 0',
            helperMaxLines: 2,
            hintText: '0',
            prefixText: '${CurrencyFormatter.symbolFor(_currency)} ',
            errorText: _balanceError,
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (_) => setState(() => _balanceError = null),
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Account Type'),
          items: AppConstants.accountTypeOptions
              .map(
                (opt) => DropdownMenuItem(
                  value: opt['value'] as String,
                  child: Row(
                    children: [
                      Icon(
                        IconUtils.accountIcon(opt['icon'] as String),
                        size: 18,
                      ),
                      const SizedBox(width: Sp.sm),
                      Text(opt['label'] as String),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _type = v);
            }
          },
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: AppConstants.currencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _currency = v);
            }
          },
        ),
        const SizedBox(height: Sp.md),
        Text('Icon', style: AppTextStyles.overline),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: AppConstants.accountIcons.map((icon) {
            final selected = _icon == icon;
            return GestureDetector(
              onTap: () => setState(() => _icon = icon),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Rad.md),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  IconUtils.accountIcon(icon),
                  color: selected ? AppColors.primary : null,
                  size: 24,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Sp.md),
        Text('Color', style: AppTextStyles.overline),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: AppColors.accountGradients.map((g) {
            final color = g[0];
            final selected = _color == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _color = color.toARGB32()),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: Sp.sm,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Sp.xxl),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Sp.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.md),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add Account', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  void _submit() async {
    setState(() => _nameError = null);

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter an account name');
      return;
    }

    Amount balance = Amount.zero;
    if (_balanceController.text.trim().isNotEmpty) {
      try {
        balance = AmountParser.decimal(_balanceController.text);
        if (balance.value.scale > CurrencyFormatter.decimalsFor(_currency)) {
          throw ArgumentError(
            'Use at most ${CurrencyFormatter.decimalsFor(_currency)} decimals',
          );
        }
      } catch (e) {
        setState(() => _balanceError = describeError(e));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final dao = ref.read(accountDaoProvider);
      await dao.insertAccount(
        AccountsCompanion.insert(
          name: _nameController.text.trim(),
          type: _type,
          balance: Value(balance.toDouble()),
          currency: Value(_currency),
          color: _color,
          icon: _icon,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }
}
