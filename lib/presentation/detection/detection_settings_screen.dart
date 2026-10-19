import 'package:flourish/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/detection/detection_bridge.dart';
import '../../core/detection/issuers.dart';
import '../../core/detection/parsed_payment.dart';
import '../../core/detection/payment_parser.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/bottom_sheet_scaffold.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../../shared/widgets/liquid_page.dart';
import '../providers/ai_providers.dart';
import '../providers/finance_providers.dart';
import 'inbox_screen.dart' show kindLabel;

/// Messaging apps read by default once detection is on: bank SMS arrive
/// through them.
const defaultMessagingApps = [
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.mms',
  'com.android.messaging',
];

class DetectionSettingsScreen extends ConsumerStatefulWidget {
  const DetectionSettingsScreen({super.key});
  @override
  ConsumerState<DetectionSettingsScreen> createState() =>
      _DetectionSettingsScreenState();
}

class _DetectionSettingsScreenState
    extends ConsumerState<DetectionSettingsScreen>
    with WidgetsBindingObserver {
  bool enabled = PreferencesService.getBool('detection_enabled');
  bool auto = PreferencesService.getBool('detection_auto_confirm');
  bool notify = PreferencesService.getBool(
    'detection_notify',
    defaultValue: true,
  );
  bool backupText = PreferencesService.getBool('detection_backup_raw_text');
  int keepDays = PreferencesService.getInt(
    'detection_raw_text_days',
    defaultValue: 30,
  );
  late Set<String> packages = {
    ...(jsonDecode(
              PreferencesService.getString(
                'detection_packages',
                defaultValue: '[]',
              ),
            )
            as List)
        .cast<String>(),
  };
  bool? access;
  List<SourceCandidate> candidates = const [];
  List<InstalledApp> installed = const [];
  final _test = TextEditingController();
  ParsedPayment? _tested;

  bool get android => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _test.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system's notification access page.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  DetectionBridge get bridge => ref.read(detectionBridgeProvider);

  Future<void> _refresh() async {
    final granted = await bridge.isAccessGranted();
    final found = await bridge.candidates();
    final apps = android
        ? await bridge.installedApps()
        : const <InstalledApp>[];
    if (mounted) {
      setState(() {
        access = granted;
        candidates = found;
        installed = apps;
      });
    }
  }

  Future<void> _toggle(String packageName, bool on) async {
    setState(
      () => on ? packages.add(packageName) : packages.remove(packageName),
    );
    await PreferencesService.setString(
      'detection_packages',
      jsonEncode(packages.toList()),
    );
    await _push();
  }

  /// Every launchable app, searchable, so a bank app can be picked before
  /// it posts its first alert.
  Future<void> _pickInstalled() async {
    if (installed.isEmpty) {
      final apps = await bridge.installedApps();
      if (!mounted) return;
      setState(() => installed = apps);
    }
    var query = '';
    await showSpringBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final q = query.trim().toLowerCase();
          final shown = [
            for (final app in installed)
              if (!defaultMessagingApps.contains(app.packageName) &&
                  (q.isEmpty ||
                      app.label.toLowerCase().contains(q) ||
                      app.packageName.toLowerCase().contains(q)))
                app,
          ];
          return BottomSheetScaffold(
            title: context.l10n.bankWalletApps,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.searchApps,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setSheet(() => query = v),
              ),
              const SizedBox(height: Sp.sm),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.md),
                  child: Text(
                    installed.isEmpty
                        ? context.l10n.noAppsFound
                        : context.l10n.noMatchingApps,
                    style: AppTextStyles.caption,
                  ),
                ),
              for (final app in shown)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: packages.contains(app.packageName),
                  title: Text(app.label),
                  subtitle: Text(app.packageName, style: AppTextStyles.caption),
                  onChanged: (v) async {
                    await _toggle(app.packageName, v == true);
                    setSheet(() {});
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _push() => bridge.configure(
    enabled: enabled,
    packages: [...defaultMessagingApps, ...packages],
    notify: notify,
  );

  Future<void> _setEnabled(bool value) async {
    if (value && !await _disclose()) return;
    setState(() => enabled = value);
    await PreferencesService.setBool('detection_enabled', value);
    await _push();
    if (value && access != true) await bridge.openAccessSettings();
  }

  /// The prominent disclosure shown before notification access is asked.
  Future<bool> _disclose() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.readAlertsTitle),
          content: Text(ctx.l10n.readAlertsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.continueAction),
            ),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: Sp.sm),
            ...children,
          ],
        ),
      ),
    );
    final caption = AppTextStyles.caption.copyWith(color: palette.textLow);
    final labels = {for (final app in installed) app.packageName: app.label};
    final seen = {for (final c in candidates) c.packageName};
    // Picked from the installed list rather than from apps seen posting alerts.
    final picked = [
      for (final p in packages)
        if (!seen.contains(p) && !defaultMessagingApps.contains(p)) p,
    ]..sort((a, b) => (labels[a] ?? a).compareTo(labels[b] ?? b));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.paymentDetection)),
      body: LiquidPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            120,
          ),
          children: [
            if (android)
              section('Android', [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: _setEnabled,
                  title: Text(context.l10n.detectFromNotifications),
                  subtitle: Text(context.l10n.detectFromNotificationsSubtitle),
                ),
                if (enabled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      access == true
                          ? Icons.verified_user_outlined
                          : Icons.warning_amber_rounded,
                      color: access == true ? palette.income : palette.warning,
                    ),
                    title: Text(
                      access == true
                          ? context.l10n.accessGranted
                          : context.l10n.accessNeeded,
                    ),
                    subtitle: access == true
                        ? null
                        : Text(context.l10n.restrictedSettingsHint),
                    trailing: access == true
                        ? null
                        : TextButton(
                            onPressed: bridge.openAccessSettings,
                            child: Text(context.l10n.grant),
                          ),
                  ),
                if (enabled) ...[
                  const SizedBox(height: Sp.sm),
                  Text(
                    context.l10n.bankWalletApps,
                    style: AppTextStyles.bodyMedium,
                  ),
                  Text(context.l10n.messagingAlwaysRead, style: caption),
                  if (candidates.isEmpty && picked.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                      child: Text(context.l10n.noneSeenYet, style: caption),
                    ),
                  for (final c in candidates)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: packages.contains(c.packageName),
                      title: Text(c.label),
                      subtitle: Text(
                        context.l10n.alertsCount(c.count),
                        style: caption,
                      ),
                      onChanged: (v) => _toggle(c.packageName, v == true),
                    ),
                  for (final p in picked)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: Text(labels[p] ?? p),
                      subtitle: Text(
                        context.l10n.chosenFromInstalled,
                        style: caption,
                      ),
                      onChanged: (v) => _toggle(p, v == true),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _pickInstalled,
                      icon: const Icon(Icons.apps_rounded),
                      label: Text(context.l10n.chooseFromInstalled),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: notify,
                    title: Text(context.l10n.notifyNewPayments),
                    onChanged: (v) async {
                      setState(() => notify = v);
                      await PreferencesService.setBool('detection_notify', v);
                      await _push();
                    },
                  ),
                ],
              ])
            else
              section('iPhone', [
                Text(context.l10n.iosShortcutsIntro, style: AppTextStyles.body),
                const SizedBox(height: Sp.sm),
                for (final step in [
                  context.l10n.iosStep1,
                  context.l10n.iosStep2,
                  context.l10n.iosStep3,
                  context.l10n.iosStep4,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.xs),
                    child: Text('• $step', style: AppTextStyles.body),
                  ),
                Text(context.l10n.paymentsArriveInbox, style: caption),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt_rounded),
                  title: Text(context.l10n.iosGuideTitle),
                  subtitle: Text(context.l10n.iosGuideSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/detection/iphone'),
                ),
              ]),
            section(context.l10n.catchUpTitle, [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(context.l10n.catchUpTitle),
                subtitle: Text(context.l10n.catchUpSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/catch-up'),
              ),
            ]),
            section(context.l10n.addingPayments, [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: auto,
                title: Text(context.l10n.autoAddClear),
                subtitle: Text(context.l10n.autoAddClearSubtitle),
                onChanged: (v) async {
                  setState(() => auto = v);
                  await PreferencesService.setBool('detection_auto_confirm', v);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.psychology_alt_outlined),
                title: Text(context.l10n.aiForUnclear),
                subtitle: Text(
                  ref.watch(aiSettingsProvider).enabled
                      ? context.l10n.aiOnProvider(
                          ref.watch(aiSettingsProvider).preset.label,
                        )
                      : context.l10n.aiOffProviders,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings/ai'),
              ),
            ]),
            section(context.l10n.privacy, [
              DropdownButtonFormField<int>(
                initialValue: keepDays,
                decoration: InputDecoration(
                  labelText: context.l10n.keepMessageText,
                ),
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(context.l10n.dontKeep),
                  ),
                  for (final d in [7, 30, 90])
                    DropdownMenuItem(
                      value: d,
                      child: Text(context.l10n.daysCount(d)),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => keepDays = v);
                  await PreferencesService.setInt('detection_raw_text_days', v);
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: backupText,
                title: Text(context.l10n.includeTextInBackups),
                onChanged: (v) async {
                  setState(() => backupText = v);
                  await PreferencesService.setBool(
                    'detection_backup_raw_text',
                    v,
                  );
                },
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(detectionServiceProvider).purgeAllText();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.messageTextDeleted),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(context.l10n.deleteAllMessageText),
                ),
              ),
            ]),
            section(context.l10n.testMessage, [
              TextField(
                controller: _test,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(hintText: context.l10n.pasteAlert),
                onChanged: (v) => setState(
                  () => _tested = v.trim().isEmpty
                      ? null
                      : PaymentMessageParser.parse(
                          RawMessage(
                            text: v,
                            receivedAt: DateTime.now(),
                            source: 'paste',
                          ),
                        ),
                ),
              ),
              if (_tested case final p?)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.sm),
                  child: Text(
                    p.ignored
                        ? context.l10n.notAPayment('${p.ignoreReason}')
                        : '${kindLabel(p.kind)}: ${p.currency ?? '?'} ${p.amount}'
                              '${p.merchant == null ? '' : ' · ${p.merchant}'}'
                              '${p.counterparty == null ? '' : ' · ${p.counterparty}'}'
                              '${p.last4 == null ? '' : ' · ••${p.last4}'}'
                              '${Issuers.byId(p.issuerId) == null ? '' : ' · ${Issuers.byId(p.issuerId)!.name}'}'
                              ' · ${context.l10n.percentSure((p.confidence * 100).round())}',
                    style: AppTextStyles.body,
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
