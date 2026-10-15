import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' hide Column;
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';
import '../providers/database_provider.dart';
import '../../core/finance/backup_service.dart';
import '../../core/finance/reminder_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/database/database.dart';

final remindersProvider = Provider((ref) => ReminderService());

class FinanceRuntime extends ConsumerStatefulWidget {
  final Widget child;
  const FinanceRuntime({super.key, required this.child});
  @override
  ConsumerState<FinanceRuntime> createState() => _FinanceRuntimeState();
}

class _FinanceRuntimeState extends ConsumerState<FinanceRuntime>
    with WidgetsBindingObserver {
  bool running = false;
  StreamSubscription<void>? changes;
  Timer? checkpoint;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    changes = ref.read(databaseProvider).financeChanges.stream.listen((_) {
      checkpoint?.cancel();
      checkpoint = Timer(const Duration(seconds: 1), () async {
        if (!mounted) return;
        final valuation = ref.read(valuationProvider),
            currency = ref.read(defaultCurrencyProvider),
            db = ref.read(databaseProvider),
            reminders = ref.read(remindersProvider),
            store = ref.read(financeStoreProvider);
        try {
          await valuation.snapshot(currency);
          if (!mounted) return;
          await BackupService(db).automaticBackup();
          await reminders.schedule(store);
        } catch (e) {
          debugPrint('Finance checkpoint: $e');
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void dispose() {
    changes?.cancel();
    checkpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (running || !mounted) return;
    running = true;
    final db = ref.read(databaseProvider);
    try {
      await db.processDueRecurringTransactions();
      if (!mounted) return;
      await _income();
      if (!mounted) return;
      final currency = ref.read(defaultCurrencyProvider);
      await ref.read(marketDataProvider).refresh(reportingCurrency: currency);
      if (!mounted) return;
      await ref.read(valuationProvider).snapshot(currency);
      if (!mounted) return;
      await BackupService(db).automaticBackup();
      if (!mounted) return;
      await ref
          .read(remindersProvider)
          .schedule(ref.read(financeStoreProvider));
    } catch (e, st) {
      debugPrint('Finance refresh: $e\n$st');
    } finally {
      running = false;
    }
  }

  Future<void> _income() async {
    if (!ref.read(monthlyAutoIncomeProvider)) return;
    final amount = ref.read(monthlyIncomeAmountProvider),
        accountId = ref.read(monthlyIncomeAccountIdProvider),
        categoryId = ref.read(monthlyIncomeCategoryIdProvider);
    if (amount <= 0 || accountId == null || categoryId == null) return;
    final now = DateTime.now(),
        key = '${DateTime.now().year}-${DateTime.now().month}';
    final last = DateTime(now.year, now.month + 1, 0).day;
    final day = ref.read(monthlyIncomeDayProvider).clamp(1, last);
    if (now.day < day ||
        PreferencesService.getString('last_auto_income_month') == key) {
      return;
    }
    final ledger = ref.read(financialLedgerProvider);
    final database = ref.read(databaseProvider);
    await database.transaction(() async {
      final db = database;
      final exists = (await db.getTransactionsByAccount(accountId)).any(
        (t) =>
            t.note == 'Auto monthly income' &&
            t.transactionDate.year == now.year &&
            t.transactionDate.month == now.month,
      );
      if (!exists) {
        await ledger.insertTransactionAndUpdateBalance(
          TransactionsCompanion.insert(
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            type: 'income',
            note: const Value('Auto monthly income'),
            transactionDate: DateTime(now.year, now.month, day),
          ),
        );
      }
    });
    await PreferencesService.setString('last_auto_income_month', key);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class FinanceAppLock extends StatefulWidget {
  final Widget child;
  const FinanceAppLock({super.key, required this.child});
  @override
  State<FinanceAppLock> createState() => _FinanceAppLockState();
}

class _FinanceAppLockState extends State<FinanceAppLock>
    with WidgetsBindingObserver {
  bool locked = PreferencesService.getBool('app_lock_enabled'),
      authenticating = false,
      private = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (locked) WidgetsBinding.instance.addPostFrameCallback((_) => unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!PreferencesService.getBool('app_lock_enabled')) return;
    if (state == AppLifecycleState.inactive) {
      setState(() => private = true);
    }
    if (state == AppLifecycleState.paused) {
      setState(() => locked = true);
    }
    if (state == AppLifecycleState.resumed) {
      setState(() => private = false);
      if (locked && !authenticating) unlock();
    }
  }

  Future<void> unlock() async {
    if (authenticating) return;
    setState(() => authenticating = true);
    try {
      final accepted = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock your Flourish finances',
        persistAcrossBackgrounding: true,
      );
      if (mounted) {
        setState(() {
          locked = !accepted;
          error = accepted ? null : 'Authentication cancelled';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unlock with your device authentication to continue.',
        );
      }
    } finally {
      if (mounted) setState(() => authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obscured = locked || private;
    // The app stays mounted underneath so navigation and scroll positions
    // survive a lock; while obscured it is hidden from touch and from
    // screen readers, and its animations are paused.
    return Stack(
      children: [
        Positioned.fill(
          child: TickerMode(
            enabled: !obscured,
            child: IgnorePointer(
              ignoring: obscured,
              child: ExcludeSemantics(excluding: obscured, child: widget.child),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !obscured,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.slow),
              switchInCurve: Motion.enter,
              switchOutCurve: Curves.easeInCubic,
              child: !obscured
                  ? const SizedBox.shrink(key: ValueKey('open'))
                  : _LockCurtain(
                      key: const ValueKey('locked'),
                      // The app-switcher snapshot only needs the curtain.
                      showControls: locked && !private,
                      authenticating: authenticating,
                      error: error,
                      onUnlock: unlock,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Frosted, branded cover shown while locked or in the app switcher.
class _LockCurtain extends StatelessWidget {
  const _LockCurtain({
    super.key,
    required this.showControls,
    required this.authenticating,
    required this.error,
    required this.onUnlock,
  });

  final bool showControls;
  final bool authenticating;
  final String? error;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Material(
          // Near-opaque so nothing behind is legible even mid-blur.
          color: palette.background.withValues(alpha: 0.94),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primaryDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withValues(alpha: 0.35),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: AppColors.backgroundDark,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  Text(
                    'Flourish',
                    style: AppTextStyles.headline.copyWith(
                      color: palette.textHigh,
                    ),
                  ),
                  if (showControls) ...[
                    const SizedBox(height: Sp.sm),
                    Text(
                      error ?? 'Your finances are locked.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: error == null
                            ? palette.textLow
                            : palette.warning,
                      ),
                    ),
                    const SizedBox(height: Sp.xxl),
                    FilledButton.icon(
                      onPressed: authenticating ? null : onUnlock,
                      icon: authenticating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: const Text('Unlock'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(180, 52),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
