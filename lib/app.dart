import 'presentation/wealth/finance_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/motion/motion.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/theme_providers.dart';

class FlourishApp extends ConsumerWidget {
  const FlourishApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Flourish',
      // Honour Dynamic Type up to 1.3×, the largest size the layouts are
      // designed and tested for.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: FinanceAppLock(child: child!),
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: Motion.slow,
      themeAnimationCurve: Motion.morph,
      routerConfig: appRouter,
    );
  }
}
