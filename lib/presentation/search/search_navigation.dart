import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/search/search_models.dart';
import '../../data/finance/finance_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../providers/database_provider.dart';
import '../providers/finance_providers.dart';
import '../transactions/widgets/edit_transaction_sheet.dart';
import '../templates/templates_screen.dart';
import '../goals/goals_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_management_screen.dart';
import '../wealth/holdings_view.dart';
import '../wealth/contracts_view.dart';

Future<void> openSearchHit(
  BuildContext context,
  WidgetRef ref,
  SearchHit hit,
) async {
  final db = ref.read(databaseProvider), store = ref.read(financeStoreProvider);
  final id = int.tryParse(hit.id);
  switch (hit.kind) {
    case 'transaction':
      final t = id == null ? null : await db.getTransactionById(id);
      if (!context.mounted) return;
      if (t != null) {
        await showSpringBottomSheet(
          context: context,
          builder: (_) => EditTransactionSheet(transaction: t),
        );
        return;
      }
    case 'holding':
      final h = await PortfolioRepository(store).get(hit.id);
      if (!context.mounted) return;
      if (h != null) {
        await showHolding(context, ref, h, null);
        return;
      }
    case 'obligation':
      final j = await store.get('contracts', hit.id);
      if (!context.mounted) return;
      if (j != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ContractDetailScreen(contract: FinanceContract.fromJson(j)),
          ),
        );
        return;
      }
    case 'template':
      if (await store.get('templates', hit.id) != null && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TemplatesScreen(recordId: hit.id),
          ),
        );
        return;
      }
    case 'goal':
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GoalsScreen(recordId: id)),
        );
        return;
      }
    case 'budget':
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => BudgetsScreen(recordId: id)),
        );
        return;
      }
    case 'category':
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoriesManagementScreen(recordId: id),
          ),
        );
        return;
      }
    default:
      if (hit.target.isNotEmpty && context.mounted) {
        await context.push(hit.target);
        return;
      }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.searchMissingRecord)));
  }
}
