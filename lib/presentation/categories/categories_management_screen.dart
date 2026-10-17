import 'package:flutter/material.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/shared/widgets/animated_list_item.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flourish/shared/widgets/app_card.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:drift/drift.dart' hide Column;

class CategoriesManagementScreen extends ConsumerWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: LiquidPageBackground(
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const EmptyState(
                icon: Icons.category,
                title: 'No categories',
              );
            }
            final income = categories.where((c) => c.type == 'income').toList();
            final expense = categories
                .where((c) => c.type == 'expense')
                .toList();
            final totalItems =
                (income.isNotEmpty ? income.length + 2 : 0) +
                (expense.isNotEmpty ? expense.length + 2 : 0);
            return ListView.builder(
              padding: const EdgeInsets.all(Sp.xl),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                var currentIndex = 0;
                if (income.isNotEmpty) {
                  if (index == currentIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Sp.sm),
                      child: Text(
                        'Income',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.income,
                        ),
                      ),
                    );
                  }
                  currentIndex++;
                  if (index < currentIndex + income.length) {
                    return AnimatedListItem(
                      index: index,
                      child: _CategoryTile(
                        category: income[index - currentIndex],
                        ref: ref,
                      ),
                    );
                  }
                  currentIndex += income.length;
                  if (index == currentIndex) {
                    return const SizedBox(height: Sp.xxl);
                  }
                  currentIndex++;
                }
                if (expense.isNotEmpty) {
                  if (index == currentIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Sp.sm),
                      child: Text(
                        'Expense',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.expense,
                        ),
                      ),
                    );
                  }
                  currentIndex++;
                  return AnimatedListItem(
                    index: index,
                    child: _CategoryTile(
                      category: expense[index - currentIndex],
                      ref: ref,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
          loading: () => const ShimmerList(),
          error: (error, stackTrace) => const EmptyState(
            icon: Icons.error,
            title: 'Error loading categories',
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, WidgetRef ref) {
    showSpringBottomSheet(
      context: context,
      builder: (ctx) => const _AddCategorySheet(),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;
  final WidgetRef ref;

  const _CategoryTile({required this.category, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          title: Text(category.name, style: AppTextStyles.bodyMedium),
          subtitle: Text(
            category.type.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.danger.withValues(alpha: 0.6),
            onPressed: () => _confirmDelete(context, ref, category),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.md),
          ),
          onTap: () => _showEditCategorySheet(context, ref, category),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) async {
    final db = ref.read(databaseProvider);
    final count = await db.getCategoryTransactionCount(cat.id);
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            count > 0
                ? '"${cat.name}" has $count transactions. Deleting will move them to a fallback ${cat.type} category.'
                : 'Delete "${cat.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await db.deleteCategoryAndReassignTransactions(cat.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showEditCategorySheet(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) {
    showSpringBottomSheet(
      context: context,
      builder: (ctx) => _AddCategorySheet(existing: cat),
    );
  }
}

class _AddCategorySheet extends ConsumerStatefulWidget {
  final Category? existing;
  const _AddCategorySheet({this.existing});

  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _nameController = TextEditingController();
  String _type = 'expense';
  String _icon = 'more_horiz';
  int _color = AppColors.fallbackColor;
  String? _nameError;

  static final _availableIcons = IconUtils.categoryIcons.keys.toList();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _type = widget.existing!.type;
      _icon = widget.existing!.icon;
      _color = widget.existing!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetScaffold(
      title: widget.existing != null ? 'Edit Category' : 'Add Category',
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Category Name',
            errorText: _nameError,
          ),
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const [
            DropdownMenuItem(value: 'income', child: Text('Income')),
            DropdownMenuItem(value: 'expense', child: Text('Expense')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _type = v);
            }
          },
        ),
        const SizedBox(height: Sp.md),
        Text('Icon', style: AppTextStyles.overline),
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
        const SizedBox(height: Sp.md),
        Text('Color', style: AppTextStyles.overline),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: AppColors.categoryPalette.map((c) {
            final color = Color(c);
            final selected = _color == c;
            return GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
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
          child: Text(
            widget.existing != null ? 'Save Changes' : 'Add Category',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter a name');
      return;
    }
    final db = ref.read(databaseProvider);
    if (widget.existing != null) {
      await db.updateCategory(
        widget.existing!.copyWith(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
        ),
      );
    } else {
      final cats = await db.getAllCategories();
      await db.insertCategory(
        CategoriesCompanion.insert(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
          isDefault: const Value(false),
          sortOrder: Value(cats.length),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
