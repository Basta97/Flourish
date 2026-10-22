import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Financial data and API keys must never reach Google backups or a new
/// phone through device transfer. Android reads these files at install, so
/// they are checked as text here.
void main() {
  const res = 'android/app/src/main/res/xml';
  const domains = ['root', 'file', 'database', 'sharedpref', 'external'];

  test('the manifest turns backup off and names both rule files', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('Android 12+ excludes every domain from cloud and device transfer', () {
    final rules = File('$res/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$section>([\\s\\S]*?)</$section>',
      ).firstMatch(rules)!.group(1)!;
      expect(body, isNot(contains('<include')), reason: section);
      for (final domain in domains) {
        expect(
          body,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$section $domain',
        );
      }
    }
  });

  test('Android 11 and lower exclude every domain', () {
    final rules = File('$res/backup_rules.xml').readAsStringSync();
    expect(rules, isNot(contains('<include')));
    for (final domain in domains) {
      expect(rules, contains('<exclude domain="$domain" path="." />'));
    }
  });
}
