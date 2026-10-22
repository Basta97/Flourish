import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../core/ai/ai_config.dart';

/// Asks before screenshots may be sent to the AI as images. Shown when the
/// person turns the option on, from AI settings or from Smart Import.
Future<bool> confirmScreenshotAi(
  BuildContext context,
  AiSettings settings,
) async {
  final provider = settings.preset;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.screenshotAiTitle),
      content: Text(
        '${ctx.l10n.screenshotAiBody(provider.label)}'
        '${provider.free ? '\n\n${ctx.l10n.freeTiersKeep}' : ''}'
        '\n\n${ctx.l10n.screenshotAiFooter}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.turnOn),
        ),
      ],
    ),
  );
  return agreed == true;
}

/// Asks before captured alerts may be sent to the AI without a tap. The
/// answer is recorded for this provider's host only.
Future<bool> confirmAutomaticAi(
  BuildContext context,
  AiSettings settings,
) async {
  final provider = settings.preset.label;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.aiAutomaticTitle(provider)),
      content: SingleChildScrollView(
        child: Text(
          '${ctx.l10n.aiAutomaticBody(provider, settings.host)}'
          '${settings.preset.free ? '\n\n${ctx.l10n.freeTiersKeep}' : ''}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.aiAutomaticAgree),
        ),
      ],
    ),
  );
  return agreed == true;
}
