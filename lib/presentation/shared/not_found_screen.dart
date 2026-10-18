import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notFound)),
      body: LiquidPageBackground(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Sp.bottomNavClear),
          child: EmptyState(
            icon: Icons.explore_off_rounded,
            title: title ?? context.l10n.pageNotFoundTitle,
            subtitle: subtitle ?? context.l10n.destinationUnavailable,
            action: FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: Text(context.l10n.backHome),
            ),
          ),
        ),
      ),
    );
  }
}
