import '../../shared/widgets/global_search_button.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../wealth/finance_tools_view.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.tools),
      actions: const [GlobalSearchButton()],
    ),
    body: const FinanceToolsView(),
  );
}
