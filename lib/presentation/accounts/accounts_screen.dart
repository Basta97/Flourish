import 'package:flourish/l10n/l10n.dart';
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
          SliverAppBar.large(title: Text(context.l10n.navAccounts)),
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
                      title: context.l10n.noAccountsYet,
                      subtitle: context.l10n.addFirstAccount,
                      action: FilledButton.icon(
                        onPressed: () => showSpringBottomSheet(
                          context: context,
                          builder: (_) => const AddAccountSheet(),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.l10n.addAnAccount),
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
                      context.l10n.accountCount(accounts.length),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: context.l10n.errorLoadingAccounts,
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
  final _limitController = TextEditingController();
  final _intlLimitController = TextEditingController();
  final _aprController = TextEditingController();
  final _statementDayController = TextEditingController(text: '25');
  final _dueDayController = TextEditingController(text: '10');
  String? _cardError;
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
    _limitController.dispose();
    _intlLimitController.dispose();
    _aprController.dispose();
    _statementDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetScaffold(
      title: context.l10n.addAccount,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.accountName,
            hintText: context.l10n.accountNameHint,
            errorText: _nameError,
          ),
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _balanceController,
          decoration: InputDecoration(
            labelText: _type == 'credit'
                ? context.l10n.amountOweNow
                : context.l10n.currentBalance,
            helperText: _type == 'credit'
                ? context.l10n.debtPositiveHint
                : context.l10n.leaveEmptyZero,
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
          decoration: InputDecoration(labelText: context.l10n.accountType),
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
          decoration: InputDecoration(labelText: context.l10n.currency),
          items: AppConstants.currencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _currency = v);
            }
          },
        ),
        if (_type == 'credit') ...[
          const SizedBox(height: Sp.md),
          Text(context.l10n.cardTerms, style: AppTextStyles.overline),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [AmountInputFormatter()],
                  decoration: InputDecoration(
                    labelText: context.l10n.creditLimit,
                  ),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: TextField(
                  controller: _aprController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [AmountInputFormatter()],
                  decoration: InputDecoration(
                    labelText: context.l10n.interestPerYear,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          TextField(
            controller: _intlLimitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountInputFormatter()],
            decoration: InputDecoration(
              labelText: context.l10n.intlLimitOptional,
            ),
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statementDayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  decoration: InputDecoration(
                    labelText: context.l10n.statementDay,
                  ),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: TextField(
                  controller: _dueDayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  decoration: InputDecoration(labelText: context.l10n.dueDay),
                ),
              ),
            ],
          ),
          if (_cardError != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(
                _cardError!,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: Sp.xs),
          Text(context.l10n.cardFeesLater, style: AppTextStyles.caption),
        ],
        const SizedBox(height: Sp.md),
        Text(context.l10n.icon, style: AppTextStyles.overline),
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
        Text(context.l10n.color, style: AppTextStyles.overline),
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
              : Text(context.l10n.addAccount, style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  void _submit() async {
    setState(() => _nameError = null);

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = context.l10n.enterAccountName);
      return;
    }

    Amount balance = Amount.zero;
    if (_balanceController.text.trim().isNotEmpty) {
      try {
        balance = AmountParser.decimal(_balanceController.text);
        if (balance.value.scale > CurrencyFormatter.decimalsFor(_currency)) {
          throw ArgumentError(
            context.l10n.maxDecimals(CurrencyFormatter.decimalsFor(_currency)),
          );
        }
      } catch (e) {
        setState(() => _balanceError = describeError(e));
        return;
      }
    }

    CardTerms? terms;
    Amount apr = Amount.zero;
    int statementDay = 25, dueDay = 10;
    if (_type == 'credit' && _limitController.text.trim().isNotEmpty) {
      try {
        terms = CardTerms(
          creditLimit: AmountParser.decimal(_limitController.text),
          intlLimit: _intlLimitController.text.trim().isEmpty
              ? null
              : AmountParser.decimal(_intlLimitController.text),
        );
        terms.validate();
        apr = _aprController.text.trim().isEmpty
            ? Amount.zero
            : AmountParser.decimal(_aprController.text);
        statementDay = AmountParser.decimal(
          _statementDayController.text,
        ).toDouble().toInt();
        dueDay = AmountParser.decimal(
          _dueDayController.text,
        ).toDouble().toInt();
      } catch (e) {
        setState(() => _cardError = describeError(e));
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _cardError = null;
    });
    try {
      if (terms != null) {
        await ref
            .read(creditCardServiceProvider)
            .createCard(
              name: _nameController.text.trim(),
              currency: _currency,
              owed: balance,
              terms: terms,
              purchaseApr: apr,
              statementDay: statementDay,
              paymentDay: dueDay,
              color: _color,
              icon: _icon,
            );
        if (mounted) Navigator.pop(context);
        return;
      }
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
