import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/core/utils/amount_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/goals_provider.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/progress.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';

class GoalsScreen extends ConsumerWidget {
  final int? recordId;
  const GoalsScreen({super.key, this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSpringBottomSheet(
          context: context,
          builder: (_) => const _AddGoalSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.goal),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(pinned: true, title: Text(context.l10n.savingsGoals)),
          ...goalsAsync.when(
            data: (allRecords) {
              final goals = allRecords
                  .where((r) => recordId == null || r.id == recordId)
                  .toList();
              if (goals.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.flag_outlined,
                      title: context.l10n.noGoalsYet,
                      subtitle: context.l10n.noGoalsSubtitle,
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
                    120,
                  ),
                  sliver: SliverList.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Sp.md),
                    itemBuilder: (ctx, i) => AnimatedListItem(
                      key: ValueKey(goals[i].id),
                      index: i,
                      child: _GoalCard(goal: goals[i]),
                    ),
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
                        padding: const EdgeInsets.only(bottom: Sp.md),
                        child: ShimmerLoading.card(height: 120),
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
                  title: context.l10n.errorLoadingGoals,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A goal: progress ring with the percentage, amounts, a deadline chip, and
/// an Add action. Crossing the target plays a short celebratory pulse.
class _GoalCard extends ConsumerStatefulWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Goal get goal => widget.goal;

  @override
  void didUpdateWidget(_GoalCard old) {
    super.didUpdateWidget(old);
    final wasReached = old.goal.currentAmount >= old.goal.targetAmount;
    final isReached = goal.currentAmount >= goal.targetAmount;
    if (!wasReached && isReached) {
      Haptics.success();
      if (!Motion.reduced(context)) _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final currency =
        ref
            .watch(accountsProvider)
            .valueOrNull
            ?.where((a) => a.id == goal.accountId)
            .firstOrNull
            ?.currency ??
        ref.watch<String>(defaultCurrencyProvider);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final color = Color(goal.color);
    final reached = goal.currentAmount >= goal.targetAmount;
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;
    final tone = reached ? palette.accent : color;

    final card = AppCard(
      padding: const EdgeInsets.all(Sp.lg),
      child: Row(
        children: [
          ProgressRing(
            value: progress,
            color: tone,
            size: 76,
            stroke: 7,
            semanticsLabel: reached
                ? context.l10n.goalReached
                : context.l10n.percentSaved(
                    (progress * 100).toStringAsFixed(0),
                  ),
            child: reached
                ? Icon(Icons.check_rounded, color: tone, size: 30)
                : Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.numberSmall.copyWith(color: tone),
                  ),
          ),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      IconUtils.categoryIcon(goal.icon),
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Text(
                        goal.name,
                        style: AppTextStyles.subtitle.copyWith(
                          color: palette.textHigh,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: CurrencyFormatter.formatCompact(
                          goal.currentAmount,
                          currency: currency,
                        ),
                        style: AppTextStyles.number.copyWith(
                          fontSize: 16,
                          color: palette.textHigh,
                        ),
                      ),
                      TextSpan(
                        text:
                            '  ${context.l10n.ofTarget(CurrencyFormatter.formatCompact(goal.targetAmount, currency: currency))}',
                        style: AppTextStyles.caption.copyWith(
                          color: palette.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.sm),
                Row(
                  children: [
                    _Chip(
                      text: reached
                          ? context.l10n.goalReached
                          : daysLeft < 0
                          ? context.l10n.pastDeadline
                          : context.l10n.daysLeft(daysLeft),
                      color: reached
                          ? palette.accent
                          : daysLeft < 7
                          ? palette.warning
                          : palette.textLow,
                    ),
                    const Spacer(),
                    if (!reached)
                      SizedBox(
                        height: 32,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showContributeSheet(context),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(context.l10n.add),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sp.md,
                            ),
                            minimumSize: const Size(0, 32),
                            textStyle: AppTextStyles.caption,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: context.l10n.deleteGoal,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: palette.textLow,
                      ),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Celebration: a gentle swell and an accent glow that fades out.
    return AnimatedBuilder(
      animation: _burst,
      child: card,
      builder: (context, child) {
        final t = _burst.value;
        final pulse = t == 0
            ? 0.0
            : Curves.easeOut.transform(1 - (2 * t - 1).abs());
        return Transform.scale(
          scale: 1 + 0.035 * pulse,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.lg),
              boxShadow: [
                if (pulse > 0)
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.45 * pulse),
                    blurRadius: 36 * pulse,
                    spreadRadius: 2 * pulse,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    Haptics.warning();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteGoalTitle),
        content: Text(ctx.l10n.deleteGoalBody(goal.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(databaseProvider).deleteGoal(goal.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              context.l10n.delete,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showContributeSheet(BuildContext context) {
    final controller = TextEditingController();
    String? error;
    showSpringBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => BottomSheetScaffold(
          title: ctx.l10n.addToGoal(goal.name),
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.amount,
                hintText: '0.00',
                errorText: error,
                errorMaxLines: 3,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (error != null) setSheetState(() => error = null);
              },
            ),
            const SizedBox(height: Sp.xxl),
            FilledButton(
              onPressed: () async {
                final currency =
                    ref
                        .read(accountsProvider)
                        .valueOrNull
                        ?.where((a) => a.id == goal.accountId)
                        .firstOrNull
                        ?.currency ??
                    '';
                final parsed = AmountParser.parse(
                  controller.text,
                  currency: currency,
                );
                if (!parsed.isValid) {
                  Haptics.warning();
                  setSheetState(() => error = parsed.error);
                  return;
                }
                final amount = parsed.value!.toDouble();
                try {
                  await ref
                      .read(databaseProvider)
                      .contributeToGoal(goal.id, amount);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // e.g. the linked account doesn't hold enough cash.
                  Haptics.warning();
                  setSheetState(
                    () => error = '$e'.replaceFirst(
                      RegExp(r'^(Bad state|Exception|StateError): '),
                      '',
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Rad.full),
                ),
              ),
              child: Text(context.l10n.contribute),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Rad.full),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  int _accountId = -1;
  final int _color = AppColors.income.toARGB32();
  String _icon = 'savings';
  String? _nameError;
  String? _amountError;

  static const _availableIcons = [
    'savings',
    'home',
    'directions_car',
    'flight',
    'school',
    'favorite',
    'shopping_bag',
    'account_balance_wallet',
  ];

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    return BottomSheetScaffold(
      title: context.l10n.newSavingsGoal,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.goalName,
            hintText: context.l10n.goalNameHint,
            errorText: _nameError,
          ),
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: context.l10n.targetAmount,
            hintText: '0.00',
            errorText: _amountError,
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: Sp.md),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _deadline,
              firstDate: DateTime.now(),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _deadline = picked);
          },
          borderRadius: BorderRadius.circular(Rad.md),
          child: InputDecorator(
            decoration: InputDecoration(labelText: context.l10n.deadline),
            child: Text(
              '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: Sp.md),
        accountsAsync.when(
          data: (all) {
            // Goals earmark cash; a card's credit line cannot be set aside.
            final accounts = all.where((a) => a.type != 'credit').toList();
            if (_accountId == -1 && accounts.isNotEmpty) {
              _accountId = accounts.first.id;
            }
            return DropdownButtonFormField<int>(
              initialValue: _accountId >= 0 ? _accountId : null,
              decoration: InputDecoration(
                labelText: context.l10n.linkedAccount,
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _accountId = v);
                }
              },
            );
          },
          loading: () => const SizedBox(height: 60),
          error: (error, stackTrace) => const SizedBox(height: 60),
        ),
        const SizedBox(height: Sp.md),
        Text(context.l10n.icon, style: AppTextStyles.overline),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: _availableIcons.map((icon) {
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
                  IconUtils.categoryIcon(icon),
                  color: selected ? AppColors.primary : null,
                  size: 22,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Sp.xxl),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Sp.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.md),
            ),
          ),
          child: Text(context.l10n.createGoal, style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  void _submit() async {
    setState(() {
      _nameError = null;
      _amountError = null;
    });
    bool hasError = false;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = context.l10n.enterName);
      hasError = true;
    }
    final account = ref
        .read(accountsProvider)
        .valueOrNull
        ?.where((a) => a.id == _accountId && a.type != 'credit')
        .firstOrNull;
    if (account == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.addCashOrBankFirst)));
      return;
    }
    final parsed = AmountParser.parse(
      _amountController.text,
      currency: account.currency,
    );
    if (!parsed.isValid) {
      setState(() => _amountError = parsed.error);
      hasError = true;
    }
    if (hasError) return;
    final amount = parsed.value!.toDouble();

    final db = ref.read(databaseProvider);
    await db.insertGoal(
      GoalsCompanion.insert(
        name: _nameController.text.trim(),
        targetAmount: amount,
        deadline: _deadline,
        accountId: _accountId,
        color: _color,
        icon: _icon,
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}
