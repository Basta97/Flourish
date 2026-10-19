import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final label = Platform.environment['FLOURISH_QA_LABEL'] ?? 'phone';
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('docs/verification/images/$name-$label.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      await File('docs/verification/search-$label-results.json').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({...?data}..remove('screenshots')),
      );
    },
  );
}
