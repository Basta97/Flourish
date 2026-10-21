import 'package:flourish/core/finance/system_categories.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/error_text.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/categories/category_form_sheet.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/shared/category_label.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesManagementScreen extends ConsumerWidget {
  final int? recordId;
  const CategoriesManagementScreen({super.key, this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.manageCategories)),
      body: LiquidPageBackground(
        child: categoriesAsync.when(
          data: (all) {
            final categories = recordId == null
                ? SystemCategories.pickable(all)
                : all.where((c) => c.id == recordId).toList();
            if (categories.isEmpty) {
              return EmptyState(
                icon: Icons.category,
                title: context.l10n.noCategories,
              );
            }
            final income = _sorted(categories.where((c) => c.type == 'income'));
            final expense = _sorted(
              categories.where((c) => c.type == 'expense'),
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 96),
              children: [
                if (income.isNotEmpty)
                  ..._section(
                    context,
                    title: context.l10n.income,
                    color: AppColors.income,
                    categories: income,
                    firstIndex: 0,
                  ),
                if (income.isNotEmpty && expense.isNotEmpty)
                  const SizedBox(height: Sp.xxl),
                if (expense.isNotEmpty)
                  ..._section(
                    context,
                    title: context.l10n.expense,
                    color: AppColors.expense,
                    categories: expense,
                    firstIndex: income.length,
                  ),
              ],
            );
          },
          loading: () => const ShimmerList(),
          error: (error, stackTrace) => EmptyState(
            icon: Icons.error,
            title: context.l10n.errorLoadingCategories,
            subtitle: describeError(error),
          ),
        ),
      ),
      floatingActionButton: recordId == null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCategorySheet(context),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addCategory),
            )
          : null,
    );
  }

  static List<Category> _sorted(Iterable<Category> categories) {
    return categories.toList()..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
  }

  /// A group heading followed by one tile per category. [firstIndex] keeps
  /// the entry animation staggered across both groups.
  List<Widget> _section(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Category> categories,
    required int firstIndex,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: Text(
          title,
          style: AppTextStyles.overline.copyWith(color: color),
        ),
      ),
      for (var i = 0; i < categories.length; i++)
        AnimatedListItem(
          index: firstIndex + i,
          child: _CategoryTile(category: categories[i]),
        ),
    ];
  }

  void _showAddCategorySheet(BuildContext context) {
    showSpringBottomSheet<int>(
      context: context,
      builder: (ctx) => const CategoryFormSheet(),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSystem = SystemCategories.isSystem(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        child: ListTile(
          leading: CategoryIconWidget(
            iconName: category.icon,
            color: Color(category.color),
            size: 42,
          ),
          title: Text(category.displayName, style: AppTextStyles.bodyMedium),
          subtitle: Text(
            category.type.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          trailing: isSystem
              ? Tooltip(
                  message: context.l10n.systemCategoryLocked,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.l10n.delete,
                  color: AppColors.danger.withValues(alpha: 0.6),
                  onPressed: () => _confirmDelete(context, ref, category),
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
          onTap: () => showSpringBottomSheet<int>(
            context: context,
            builder: (ctx) => CategoryFormSheet(existing: category),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final db = ref.read(databaseProvider);
    final int count;
    try {
      count = await db.getCategoryTransactionCount(cat.id);
    } catch (e) {
      if (context.mounted) _showError(context, e);
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteCategory),
        content: Text(
          count > 0
              ? ctx.l10n.deleteCategoryWithTx(
                  cat.displayName,
                  count,
                  cat.type == 'income' ? ctx.l10n.otherIncome : ctx.l10n.other,
                )
              : ctx.l10n.deleteCategoryEmpty(cat.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await db.deleteCategoryAndReassignTransactions(cat.id);
              } catch (e) {
                if (context.mounted) _showError(context, e);
              }
            },
            child: Text(
              ctx.l10n.delete,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(describeError(error))));
  }
}
