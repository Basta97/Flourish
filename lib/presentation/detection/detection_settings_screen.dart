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
import '../../shared/widgets/liquid_page.dart';
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
    if (mounted) {
      setState(() {
        access = granted;
        candidates = found;
      });
    }
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
          title: const Text('Read payment alerts?'),
          content: const Text(
            'Flourish will read notifications from your messaging app and '
            'the bank or wallet apps you choose, to find payment alerts '
            '(amount, merchant, card ending). Other notifications are ignored '
            'on the spot. One-time codes and declined payments are never '
            'saved, card numbers are reduced to their last 4 digits, and '
            'nothing leaves your phone. You review every payment before it is '
            'added, unless you turn on automatic adding.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Payment detection')),
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
                  title: const Text('Detect payments from notifications'),
                  subtitle: const Text(
                    'Bank SMS and bank or wallet app alerts go to your inbox',
                  ),
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
                          ? 'Notification access granted'
                          : 'Notification access needed',
                    ),
                    subtitle: access == true
                        ? null
                        : const Text(
                            'If the switch is greyed out, open App info › ⋮ › '
                            'Allow restricted settings first.',
                          ),
                    trailing: access == true
                        ? null
                        : TextButton(
                            onPressed: bridge.openAccessSettings,
                            child: const Text('Grant'),
                          ),
                  ),
                if (enabled) ...[
                  const SizedBox(height: Sp.sm),
                  Text('Bank and wallet apps', style: AppTextStyles.bodyMedium),
                  Text(
                    'Messaging apps are always read. Apps that posted '
                    'money-like notifications appear here; tick the ones from '
                    'your bank or wallet.',
                    style: caption,
                  ),
                  if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                      child: Text(
                        'None seen yet. They appear after the next alert.',
                        style: caption,
                      ),
                    ),
                  for (final c in candidates)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: packages.contains(c.packageName),
                      title: Text(c.label),
                      subtitle: Text('${c.count} alerts', style: caption),
                      onChanged: (v) async {
                        setState(() {
                          v == true
                              ? packages.add(c.packageName)
                              : packages.remove(c.packageName);
                        });
                        await PreferencesService.setString(
                          'detection_packages',
                          jsonEncode(packages.toList()),
                        );
                        await _push();
                      },
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: notify,
                    title: const Text('Notify me about new payments'),
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
                Text(
                  'iOS does not let apps read messages, so Shortcuts sends '
                  'them to Flourish. Set this up once (iOS 17 or later):',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: Sp.sm),
                for (final step in const [
                  'Open Shortcuts › Automation › New Automation › Message.',
                  'Message Contains: EGP. Choose Run Immediately. Make one '
                      'more automation for each word your bank uses: جنيه, '
                      'ج.م, and the currencies you pay in abroad or online, '
                      'such as USD, دولار, EUR, SAR.',
                  'Add the action "Import Transaction Text" from Flourish and '
                      'pass it the Message and Sender.',
                  'For Apple Pay: New Automation › Wallet › choose your cards '
                      '› Run Immediately › "Log Card Payment" with Amount, '
                      'Merchant and Card.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.xs),
                    child: Text('• $step', style: AppTextStyles.body),
                  ),
                Text(
                  'Payments arrive in your inbox without opening Flourish.',
                  style: caption,
                ),
              ]),
            section('Adding payments', [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: auto,
                title: const Text('Add clear payments automatically'),
                subtitle: const Text(
                  'Only purchases and refunds from a recognised bank, on a card '
                  'you saved with its last 4 digits, with no doubt about the '
                  'amount or a possible duplicate. Everything else waits for you.',
                ),
                onChanged: (v) async {
                  setState(() => auto = v);
                  await PreferencesService.setBool('detection_auto_confirm', v);
                },
              ),
            ]),
            section('Privacy', [
              DropdownButtonFormField<int>(
                initialValue: keepDays,
                decoration: const InputDecoration(
                  labelText: 'Keep message text after review',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Don't keep")),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
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
                title: const Text('Include message text in backups'),
                onChanged: (v) async {
                  setState(() => backupText = v);
                  await PreferencesService.setBool(
                    'detection_backup_raw_text',
                    v,
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(detectionServiceProvider).purgeAllText();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message text deleted')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete all message text now'),
                ),
              ),
            ]),
            section('Test a message', [
              TextField(
                controller: _test,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Paste a bank or wallet alert',
                ),
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
                        ? 'Not a payment (${p.ignoreReason}).'
                        : '${kindLabel(p.kind)}: ${p.currency ?? '?'} ${p.amount}'
                              '${p.merchant == null ? '' : ' at ${p.merchant}'}'
                              '${p.counterparty == null ? '' : ' · ${p.counterparty}'}'
                              '${p.last4 == null ? '' : ' · card ••${p.last4}'}'
                              '${Issuers.byId(p.issuerId) == null ? '' : ' · ${Issuers.byId(p.issuerId)!.name}'}'
                              ' · ${(p.confidence * 100).round()}% sure',
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
