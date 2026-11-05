import '../../presentation/currencies/exchange_rates_screen.dart';
import '../../presentation/templates/templates_screen.dart';
import 'package:flourish/presentation/detection/catch_up_screen.dart';
import 'package:flourish/presentation/detection/iphone_guide_screen.dart';
import 'package:flourish/presentation/settings/ai_settings_screen.dart';
import 'package:flourish/presentation/detection/inbox_screen.dart';
import 'package:flourish/presentation/detection/detection_settings_screen.dart';
import 'package:flourish/presentation/payment_methods/payment_methods_screen.dart';
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
import '../../shared/widgets/nav_icons.dart';
import '../motion/motion.dart';
import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  errorBuilder: (context, state) =>
      NotFoundScreen(subtitle: context.l10n.pageNotFound('${state.uri}')),
  routes: [
    // Each tab keeps its own navigator, so switching back finds the page
    // where it was left (scroll, filters) instead of rebuilding it.
    StatefulShellRoute(
      builder: (context, state, shell) => ScaffoldWithNavBar(child: shell),
      navigatorContainerBuilder: (context, shell, children) =>
          _TabSwitcher(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) => NoTransitionPage(
                child: TransactionsScreen(
                  key: ValueKey(state.uri.query),
                  initialCategory: int.tryParse(
                    state.uri.queryParameters['category'] ?? '',
                  ),
                  initialMonth: _parseMonth(state.uri.queryParameters['month']),
                ),
              ),
            ),
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SearchScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AccountsScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              pageBuilder: (context, state) => NoTransitionPage(
                child: InsightsScreen(
                  key: ValueKey(state.uri.queryParameters['tab']),
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ),
          ],
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
/// Shows the active tab. On a switch the old tab fades out quickly and the
/// new one fades in with a short slide from the side it was tapped on.
/// Inactive tabs stay mounted but offstage, with their tickers paused.
class _TabSwitcher extends StatefulWidget {
  const _TabSwitcher({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<_TabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
        value: 1,
      )..addStatusListener((status) {
        // Takes the old tab offstage once it has faded.
        if (status == AnimationStatus.completed) setState(() {});
      });
  late int _previous = widget.index;
  double _direction = 1;

  @override
  void didUpdateWidget(_TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _previous = old.index;
    _direction = widget.index > old.index ? 1 : -1;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final leaving = _controller.isAnimating ? _previous : null;
    final fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    final fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 1, curve: Motion.enter),
    );
    final slideIn = Tween<Offset>(
      begin: Offset(0.06 * _direction * (rtl ? -1 : 1), 0),
      end: Offset.zero,
    ).animate(fadeIn);
    // Every tab keeps the same wrappers in every state, and keyed slots let
    // the stack reorder them, so no tab is ever rebuilt by a switch. The
    // incoming tab paints last, above the one fading out.
    final order = [
      for (var i = 0; i < widget.children.length; i++)
        if (i != widget.index && i != leaving) i,
      ?leaving,
      widget.index,
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final i in order)
          KeyedSubtree(
            key: ValueKey(i),
            child: IgnorePointer(
              ignoring: i != widget.index,
              child: FadeTransition(
                opacity: i == widget.index
                    ? fadeIn
                    : i == leaving
                    ? ReverseAnimation(fadeOut)
                    : kAlwaysCompleteAnimation,
                child: SlideTransition(
                  position: i == widget.index
                      ? slideIn
                      : const AlwaysStoppedAnimation(Offset.zero),
                  child: Offstage(
                    offstage: i != widget.index && i != leaving,
                    child: TickerMode(
                      enabled: i == widget.index,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ScaffoldWithNavBar extends StatefulWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _addOpen = false;

  /// Tab tapped but not routed to yet.
  int? _pending;

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
    final routed = _currentIndex(context);
    // The tapped tab lights up at once; the route catches up a frame or two
    // later, after the new page has been built.
    if (_pending == routed) _pending = null;
    final index = _pending ?? routed;
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
                  if (i != 2 && i != index) {
                    Haptics.select();
                    setState(() => _pending = i);
                  }
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

  static List<({NavGlyph glyph, String label})> _items(AppLocalizations l) => [
    (glyph: NavGlyph.home, label: l.navHome),
    (glyph: NavGlyph.ledger, label: l.navLedger),
    (glyph: NavGlyph.home, label: l.add), // centre slot: the add button
    (glyph: NavGlyph.accounts, label: l.navAccounts),
    (glyph: NavGlyph.insights, label: l.navInsights),
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
        : const Duration(milliseconds: 300);

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
          // Near-opaque instead of frosted: a backdrop blur here would
          // re-render every frame while the page scrolls underneath.
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Rad.full),
              child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: _hPad),
                decoration: BoxDecoration(
                  color: palette.navBar,
                  borderRadius: BorderRadius.circular(Rad.full),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.11),
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
                      top: 8,
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
                                  glyph: items[index].glyph,
                                  label: items[index].label,
                                  selected: index == selectedIndex,
                                  cutout: palette.navBar,
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

/// Icon-only tab: the glyph fills in and plays its flourish when chosen,
/// and springs under the finger. The name is kept for screen readers.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.cutout,
    required this.onTap,
  });

  final NavGlyph glyph;
  final String label;
  final bool selected;
  final Color cutout;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: Motion.fast,
    value: widget.selected ? 1 : 0,
  );
  late final AnimationController _flourish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    value: 1,
  );

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    if (Motion.reduced(context)) {
      _fill.value = widget.selected ? 1 : 0;
      return;
    }
    if (widget.selected) {
      _fill.forward();
      _flourish.forward(from: 0);
    } else {
      _fill.reverse();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _flourish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Selected glyphs sit on the selection blob, so details cut out to that.
    final cutout = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.10),
      widget.cutout,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        // Screen readers activate through here, the gesture below is hidden.
        onTap: widget.onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: widget.label,
          excludeFromSemantics: true,
          child: Pressable(
            onTap: widget.onTap,
            onTapDown: true,
            scale: 0.8,
            haptic: false,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fill, _flourish]),
                  builder: (context, _) {
                    final fill = Motion.morph.transform(_fill.value);
                    return NavIcon(
                      glyph: widget.glyph,
                      size: 25,
                      fill: fill,
                      flourish: _flourish.value,
                      cutout: cutout,
                      color: Color.lerp(
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white,
                        fill,
                      )!,
                    );
                  },
                ),
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
                // A soft lift, not a glow.
                color: accent.withValues(alpha: open ? 0.22 : 0.14),
                blurRadius: open ? 12 : 8,
                offset: const Offset(0, 3),
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
