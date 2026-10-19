import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';

class GlobalSearchButton extends StatelessWidget {
  const GlobalSearchButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.globalSearch,
    icon: const Icon(Icons.search_rounded),
    onPressed: () => context.push('/search'),
  );
}
