import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/authentication_coordinator.dart';
import '../../../core/motion/motion.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/spring_bottom_sheet.dart';
import '../../accounts/accounts_screen.dart' show AddAccountSheet;
import '../../currencies/currency_picker.dart';
import '../../providers/account_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/transaction_providers.dart';

/// First-run steps at the top of Home: currency, a first account, the app
/// lock and (optionally) payment detection. Hidden once dismissed or once
/// the person has recorded anything.
class SetupChecklist extends ConsumerStatefulWidget {
  const SetupChecklist({super.key});

  static bool get dismissed => PreferencesService.getBool('setup_done');

  @override
  ConsumerState<SetupChecklist> createState() => _SetupChecklistState();
}

class _SetupChecklistState extends ConsumerState<SetupChecklist> {
  Future<void> _dismiss() async {
    Haptics.success();
    await PreferencesService.setBool('setup_done', true);
    if (mounted) setState(() {});
  }

  Future<void> _lock() async {
    final l = context.l10n;
    final auth = AuthenticationCoordinator.instance;
    try {
      if (!await auth.isDeviceSupported()) {
        throw StateError(l.setUpPasscodeFirst);
      }
      if (await auth.authenticate(l.changeAppLockReason)) {
        await PreferencesService.setBool('app_lock_enabled', true);
        ref.read(databaseProvider).notifyFinanceChanged();
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider).valueOrNull;
    if (SetupChecklist.dismissed ||
        transactions == null ||
        transactions.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final palette = FlourishPalette.of(context);
    final currency = ref.watch(defaultCurrencyProvider);
    final hasAccount =
        (ref.watch(accountsProvider).valueOrNull ?? []).isNotEmpty;
    final locked = PreferencesService.getBool('app_lock_enabled');
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.sm, Sp.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.setupTitle,
                        style: AppTextStyles.title.copyWith(
                          color: palette.textHigh,
                        ),
                      ),
                      Text(
                        l.setupSubtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: palette.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _dismiss, child: Text(l.setupDone)),
              ],
            ),
            const SizedBox(height: Sp.sm),
            _Step(
              done: true,
              label: l.setupCurrency(currency),
              onTap: () async {
                final v = await pickCurrency(context, selected: currency);
                if (v != null && context.mounted) {
                  ref.read(defaultCurrencyProvider.notifier).state = v;
                  persistSettings(ref);
                }
              },
            ),
            _Step(
              done: hasAccount,
              label: l.setupAccount,
              onTap: () => showSpringBottomSheet(
                context: context,
                builder: (_) => const AddAccountSheet(),
              ),
            ),
            _Step(
              done: locked,
              label: l.setupLock,
              onTap: locked ? null : _lock,
            ),
            _Step(
              done: false,
              optional: true,
              label: l.setupDetection,
              onTap: () => context.push('/settings/detection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.label,
    required this.onTap,
    this.optional = false,
  });

  final bool done;
  final bool optional;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.only(end: Sp.sm),
      leading: Icon(
        done
            ? Icons.check_circle_rounded
            : optional
            ? Icons.add_circle_outline_rounded
            : Icons.radio_button_unchecked_rounded,
        color: done ? palette.accent : palette.textLow,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(color: palette.textHigh),
      ),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: palette.textLow),
      onTap: onTap,
    );
  }
}
