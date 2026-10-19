# Usability and home screen widgets — verification

Date: 2026-10-19. Acceptance criteria: the approved usability/templates/authentication/detection/widgets plan.

## Evidence

- **STATIC CHECKS PASSED:** `flutter analyze --no-pub`; `git diff --check`.
- **UNIT TESTED / DATABASE TESTED:** 224 focused Flutter tests passed across detection, authentication, widget snapshots/runtime, template persistence, ledger/backup behavior, navigation, and layout. Template tests reopen a file-backed SQLite database, then edit/delete the recorded transaction after deleting its template; exact balances and monthly reporting remain correct. Backup tests cover legacy single amounts and three-preset templates.
- **NATIVE UNIT TESTED:** two Android `PreFilterTest` cases passed, covering LE/L.E/L.E., case variants, adjacent amounts, Arabic digits, OTPs, and unrelated word fragments. Command: `JAVA_HOME='<Android Studio JBR>' android/gradlew -p android :app:testDebugUnitTest --tests com.flourish.app.detect.PreFilterTest --offline`.
- **INTEGRATION TESTED:** `integration_test/usability_flow_test.dart` passed on Android 16 (`emulator-5554`) and the iPhone simulator (`FA9F58BF-5D66-4F39-8C81-C170C04BAB3D`). The production UI creates a three-preset template through Home → Tools, applies/reviews/adjusts it, records a normal transaction, edits it, checks exact balances in real SQLite, visits Tools through Settings, checks the three Wealth tabs, and selects a preset through the Add menu without recording another transaction.
- **BUILD PASSED:** Android debug APK. iOS simulator app with the embedded WidgetKit extension, including ad-hoc signing and the existing App Group entitlement. The widget extension derives its version/build from Flutter's generated configuration.
- **ANDROID WIDGET PATH EXERCISED:** installed Monthly summary on the launcher, inspected empty and recorded states, launched Add transaction from the widget, saved an EGP 85.50 expense, and observed the refreshed widget/native snapshot. Relaunching through the widget after closing the background app process reached the transaction form.
- **iOS SHARED STORAGE CHECKED:** the signed simulator app published a valid widget snapshot to the App Group preferences used by the extension. The URL scheme is registered; opening a URL through `simctl` reached the OS “Open in Flourish?” confirmation, so this does not establish an end-to-end iPhone widget tap.
- **PRIVACY / AUTHENTICATION AUTOMATED CHECKS:** snapshot and runtime tests confirm that enabling app lock or Hide amounts removes previously public totals. Controlled authentication tests exercise overlapping requests, prompt-induced lifecycle events, cancellation, explicit retry, passcode fallback configuration, and subsequent genuine background/resume.

## Reproduction commands

```sh
flutter analyze --no-pub
flutter test --no-pub test/detection test/auth test/home_widgets \
  test/finance/templates_test.dart test/finance/migration_backup_test.dart \
  test/finance/ledger_test.dart test/widgets/home_layout_test.dart \
  test/widgets/large_text_layout_test.dart test/widgets/island_nav_test.dart \
  test/architecture_test.dart
flutter test --no-pub integration_test/usability_flow_test.dart -d emulator-5554
flutter test --no-pub integration_test/usability_flow_test.dart \
  -d FA9F58BF-5D66-4F39-8C81-C170C04BAB3D
flutter build apk --debug --no-pub
flutter build ios --simulator --debug --config-only --no-pub
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'id=FA9F58BF-5D66-4F39-8C81-C170C04BAB3D' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

The simulator destination build avoids a generic multi-architecture Flutter packaging failure encountered with the installed Xcode/Flutter toolchain. Integration runs use disposable development simulator/emulator state and add uniquely named QA accounts/templates; they are not intended for a personal device/database.

## Checks still requiring devices/manual interaction

- Real Android biometric success/failure/lockout and device-credential fallback, plus Face ID/Touch ID regression checks. Controlled lifecycle tests do not reproduce a physical sensor's reported flicker.
- Live bank notification/SMS delivery and iPhone Messages/Wallet Shortcuts handoff. LE already passed the existing parser and native filter; changes add regression coverage and explicit LE automation guidance.
- iPhone widget gallery placement, rendered widget states, and taps through authentication on a device. Simulator UI control was unavailable in the computer-use tool.
- Native widget rendering across Arabic/RTL, system appearance, resizing, and actual OS-scheduled month rollover. Shared reporting-period calculations and Flutter Arabic/large-text layouts are covered automatically; native scheduling remains subject to OS timing.
