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

## iOS distribution

GitHub Releases are commonly used for **Android APKs**. iOS builds need Apple Developer signing:

- **TestFlight / App Store:** Archive in Xcode, upload with Transporter or Xcode Organizer.
- Attach an `.ipa` to a GitHub Release only for small internal tester groups (not typical).

## CI on every push

CI template: [`docs/ci/flutter.yml`](ci/flutter.yml) → `.github/workflows/flutter.yml` runs format, analyze, and tests on pull requests and pushes to `main`.

**Note:** Pushing workflow files requires a Git credential with the **`workflow`** OAuth scope (or SSH). If push is rejected, add the workflow via the GitHub web editor or update your token scopes.
