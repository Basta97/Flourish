# Releases

This document describes how to version Flourish, build signed Android artifacts, and publish a **GitHub Release**.

## Version numbers

Flutter reads the version from `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        │     └─ versionCode (Android integer, must increase every store/upload)
#        └────── versionName (human-readable semver)
```

For each release:

1. Bump **semver** when user-visible features or fixes warrant it (`1.0.1`, `1.1.0`, …).
2. Always **increment the build number** after `+` for Android (`+2`, `+3`, …).

Commit the version bump on `main` before tagging.

## Changelog

Maintain [CHANGELOG.md](../CHANGELOG.md) following [Keep a Changelog](https://keepachangelog.com/). Copy the relevant section into the GitHub Release notes.

## Android signing (required for release APK/AAB)

Release Gradle tasks **fail** if `android/key.properties` is missing (no debug fallback).

### 1. Create a keystore (once)

```bash
keytool -genkey -v \
  -keystore "$HOME/flourish-release.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias flourish
```

Store the keystore and passwords somewhere safe (password manager, offline backup). **Losing the keystore means you cannot update the same Play Store listing.**

### 2. Configure `key.properties`

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` (never commit this file):

```properties
storeFile=/absolute/path/to/flourish-release.jks
storePassword=your-keystore-password
keyAlias=flourish
keyPassword=your-key-password
```

Paths can be absolute, or relative to the `android/app` module (e.g. `storeFile=upload-keystore.jks` with the file in `android/app/`).

### 3. Build artifacts

```bash
flutter pub get
flutter test
flutter build apk --release
# Play Store:
flutter build appbundle --release
```

| Output | Path |
|--------|------|
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| App bundle | `build/app/outputs/bundle/release/app-release.aab` |

## GitHub Release (manual)

### Tag

Use an annotated tag matching the marketing version:

```bash
git tag -a v1.0.0 -m "Flourish 1.0.0"
git push origin v1.0.0
```

### Create release with GitHub CLI

```bash
gh release create v1.0.0 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "Flourish 1.0.0" \
  --notes-file CHANGELOG.md
```

Or use the GitHub web UI: **Releases → Draft a new release** → choose tag → attach `app-release.apk` → paste notes.

### What to include in release notes

- Summary of user-visible changes (from CHANGELOG).
- **Install:** Android 7+ (API 24+), enable install from unknown sources if sideloading.
- **Data:** Local-only; recommend encrypted backup before upgrading.
- Link to [docs/OVERVIEW.md](OVERVIEW.md) for feature overview.

## Automated release (optional)

Workflow templates live in [`docs/ci/release.yml`](ci/release.yml) (copy to `.github/workflows/release.yml` in the repo). On tags `v*`:

1. Runs `flutter test`
2. If Android signing secrets are configured, builds `app-release.apk` and attaches it to the GitHub Release

### Repository secrets

Set these under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of your `.jks` file: `base64 -i flourish-release.jks \| pbcopy` |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | e.g. `flourish` |
| `ANDROID_KEY_PASSWORD` | Key password |

If secrets are missing, the workflow still creates a **source-only** release (tag + notes) so you can upload an APK manually later.

## Google Play: version codes and signing (decision pending)

**Status:** recommendation only. Nothing has been enrolled, uploaded or
regenerated, and `pubspec.yaml` is unchanged.

### What has shipped so far (verified 2026-10-22)

Checked by downloading the GitHub release assets and comparing them with
`apksigner` / `aapt2` / `keytool` against the current release build:

| Build | Application ID | versionCode | Signing certificate (SHA-256) |
|---|---|---|---|
| v1.0.0 `app-arm64-v8a-debug.apk` | `com.flourish.app` | 2001 | `4feca506…e3c01c3b`: **Android debug key**, debuggable build |
| v1.1.0 `Flourish-1.1.0-armeabi-v7a.apk` | `com.flourish.app` | 1002 | `cf04e2d3…0b80c3cf`: `CN=Flourish, O=Basta97, C=EG` |
| v1.1.0 `Flourish-1.1.0-arm64-v8a.apk` | `com.flourish.app` | 2002 | `cf04e2d3…0b80c3cf` (same) |
| 1.2.0 AAB/APK built from this repo | `com.flourish.app` | 10200 | `cf04e2d3…0b80c3cf` (same) |

Full digest: `CF:04:E2:D3:81:00:45:C4:6E:60:87:50:34:AF:ED:3F:52:9A:B0:ED:81:79:42:9E:46:C3:6F:3C:0B:80:C3:CF`.

About the key:

- RSA 2048-bit; certificate signed with SHA384withRSA; valid until 2054.
- Lives only in `~/.flourish-signing/flourish-release.jks`.
- `android/key.properties` points at it (`keyAlias=flourish`). There is
  **no separate upload key** yet.

Emulator results (Android 16):

- Installing 1.2.0 over v1.1.0 **succeeded**, keeping all data (schema 8 → 9
  migration).
- Installing over v1.0.0 **failed** with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

### Recommended production versionCode

`pubspec.yaml` is now `version: 1.2.0+10200`. That is above every code
already distributed (max 2002), far below Play's limit of 2100000000, and
follows a scheme that keeps rising predictably
(`versionCode = major*10000 + minor*100 + patch`).
`test/release_config_test.dart` fails if it ever drops to 2002 or below, or
if the version shown in Settings drifts from pubspec.

Then `1.2.1` → `10201`, `1.3.0` → `10300`, and so on.

Stop publishing `--split-per-abi` APKs on GitHub after the Play launch.
Flutter adds `abi × 1000` to those codes, so they would leapfrog Play's code.
If GitHub builds continue, publish a universal APK with the same versionCode
as Play, signed with the same key.

### Play App Signing — the irreversible choice

Enrolling in Play App Signing fixes the app signing key for
`com.flourish.app`. **Owner approval is required.**

- **Option A (recommended): keep the existing key as the app signing key.**
  - In Play Console, choose "Use existing app signing key from Java keystore"
    and upload the key with Google's PEPK tool.
  - Then create a separate **upload key** and point `android/key.properties`
    at it.
  - Result: GitHub v1.1.0 users can install the Play version as an update,
    with their data intact.
  - Cost: the private key leaves this machine once, encrypted for Google.
- **Option B: let Google generate a new app signing key; use the existing key
  as the upload key.**
  - Result: GitHub users must uninstall before installing from Play, which
    **erases their local data**. They must make an encrypted backup first
    (Wealth → Tools → Export encrypted backup) and restore it afterwards.

Either way:

- Never delete or regenerate `~/.flourish-signing/flourish-release.jks`.
- Keep an offline copy of it and of the new upload key.

### Moving GitHub users to Play

1. Ship one more GitHub release note, before or at Play launch, that says
   "make an encrypted backup".
2. **Option A:** installing from Play updates the app in place. Settings and
   data stay.
3. **Option B (and anyone on v1.0.0):** export an encrypted backup,
   uninstall, install from Play, then restore.

The new Android backup rules (`android:allowBackup="false"`,
`res/xml/data_extraction_rules.xml`) mean reinstalling never restores data
from Google backup, so the encrypted file is the only way across.

### Verifying the backup rules on a device

`test/android_backup_rules_test.dart` checks the manifest and XML. Before a
Play release, also check on a device or emulator (Android 12+, signed in to a
Google account), using a release build with some test data:

```bash
adb shell bmgr enable true
adb shell bmgr backupnow com.flourish.app
adb shell dumpsys backup | grep -A3 com.flourish.app
```

Expected: the app is skipped or uploads no data. Then uninstall, reinstall
from the same build, and confirm the app starts empty: no restored ledger,
no API keys, no crash from secure storage. Device-to-device transfer can be
checked with the Android Setup "copy apps & data" flow on a spare device. No
Flourish data should arrive.

## iOS distribution

GitHub Releases are commonly used for **Android APKs**. iOS builds need Apple Developer signing:

- **TestFlight / App Store:** Archive in Xcode, upload with Transporter or Xcode Organizer.
- Attach an `.ipa` to a GitHub Release only for small internal tester groups (not typical).

## CI on every push

CI template: [`docs/ci/flutter.yml`](ci/flutter.yml) → `.github/workflows/flutter.yml` runs format, analyze, and tests on pull requests and pushes to `main`.

**Note:** Pushing workflow files requires a Git credential with the **`workflow`** OAuth scope (or SSH). If push is rejected, add the workflow via the GitHub web editor or update your token scopes.
