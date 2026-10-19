import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/liquid_page.dart';

/// Step-by-step setup of the Shortcuts automations that hand new bank SMS
/// and Apple Pay payments to Flourish (iPhone apps cannot read Messages).
class IphoneGuideScreen extends StatelessWidget {
  const IphoneGuideScreen({super.key});

  /// Opens the Shortcuts app; nothing happens where it is not installed.
  Future<void> _openShortcuts() => launchUrl(
    Uri.parse('shortcuts://'),
    mode: LaunchMode.externalApplication,
  ).then((_) {}, onError: (_) {});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final secondary = AppTextStyles.body.copyWith(
      color: AppColors.textSecondary(context),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.iosGuideTitle)),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            Sp.xxxl,
          ),
          children: [
            Text(l.iosGuideIntro, style: secondary),
            const SizedBox(height: Sp.lg),
            FilledButton.icon(
              onPressed: _openShortcuts,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l.iosGuideOpenShortcuts),
            ),
            const SizedBox(height: Sp.lg),
            _Steps(
              icon: Icons.sms_outlined,
              title: l.iosGuideMessagesTitle,
              steps: [
                l.iosGuideMsg1,
                l.iosGuideMsg2,
                l.iosGuideMsg3,
                l.iosGuideMsg4,
                l.iosGuideMsg5,
                l.iosGuideMsg6,
              ],
            ),
            const SizedBox(height: Sp.lg),
            _Steps(
              icon: Icons.contactless_outlined,
              title: l.iosGuideWalletTitle,
              steps: [
                l.iosGuideWallet1,
                l.iosGuideWallet2,
                l.iosGuideWallet3,
                l.iosGuideWallet4,
              ],
            ),
            const SizedBox(height: Sp.lg),
            _Steps(
              icon: Icons.check_circle_outline_rounded,
              title: l.iosGuideCheckTitle,
              steps: [l.iosGuideCheck],
              numbered: false,
            ),
            const SizedBox(height: Sp.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(l.catchUpTitle),
                subtitle: Text(l.iosGuideCatchUpHint),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/catch-up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.icon,
    required this.title,
    required this.steps,
    this.numbered = true,
  });

  final IconData icon;
  final String title;
  final List<String> steps;
  final bool numbered;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(Sp.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(title, style: AppTextStyles.subtitle)),
          ],
        ),
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(top: Sp.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                if (numbered) const SizedBox(width: Sp.md),
                Expanded(child: Text(step, style: AppTextStyles.body)),
              ],
            ),
          ),
      ],
    ),
  );
}
