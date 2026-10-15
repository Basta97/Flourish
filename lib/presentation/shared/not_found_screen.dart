import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({
    super.key,
    this.title = 'Page not found',
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: LiquidPageBackground(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Sp.bottomNavClear),
          child: EmptyState(
            icon: Icons.explore_off_rounded,
            title: title,
            subtitle:
                subtitle ??
                'This destination is unavailable or may have moved.',
            action: FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back Home'),
            ),
          ),
        ),
      ),
    );
  }
}
