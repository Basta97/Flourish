# Getting started (developers)

## Requirements

- **Flutter** stable (SDK `^3.11.5` per `pubspec.yaml`)
- **Xcode** (macOS) for iOS simulator or device
- **Android Studio** or Android SDK for emulator or device
- **CocoaPods** for iOS (`pod install` in `ios/` when native deps change)

Check your environment:

```bash
flutter doctor -v
```

## Clone and run

```bash
git clone https://github.com/Basta97/Flourish.git
cd Flourish
flutter pub get
flutter run
```

Pick a device when prompted, or pass `-d <device-id>` (`flutter devices`).

Fonts are **bundled** under `assets/fonts/`; the app disables runtime Google Fonts fetching.

## Common commands

```bash
# Format (CI enforces this)
dart format .

# Static analysis
flutter analyze

# Tests
flutter test

# Integration test (use a dedicated simulator; adds QA data)
flutter test integration_test/finance_flow_test.dart -d <device-id>
```

## Code generation

Drift generates `lib/data/database/database.g.dart`. After editing tables or DAOs:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## iOS notes

```bash
cd ios && pod install && cd ..
flutter run -d <ios-simulator-id>
```

Share extension and some capabilities require opening `ios/Runner.xcworkspace` in Xcode for signing.

## Android notes

- Application ID: `com.flourish.app`
- **Debug** builds install without `key.properties`.
- **Release** builds require signing — see [Releases](RELEASE.md).

```bash
flutter build apk --debug
```

## IDE

Open the repo root in VS Code or Android Studio with the Flutter plugin. Generated files (`*.g.dart`) should not be hand-edited.

## Where to read next

- [Architecture](ARCHITECTURE.md)
- [Finance implementation](FINANCE_IMPLEMENTATION.md)
- [Releases](RELEASE.md)
