# Platforms (Android & iOS)

Flourish uses a **single Flutter UI** on both platforms. There are no separate Android/iOS screen implementations in Dart; differences are system chrome, transitions, and native entry points for import.

## Shared UI

- `MaterialApp` with custom theme (`lib/core/theme/`)
- Island bottom navigation (`ScaffoldWithNavBar` in `app_router.dart`)
- iOS-style pull-to-refresh (`CupertinoSliverRefreshControl`) and bouncing scroll physics on **both** platforms
- Bundled **Manrope** and **Space Grotesk** fonts (no runtime font download)

## Intentional platform differences

| Behavior | Android | iOS |
|----------|---------|-----|
| Push route animation | Material fade-forward | Cupertino slide |
| System insets | Status + gesture/nav bar | Status + home indicator |
| Tap feedback | Material ink ripple (more visible) | Same theme, subtler feel |

## Android

- **Package:** `com.flourish.app`
- **Import:** `ACTION_SEND` for `text/plain` and `image/*` opens the app for review (OCR via ML Kit for images).
- **Permissions:** Internet (feeds), biometrics, notifications, boot completed (scheduled reminders).
- **Release signing:** `android/key.properties` — see [RELEASE.md](RELEASE.md).

## iOS

- **Share extension:** `ios/FlourishShareExtension/` forwards shared text into the main app via app group storage (`SharedImportStore.swift`).
- **Shortcuts / scene:** `FlourishShortcuts.swift`, `SceneDelegate.swift` handle lifecycle and deep links.
- **Face ID:** Usage string in `Info.plist` for app lock.
- **Pods:** `ios/Podfile` / `Podfile.lock` — run `pod install` after dependency changes.

## Parity checklist for QA

When verifying a build on both platforms:

1. Home net worth card, month stats, island nav, and add sheet from each tab
2. Ledger filters and transaction swipe actions
3. Wealth tabs: Holdings, Obligations, Reports, Tools
4. Settings: theme, backup/restore, reporting currency
5. Import path: share text (Android intent vs iOS share sheet)
6. Device auth lock (biometric / passcode)

Screenshots for manual regression live in [verification/](verification/).
