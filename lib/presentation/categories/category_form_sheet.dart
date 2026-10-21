import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flourish/core/finance/system_categories.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/error_text.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/shared/widgets/bottom_sheet_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maximum length of a category name, matching the database column.
const int maxCategoryNameLength = 100;

/// Creates or edits a category. Pops with the saved category's id, so a
/// caller such as the transaction sheet can select it straight away.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, this.existing, this.initialType});

  final Category? existing;

  /// Type preselected for a new category ('income' or 'expense').
  final String? initialType;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  static final _availableIcons = IconUtils.categoryIcons.keys.toList();

  final _nameController = TextEditingController();
  late String _type;
  late String _icon;
  late int _color;
  String? _nameError;
  String? _typeError;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isSystem => SystemCategories.isSystem(widget.existing);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _type = existing.type;
      _icon = existing.icon;
      _color = existing.color;
    } else {
      final all = ref.read(categoriesProvider).valueOrNull ?? const [];
      _type = widget.initialType ?? 'expense';
      _icon = 'more_horiz';
      _color = _unusedColor(all);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The first palette colour no category uses yet, so new ones stand out.
  static int _unusedColor(Iterable<Category> all) {
    final used = all.map((c) => c.color).toSet();
    return AppColors.categoryPalette.firstWhere(
      (c) => !used.contains(c),
      orElse: () => AppColors.categoryPalette.first,
    );
  }

  /// Names are unique per type, ignoring case, so the pickers never show
  /// two "Groceries" in the same list.
  String? _validateName(String name, List<Category> all) {
    final l10n = context.l10n;
    if (name.isEmpty) return l10n.enterName;
    if (name.length > maxCategoryNameLength) return l10n.categoryNameTooLong;
    final lower = name.toLowerCase();
    final clash = all.any(
      (c) =>
          c.type == _type &&
          c.name.trim().toLowerCase() == lower &&
          c.id != widget.existing?.id,
    );
    return clash ? l10n.categoryNameExists : null;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final all = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final nameError = _validateName(name, all);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    setState(() {
      _saving = true;
      _typeError = null;
    });
    final db = ref.read(databaseProvider);
    try {
      final existing = widget.existing;
      final int id;
      if (existing == null) {
        final nextSort = all
            .where((c) => !SystemCategories.isSystem(c))
            .fold<int>(0, (max, c) => math.max(max, c.sortOrder));
        id = await db.insertCategory(
          CategoriesCompanion.insert(
            name: name,
            icon: _icon,
            color: _color,
            type: _type,
            isDefault: const Value(false),
            sortOrder: Value(nextSort + 1),
          ),
        );
      } else {
        // Changing the type would move past entries into the other totals,
        // so it is only allowed while nothing is booked to the category.
        if (_type != existing.type) {
          final used = await db.getCategoryTransactionCount(existing.id);
          if (used > 0) {
            if (!mounted) return;
            setState(() {
              _saving = false;
              _typeError = context.l10n.categoryTypeLocked(used);
            });
            return;
          }
        }
        await db.updateCategory(
          existing.copyWith(
            name: name,
            icon: _icon,
            color: _color,
            type: _type,
          ),
        );
        id = existing.id;
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomSheetScaffold(
      title: _isEditing ? l10n.editCategory : l10n.addCategory,
      children: [
        TextField(
          controller: _nameController,
          autofocus: !_isEditing,
          maxLength: maxCategoryNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.categoryName,
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: Sp.md),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(
            labelText: l10n.type,
            helperText: _isSystem ? l10n.systemCategoryTypeFixed : null,
            errorText: _typeError,
          ),
          items: [
            DropdownMenuItem(value: 'income', child: Text(l10n.income)),
            DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
          ],
          onChanged: _isSystem
              ? null
              : (v) {
                  if (v != null) setState(() => _type = v);
                },
        ),
        const SizedBox(height: Sp.md),
        Text(l10n.icon, style: AppTextStyles.overline),
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
        Text(l10n.color, style: AppTextStyles.overline),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: AppColors.categoryPalette.map((c) {
            final selected = _color == c;
            return GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
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
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Sp.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rad.md),
            ),
          ),
          child: Text(
            _isEditing ? l10n.saveChanges : l10n.addCategory,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
