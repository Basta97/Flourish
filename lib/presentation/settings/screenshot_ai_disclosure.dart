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
      title: const Text('Read screenshots with AI?'),
      content: Text(
        "Android's on-device text reader cannot read Arabic. With this on, "
        'a screenshot you choose to read with AI is sent as an image to '
        '${provider.label}. An image cannot be masked: names, card or '
        'account numbers and balances visible in it are sent too.'
        '${provider.free ? '\n\nFree tiers may keep what you send.' : ''}'
        '\n\nOn-device reading stays the default; nothing is sent until you '
        'tap "Read with AI". You can turn this off in AI settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Turn on'),
        ),
      ],
    ),
  );
  return agreed == true;
}
