import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/finance/monthly_summary_service.dart';
import '../../core/router/app_router.dart';
import '../../core/services/preferences_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/home_widget_snapshot.dart';
import '../../l10n/l10n.dart';
import '../providers/finance_providers.dart';
import '../providers/database_provider.dart';
import '../wealth/finance_runtime.dart' show appUnlocked;

const homeWidgetChannel = MethodChannel('flourish/widgets');

class HomeWidgetRuntime extends ConsumerStatefulWidget {
  final Widget child;
  const HomeWidgetRuntime({super.key, required this.child});
  @override
  ConsumerState<HomeWidgetRuntime> createState() => _HomeWidgetRuntimeState();
}

class _HomeWidgetRuntimeState extends ConsumerState<HomeWidgetRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<void>? finance;
  StreamSubscription<String>? preferences;
  Timer? debounce, boundary;
  int revision = 0;
  String? pendingAction;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appUnlocked.addListener(_followAction);
    finance = ref
        .read(databaseProvider)
        .financeChanges
        .stream
        .listen((_) => _schedule());
    preferences = PreferencesService.changes.stream.listen((_) => _schedule());
    homeWidgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'actionAvailable') await _consume();
      if (call.method == 'action') {
        pendingAction = call.arguments as String?;
        _followAction();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedule();
      _consume();
    });
  }

  void _schedule() {
    revision++;
    debounce?.cancel();
    // Publish privacy changes before calculating totals or doing database work.
    if (PreferencesService.getBool('app_lock_enabled') ||
        PreferencesService.getBool('hide_amounts')) {
      unawaited(_publish(privateOnly: true));
    }
    debounce = Timer(const Duration(milliseconds: 250), _publish);
  }

  Future<void> _consume() async {
    try {
      pendingAction =
          await homeWidgetChannel.invokeMethod<String>('consumeAction') ??
          pendingAction;
      _followAction();
    } on MissingPluginException {
      /* Desktop and tests have no phone widgets. */
    } on PlatformException catch (e) {
      debugPrint('Widget action: $e');
    }
  }

  void _followAction() {
    if (!mounted || !appUnlocked.value || pendingAction == null) return;
    final action = pendingAction;
    pendingAction = null;
    if (action == 'home') appRouter.go('/dashboard');
    if (action == 'add' || action == 'template') {
      appRouter.push('/widget/$action');
    }
  }

  Future<void> _publish({bool privateOnly = false}) async {
    final token = revision;
    try {
      final now = DateTime.now();
      final prefs = PreferencesService.prefs;
      final day = prefs.getInt('month_start_day') ?? 1;
      final currency = prefs.getString('default_currency') ?? 'EGP';
      final locale =
          prefs.getString('app_locale') ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final code = locale == 'ar' ? 'ar' : 'en';
      final l = lookupAppLocalizations(Locale(code));
      final hidden =
          prefs.getBool('app_lock_enabled') == true ||
          prefs.getBool('hide_amounts') == true;
      final end = MonthlySummaryService.period(now, day).$2;
      boundary?.cancel();
      boundary = Timer(
        end.difference(now) + const Duration(seconds: 1),
        _schedule,
      );
      String? income, spending;
      var empty = false, missing = 0;
      if (!hidden && !privateOnly) {
        final store = ref.read(financeStoreProvider);
        final transactions = await store.db.getAllTransactions();
        empty = transactions.isEmpty;
        final totals = await MonthlySummaryService(
          store,
          ref.read(valuationProvider),
        ).calculate(transactions, currency, day: day, at: now);
        missing = totals.$3;
        final format = NumberFormat.decimalPatternDigits(
          locale: code,
          decimalDigits: CurrencyFormatter.decimalsFor(currency),
        );
        income = format.format(totals.$1.toDouble());
        spending = format.format(totals.$2.toDouble());
      }
      if (!mounted || token != revision) return;
      final snapshot = HomeWidgetSnapshot.create(
        hidden: hidden,
        currency: currency,
        locale: code,
        updatedAt: now,
        periodEnd: end,
        income: income,
        spending: spending,
        empty: empty,
        missingRates: missing,
        labels: {
          'title': l.widgetMonthlySummary,
          'quickTitle': l.widgetQuickAdd,
          'incomeLabel': l.income,
          'spendingLabel': l.spending,
          'addLabel': l.newTransaction,
          'templateLabel': l.useTemplate,
          'emptyLabel': l.noTransactions,
          'refreshLabel': l.widgetOpenToRefresh,
          'updatedLabel': l.widgetUpdated,
        },
      );
      await homeWidgetChannel.invokeMethod<void>(
        'publish',
        jsonEncode(snapshot),
      );
    } on MissingPluginException {
      /* No native widgets on this platform. */
    } catch (e) {
      debugPrint('Widget snapshot: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      _consume();
    }
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    boundary?.cancel();
    finance?.cancel();
    preferences?.cancel();
    appUnlocked.removeListener(_followAction);
    WidgetsBinding.instance.removeObserver(this);
    homeWidgetChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
