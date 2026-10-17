import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/accounts/accounts_screen.dart';
import '../../presentation/accounts/account_detail_screen.dart';
import '../../presentation/budgets/budgets_screen.dart';
import '../../presentation/transactions/transactions_screen.dart';
import '../../presentation/wealth/wealth_screen.dart';
import '../../presentation/search/search_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/settings/ai_settings_screen.dart';
import '../../presentation/categories/categories_management_screen.dart';
import '../../presentation/recurring/recurring_transactions_screen.dart';
import '../../presentation/goals/goals_screen.dart';
import '../../presentation/transactions/notification_import_screen.dart';
import '../../presentation/shared/not_found_screen.dart';
import '../../core/models/shared_import_draft.dart';
import '../../presentation/transactions/widgets/add_transaction_sheet.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  errorBuilder: (context, state) =>
      NotFoundScreen(subtitle: 'The page "${state.uri}" does not exist.'),
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        for (final (path, screen) in <(String, Widget)>[
          ('/transactions', const TransactionsScreen()),
          ('/wealth', const WealthScreen()),
          ('/dashboard', const DashboardScreen()),
          ('/search', const SearchScreen()),
          ('/accounts', const AccountsScreen()),
          ('/budgets', const BudgetsScreen()),
        ])
          GoRoute(
            path: path,
            pageBuilder: (context, state) =>
                _fadeThroughPage(key: state.pageKey, child: screen),
          ),
      ],
    ),
    GoRoute(
      path: '/accounts/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const NotFoundScreen(
            title: 'Account not found',
            subtitle: 'That account link is invalid or no longer available.',
          );
        }
        return AccountDetailScreen(accountId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/categories/manage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CategoriesManagementScreen(),
    ),
    GoRoute(
      path: '/recurring',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecurringTransactionsScreen(),
    ),
    GoRoute(
      path: '/goals',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GoalsScreen(),
    ),
    GoRoute(
      path: '/settings/ai',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiSettingsScreen(),
    ),
    GoRoute(
      path: '/smart-import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => NotificationImportScreen(
        initialDraft: state.extra is SharedImportDraft
            ? state.extra as SharedImportDraft
            : null,
      ),
    ),
  ],
);

/// Tab switches cross-fade with a slight scale-up, like iOS tab bars that
/// "breathe" in rather than slide.
CustomTransitionPage<void> _fadeThroughPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.enter);
      if (Motion.reduced(context)) {
        return FadeTransition(opacity: curved, child: child);
      }
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class ScaffoldWithNavBar extends StatefulWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _addOpen = false;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/search') ||
        location.startsWith('/transactions')) {
      return 1;
    }
    if (location.startsWith('/accounts')) return 3;
    if (location.startsWith('/budgets') || location.startsWith('/wealth')) {
      return 4;
    }
    return 0;
  }

  String _currentRoute(BuildContext context) {
    // Read the router's live location: the inherited GoRouterState can lag a
    // frame behind a tab switch, which made Add open the wrong sheet.
    // `state` is the top-most route, including pushed ones like /budgets.
    final location = GoRouter.of(context).state.matchedLocation;
    if (location.startsWith('/accounts')) return '/accounts';
    if (location.startsWith('/budgets')) return '/budgets';
    if (location.startsWith('/search')) return '/search';
    return '/dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      extendBody: true,
      // Pages handle the keyboard themselves; the nav stays put behind it.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _IslandNavBar(
                selectedIndex: index,
                addOpen: _addOpen,
                onDestinationSelected: (i) {
                  if (i != 2 && i != index) Haptics.select();
                  switch (i) {
                    case 0:
                      context.go('/dashboard');
                    case 1:
                      context.go('/transactions');
                    case 2:
                      _showAddSheet(context);
                    case 3:
                      context.go('/accounts');
                    case 4:
                      context.go('/wealth');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final route = _currentRoute(context);
    setState(() => _addOpen = true);
    final WidgetBuilder builder = switch (route) {
      '/accounts' => (_) => const AddAccountSheet(),
      '/budgets' => (_) => const AddBudgetSheet(),
      _ => (_) => const AddTransactionSheet(),
    };
    await showSpringBottomSheet(context: context, builder: builder);
    if (mounted) setState(() => _addOpen = false);
  }
}

class _IslandNavBar extends StatelessWidget {
  const _IslandNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.addOpen,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool addOpen;

  static const double _itemExtent = 64; // 48 hit target + 2×8 gutter
  static const double _centerExtent = 72; // 56 button + 2×8 gutter
  static const double _hPad = 10;

  static const _items =
      <({IconData icon, IconData selectedIcon, String label})>[
        (
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        (
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Ledger',
        ),
        (
          icon: Icons.add_rounded,
          selectedIcon: Icons.add_rounded,
          label: 'Add',
        ),
        (
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: 'Accounts',
        ),
        (
          icon: Icons.diamond_outlined,
          selectedIcon: Icons.diamond,
          label: 'Wealth',
        ),
      ];

  double _offsetOf(int index) {
    var x = _hPad;
    for (var i = 0; i < index; i++) {
      x += i == 2 ? _centerExtent : _itemExtent;
    }
    return x + 8;
  }

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final reduced = Motion.reduced(context);
    final blobDuration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 420);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.full),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Rad.full),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: _hPad),
                decoration: BoxDecoration(
                  color: palette.navBar,
                  borderRadius: BorderRadius.circular(Rad.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Sliding selection blob.
                    AnimatedPositioned(
                      duration: blobDuration,
                      curve: Motion.springSnappy,
                      left: _offsetOf(selectedIndex) - _hPad,
                      top: 12,
                      width: 48,
                      height: 48,
                      child: AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: selectedIndex == 2 ? 0 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(Rad.full),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < _items.length; index++)
                          index == 2
                              ? _AddButton(
                                  open: addOpen,
                                  onTap: () => onDestinationSelected(2),
                                )
                              : _NavItem(
                                  item: _items[index],
                                  selected: index == selectedIndex,
                                  onTap: () => onDestinationSelected(index),
                                ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selectedIcon, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : Motion.base,
              switchInCurve: Motion.settle,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                semanticLabel: item.label,
                size: selected ? 25 : 23,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.morph,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, AppColors.primaryDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: open ? 0.55 : 0.38),
                blurRadius: open ? 22 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: Motion.of(context, Motion.slow),
            curve: Motion.springSnappy,
            child: const Icon(
              Icons.add_rounded,
              semanticLabel: 'Add',
              color: AppColors.backgroundDark,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
