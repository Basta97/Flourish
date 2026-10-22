import 'dart:io';

import 'package:flourish/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Values a Play release depends on that live outside the build system.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec)!;

  test('Settings shows the pubspec version', () {
    expect(AppConstants.version, version.group(1));
  });

  test('versionCode is above every APK already on GitHub (2002)', () {
    expect(int.parse(version.group(2)!), greaterThan(2002));
  });

  test(
    'the privacy policy link is a public https URL',
    () {
      final url = Uri.parse(AppConstants.privacyPolicyUrl);
      expect(url.scheme, 'https');
      expect(url.host, isNot(contains('example')));
    },
    skip: AppConstants.privacyPolicyUrl.isEmpty
        ? 'OWNER: set AppConstants.privacyPolicyUrl before the Play release'
        : false,
  );
}
