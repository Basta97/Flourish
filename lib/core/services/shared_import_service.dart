import 'package:flutter/services.dart';
import 'package:flourish/core/models/shared_import_draft.dart';

class SharedImportService {
  SharedImportService._();

  static const MethodChannel _channel = MethodChannel('flourish/imports');

  static Future<String> recognizeImage(String path) async =>
      await _channel.invokeMethod<String>('recognizeImage', path) ?? '';

  static Future<SharedImportDraft?> consumePendingImport() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'consumePendingImport',
    );
    if (raw == null || raw.isEmpty) return null;
    return SharedImportDraft.fromMap(raw);
  }
}
