import 'ai_client.dart';
import 'ai_payment_assist.dart' show AiUsageTracker;
import 'prompts.dart';

/// Transcribes a screenshot with a vision-capable model, for Android, whose
/// on-device reader (ML Kit Latin) cannot read Arabic. The text then goes
/// through the same detection as on-device OCR. An image cannot be masked,
/// so this only runs after the person has agreed to send it.
class AiScreenshotReader {
  AiScreenshotReader(this.client, {this.usage});
  final AiClient client;
  final AiUsageTracker? usage;

  /// Larger images are refused rather than sent (providers cap inline
  /// images at a few MB once base64-encoded).
  static const maxBytes = 6 * 1024 * 1024;

  static String mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String> read(List<int> bytes, {String mimeType = 'image/jpeg'}) async {
    if (bytes.length > maxBytes) {
      throw const AiException('This image is too large to send');
    }
    final reply = await client.completeJson(
      system: AiPrompts.screenshotSystem,
      user: 'Transcribe this screenshot.',
      images: [AiImage(bytes, mimeType: mimeType)],
      timeout: const Duration(seconds: 60),
    );
    await usage?.record(reply.usage);
    final text = reply.json['text'];
    return text is String ? text.trim() : '';
  }
}
