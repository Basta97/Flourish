import '../../presentation/currencies/exchange_rates_screen.dart';
import '../../presentation/templates/templates_screen.dart';
import 'package:flourish/presentation/detection/catch_up_screen.dart';
import 'package:flourish/presentation/detection/iphone_guide_screen.dart';
import 'package:flourish/presentation/settings/ai_settings_screen.dart';
import 'package:flourish/presentation/detection/inbox_screen.dart';
import 'package:flourish/presentation/detection/detection_settings_screen.dart';
import 'package:flourish/presentation/payment_methods/payment_methods_screen.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/accounts/accounts_screen.dart';
import '../../presentation/accounts/account_detail_screen.dart';
import '../../presentation/transactions/transactions_screen.dart';
import '../../presentation/insights/insights_screen.dart';
import '../../presentation/search/search_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/categories/categories_management_screen.dart';
import '../../presentation/recurring/recurring_transactions_screen.dart';
import '../../presentation/transactions/notification_import_screen.dart';
import '../../presentation/shared/not_found_screen.dart';
import '../../core/models/shared_import_draft.dart';
import '../../presentation/transactions/widgets/add_transaction_sheet.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../motion/motion.dart';
import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  errorBuilder: (context, state) =>
      NotFoundScreen(subtitle: context.l10n.pageNotFound('${state.uri}')),
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/insights',
          pageBuilder: (context, state) => _fadeThroughPage(
            key: state.pageKey,
            child: InsightsScreen(
              key: ValueKey(state.uri.queryParameters['tab']),
              initialTab: state.uri.queryParameters['tab'],
            ),
          ),
        ),
        GoRoute(
          path: '/transactions',
          pageBuilder: (context, state) => _fadeThroughPage(
            key: state.pageKey,
            child: TransactionsScreen(
              key: ValueKey(state.uri.query),
              initialCategory: int.tryParse(
                state.uri.queryParameters['category'] ?? '',
              ),
              initialMonth: _parseMonth(state.uri.queryParameters['month']),
            ),
          ),
        ),
        for (final (path, screen) in <(String, Widget)>[
          ('/dashboard', const DashboardScreen()),
          ('/search', const SearchScreen()),
          ('/accounts', const AccountsScreen()),
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
          return NotFoundScreen(
            title: context.l10n.accountNotFound,
            subtitle: context.l10n.accountNotFoundSubtitle,
          );
        }
        return AccountDetailScreen(accountId: id);
      },
    ),
    GoRoute(
      path: '/widget/add',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          Scaffold(appBar: AppBar(), body: const AddTransactionSheet()),
    ),
    GoRoute(
      path: '/widget/template',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          Scaffold(appBar: AppBar(), body: const TemplateTransactionSheet()),
    ),
    GoRoute(
      path: '/exchange-rates',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExchangeRatesScreen(),
    ),
    // Tools were folded into Settings.
    GoRoute(path: '/tools', redirect: (_, _) => '/settings'),
    GoRoute(
      path: '/templates',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TemplatesScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => SettingsScreen(
        section: state.uri.queryParameters['section'] == 'data' ? 'data' : null,
      ),
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
      path: '/inbox',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const InboxScreen(),
    ),
    GoRoute(
      path: '/settings/ai',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiSettingsScreen(),
    ),
    GoRoute(
      path: '/catch-up',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CatchUpScreen(),
    ),
    GoRoute(
      path: '/settings/detection/iphone',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IphoneGuideScreen(),
    ),
    GoRoute(
      path: '/settings/detection',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DetectionSettingsScreen(),
    ),
    GoRoute(
      path: '/payment-methods',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PaymentMethodsScreen(),
    ),
    // Older locations now live as Insights tabs.
    GoRoute(
      path: '/wealth',
      redirect: (context, state) =>
          state.uri.queryParameters['tab'] == 'reports'
          ? '/insights?tab=spending'
          : '/insights?tab=holdings',
    ),
    GoRoute(path: '/budgets', redirect: (_, _) => '/insights?tab=budgets'),
    GoRoute(path: '/goals', redirect: (_, _) => '/insights?tab=goals'),
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

DateTime? _parseMonth(String? value) {
  final parts = value?.split('-');
  if (parts == null || parts.length != 2) return null;
  final year = int.tryParse(parts[0]), month = int.tryParse(parts[1]);
  return year == null || month == null ? null : DateTime(year, month);
}

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
    if (location.startsWith('/insights')) return 4;
    return 0;
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
                      context.go('/insights');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The centre button always does one thing: a new expense. Income,
  /// transfers, templates and scanning are one tap away inside the sheet;
  /// accounts, budgets and goals are added from their own screens.
  Future<void> _showAddSheet(BuildContext context) async {
    Haptics.tap();
    setState(() => _addOpen = true);
    await showSpringBottomSheet(
      context: context,
      builder: (_) => const AddTransactionSheet(initialType: 'expense'),
    );
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

  static List<({IconData icon, IconData selectedIcon, String label})> _items(
    AppLocalizations l,
  ) => [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: l.navHome,
    ),
    (
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: l.navLedger,
    ),
    (icon: Icons.add_rounded, selectedIcon: Icons.add_rounded, label: l.add),
    (
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: l.navAccounts,
    ),
    (
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: l.navInsights,
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
    final items = _items(context.l10n);
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
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    // Sliding selection blob.
                    AnimatedPositionedDirectional(
                      duration: blobDuration,
                      curve: Motion.springSnappy,
                      start: _offsetOf(selectedIndex) - _hPad,
                      top: 12,
                      width: 48,
                      height: 48,
                      child: AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: selectedIndex == 2 ? 0 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(Rad.lg),
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
                        for (var index = 0; index < items.length; index++)
                          index == 2
                              ? _AddButton(
                                  open: addOpen,
                                  onTap: () => onDestinationSelected(2),
                                )
                              : _NavItem(
                                  item: items[index],
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
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
                  size: 22,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              // Visible names: the icons alone were hard to tell apart.
              ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ],
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
            child: Icon(
              Icons.add_rounded,
              semanticLabel: context.l10n.add,
              color: AppColors.backgroundDark,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
