import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/accounts/accounts_screen.dart';
import '../../presentation/accounts/account_detail_screen.dart';
import '../../presentation/analytics/analytics_screen.dart';
import '../../presentation/budgets/budgets_screen.dart';
import '../../presentation/settings/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AnalyticsScreen(),
          ),
        ),
        GoRoute(
          path: '/budgets',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const BudgetsScreen(),
          ),
        ),
        GoRoute(
          path: '/accounts',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AccountsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/accounts/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => AccountDetailScreen(
        accountId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/analytics')) return 1;
    if (location.startsWith('/budgets')) return 2;
    if (location.startsWith('/accounts')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/dashboard');
            case 1: context.go('/analytics');
            case 2: context.go('/budgets');
            case 3: context.go('/accounts');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
        ],
      ),
    );
  }
}
