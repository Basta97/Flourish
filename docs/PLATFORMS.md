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
- **Import:** `ACTION_SEND` for `text/plain` and `image/*` opens the app for review (OCR via ML Kit for images; Latin script only).
- **Payment detection:** `detect/PaymentNotificationListener.kt` is a `NotificationListenerService`. Once the person turns detection on and grants notification access (Settings › Payment detection › Grant), it reads the newest message of notifications from messaging apps (Google/Samsung/AOSP Messages, where bank SMS arrive) and from the bank or wallet apps the person ticks. A pre-filter keeps only text with an amount and currency and never stores one-time codes. Messages wait in `filesDir/detection/queue.jsonl` until the app moves them into the inbox (`flourish/detection` channel); in the background one summary notification opens the inbox.
  - No `READ_SMS` / `RECEIVE_SMS`: Google Play reserves them for default SMS apps, and the listener also covers bank-app push alerts.
  - On Android 13+ a sideloaded APK must first allow restricted settings (App info › ⋮ › Allow restricted settings) before notification access can be granted.
  - Some manufacturers (Xiaomi, Huawei, Samsung) stop background services aggressively; exempt Flourish from battery optimisation if alerts are missed. Muted SMS threads post no notification and cannot be read.
- **Permissions:** Internet (feeds), biometrics, notifications, boot completed (scheduled reminders); notification-listener access is granted in system settings.
- **Release signing:** `android/key.properties` — see [RELEASE.md](RELEASE.md).

## iOS

- **Share extension:** `ios/FlourishShareExtension/` forwards shared text and images (Vision OCR, Arabic where supported) into the main app via app group storage (`SharedImportStore.swift`).
- **Payment detection:** iOS does not let apps read SMS or notifications, so Shortcuts hands them over. `FlourishShortcuts.swift` provides *Import Transaction Text* (for a Messages automation: "Message contains EGP / جنيه / ج.م", Run Immediately) and *Log Card Payment* (for a Wallet "Transaction" automation, Apple Pay only). Both run without opening the app, append to a JSON-lines queue in the app group container (`SharedImportStore`, coordinated writes), and post a notification that opens the inbox. *Open Payments to Review* opens the inbox.
- **Scene:** `SceneDelegate.swift` serves the `flourish/imports` (share drafts, OCR) and `flourish/detection` (queue peek/ack, pending route) channels. There are no URL-scheme deep links.
- **Face ID:** Usage string in `Info.plist` for app lock.
- **Pods:** `ios/Podfile` / `Podfile.lock` — run `pod install` after dependency changes.

## Parity checklist for QA

When verifying a build on both platforms:

1. Home net worth card, month stats, island nav, and add sheet from each tab
2. Ledger filters and transaction swipe actions
3. Wealth tabs: Holdings, Obligations, Reports, Tools
4. Settings: theme, backup/restore, reporting currency
5. Import path: share text (Android intent vs iOS share sheet)
6. Payment detection: Android notification access + a real bank SMS and bank-app alert in English and Arabic; iOS Messages and Wallet automations; notification tap opens the inbox; confirm, edit, dismiss
7. Cards & wallets, credit card panel (limit, minimum due), foreign-currency purchase with FX fee
8. Device auth lock (biometric / passcode)

Screenshots for manual regression live in [verification/](verification/).
