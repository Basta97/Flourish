# Flourish 1.2.0 — Google Play release readiness (Phase 2)

Date: 2026-10-22. This report builds on [PLAY_STORE_AUDIT.md](PLAY_STORE_AUDIT.md),
which covers Phase 0 (the audit) and Phase 1 (remediation).

Nothing has been committed, pushed, published or uploaded. The signing key was
not exported, replaced or regenerated. All device tests ran on a **read-only**
emulator session, so every change on the emulator was discarded when it shut
down.

## 1. Final recommendation

**NO-GO for production submission today. GO for an internal-testing upload
once the owner decisions below are made.**

The engineering work is done and verified. What remains is owner-only:

1. Choose the Play App Signing option.
2. Publish the privacy policy and set its URL in the app.
3. Supply the developer name and support email.
4. Fill in the Play Console declarations.
5. If the account is a personal one, run the 14-day closed test.

## 2. Verification results (actual runs)

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` (full suite) | **422 passed, 0 failed, 1 skipped**. The skip is deliberate: `release_config_test.dart` reports the privacy-policy URL as not yet set |
| Format (`dart format --set-exit-if-changed` on changed files) | Clean |
| `flutter build appbundle --release` | Built `app-release.aab` (65.0 MB). `jarsigner -verify` → "jar verified" |
| AAB signing certificate | SHA-256 `CF:04:E2:D3:…:0B:80:C3:CF`, the same as the v1.1.0 GitHub APKs |
| Release lint (`lintVitalRelease`) | "No issues found" |
| Merged manifest (release) | `allowBackup=false`, `fullBackupContent=@xml/backup_rules`, `dataExtractionRules=@xml/data_extraction_rules`, no `usesCleartextTraffic` |
| Permissions | INTERNET, USE_BIOMETRIC, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, plus plugin-added VIBRATE, USE_FINGERPRINT, ACCESS_NETWORK_STATE and a signature-level dynamic-receiver permission. No SMS, location, contacts, storage, AD_ID or QUERY_ALL_PACKAGES |
| Exported components | `MainActivity` (launcher, share target); `PaymentNotificationListener` (guarded by `BIND_NOTIFICATION_LISTENER_SERVICE`); AndroidX `ProfileInstallReceiver` (guarded by `DUMP`). All other components are `exported=false` |
| 16 KB page size (from the AAB) | Every **64-bit** library (`arm64-v8a`, `x86_64`) has `p_align` ≥ 0x4000. The 32-bit `armeabi-v7a` copies of `libpdfium`/`libsqlite3` use 0x1000; Play's rule covers 64-bit only |
| targetSdk / minSdk | 36 / 24 |
| versionCode / versionName | 10200 / 1.2.0 |

**First attempts that failed:**

- One `flutter build apk --release` failed while a `flutter test` run was using
  `build/` at the same time. The rerun on its own succeeded. Cause: likely the
  concurrent run, not confirmed.
- Two PDF tests timing out in earlier phases is fixed (test-only change, see
  the audit).

## 3. Signing compatibility

| Build | Application ID | versionCode | Certificate SHA-256 | Can update to Play build? |
|---|---|---|---|---|
| GitHub v1.0.0 (debuggable) | com.flourish.app | 2001 | `4feca506…e3c01c3b`, Android debug key | **No**. Verified on emulator: `INSTALL_FAILED_UPDATE_INCOMPATIBLE` |
| GitHub v1.1.0 armeabi-v7a | com.flourish.app | 1002 | `cf04e2d3…0b80c3cf` | Yes, if Play signs with this key |
| GitHub v1.1.0 arm64-v8a | com.flourish.app | 2002 | `cf04e2d3…0b80c3cf` | Yes, if Play signs with this key. **Verified on emulator:** the update installed in place and all data survived (schema 8 → 9 migration) |
| 1.2.0 (this repo) | com.flourish.app | 10200 | `cf04e2d3…0b80c3cf` | — |

About the release key:

- RSA 2048, SHA384withRSA, valid to 2054.
- Stored only at `~/.flourish-signing/flourish-release.jks`.
- `android/key.properties` uses it directly. **No separate upload key exists.**

**Can Play App Signing reuse it?** Yes. Play Console's "Use existing app
signing key" option accepts an RSA 2048-bit key, uploaded encrypted with
Google's PEPK tool. In that case, Play-delivered builds keep the
`cf04e2d3…` certificate, and v1.1.0 users update in place.

**Recommendation: Option A.**

1. Enroll with the **existing key as the app signing key**.
2. Create a **new upload key**.
3. Point `android/key.properties` at the upload key.
4. Keep offline backups of both keys.

Option B (Google-generated signing key) forces every GitHub user to
uninstall, which wipes their data unless they made an encrypted backup first.

Both options are **irreversible** for this package name and need your
explicit approval. I took no action.

## 4. Version management

- `pubspec.yaml` is now `1.2.0+10200`. That is above every distributed code
  (max 2002) and far below Play's ceiling of 2,100,000,000.
- The scheme is `major*10000 + minor*100 + patch`.
- Settings → About now shows the real version.
- `test/release_config_test.dart` enforces both: the version shown in
  Settings must match pubspec, and the versionCode must stay above 2002.
- **Stop publishing `--split-per-abi` GitHub APKs.** Flutter adds `abi×1000`
  to their codes (an arm64 build of 10200 would be 12200), which would jump
  ahead of Play's code. If GitHub builds continue, ship a universal APK with
  the same code.
- Nothing was tagged or released.

## 5. Backup security (changed in this phase)

| Item | Before | Now | Evidence |
|---|---|---|---|
| Seven daily automatic backups | Plain JSON in `app_flutter/backups/` | AES-256-GCM with a random 256-bit key in `flutter_secure_storage` (Android Keystore). Format `flourish-local` v1 | `lib/core/finance/backup_service.dart` (`sealLocal`, `openLocal`, `_sealLegacy`). On-device check with a debuggable build: the file starts `{"format":"flourish-local",…}` and holds no plain account or merchant names |
| Existing plain daily backups | — | Encrypted **in place** on the next backup. Each file is replaced only after its encrypted copy decrypts to identical text; stale `.tmp` files from interrupted 1.1 writes are removed | Unit test, plus an on-device test that planted a 1.1-style plain file and saw it converted |
| If the key can't be stored | — | No backup is written; old files stay untouched; nothing is ever written in plain text | `a backup is never written in plain text if the key cannot be kept` |
| Restore compatibility | — | History restore and Settings import read both the new format and plain 1.1 files. Tampered or foreign files are refused with a clear message | Unit tests; on-device restore from history succeeded |
| Export labels | "Export Data / Save your data as JSON" | "Export **unencrypted** backup / Plain JSON file: anyone who gets it can read it". It shows a warning with a **Use encrypted** button. Settings now also offers encrypted export and restore. CSV export says "Unencrypted" | Verified on emulator |
| Restore/reset left screens stale | Watched queries kept old rows until restart (pre-existing bug, found on device) | Drift is told every table changed | Regression tests fail without the fix; verified on device after reset |

Unchanged: the Android cloud-backup and device-transfer exclusions from Phase 1.

## 6. Privacy compliance

- **Privacy policy draft:** [privacy-policy.md](privacy-policy.md), rewritten
  against the final code. It covers:
  - encrypted daily backups;
  - labelled unencrypted exports;
  - the exact AI flows and consent;
  - automatic FX lookups, including that **transaction dates** of
    foreign-currency accounts go to Frankfurter;
  - ML Kit telemetry;
  - verified links to provider policies;
  - reset and uninstall behaviour.

  Placeholders remain for the effective date, developer name, support email
  and minimum age.
- **In-app link:** Settings → About → **Privacy policy** opens
  `AppConstants.privacyPolicyUrl` in the browser. It is **empty until you set
  it**; until then the tile says it could not open the policy (seen on
  device), and the release-config test reports it as skipped.
- **Data Safety worksheet:** [PLAY_DATA_SAFETY.md](PLAY_DATA_SAFETY.md). Each
  flow is mapped to Google's collection, sharing and exception rules.
  - Recommended (conservative): AI-bound data is **collected and shared**,
    optional.
  - FX/price lookups are **collected "Other financial info", required**.
  - ML Kit diagnostics and per-install ID are **collected, not shared**,
    optional.
  - "Ephemeral" is never claimed.

## 7. Store assets and listing

| Asset | Status | Location |
|---|---|---|
| 512×512 icon | **Ready**: 32-bit PNG from the same drawing as the launcher icon | `store/google-play/icon-512.png` |
| Adaptive icon | **Ready**: background, foreground and monochrome layers at 5 densities, `mipmap-anydpi-v26/ic_launcher.xml`. Seen on device in Android's settings screen and as a themed icon on the home screen | `android/app/src/main/res/mipmap-*/ic_launcher_*.png` |
| Feature graphic 1024×500 | **Ready** (24-bit PNG) | `store/google-play/feature-graphic-1024x500.png` |
| Phone screenshots | **Ready**: 7 images at 1080×2160, from the real 1.2.0 release build with invented demo data (`tool/store_demo_backup.dart`) | `store/google-play/screenshots/` |
| Short and full description (EN + AR) | **Drafted**, character counts checked | `store/google-play/listing.md` |
| Category | Finance | listing.md |
| Support contact | **Owner** | — |
| Tablet screenshots | Not prepared (optional) | — |

Regenerate the graphics with `python3 assets/icon/generate_store_assets.py`.
The 1024 master icon still renders pixel-identical after the generator was
split into reusable layers.

## 8. Device testing checklist

Executed on an Android 16 (API 36.1) arm64 emulator with the Play Store image,
in a read-only session:

| Test | Result |
|---|---|
| Fresh install of 1.2.0 | **Pass**: launches, no errors in logcat, adaptive and themed icon shown |
| Upgrade from GitHub v1.1.0 (real asset) | **Pass**: `adb install -r` succeeded (same certificate). Net worth and month totals identical after upgrade. `ALLOW_BACKUP` flag gone |
| Upgrade from GitHub v1.0.0 | **Blocked as expected** (debug signature). These users must back up and reinstall |
| Database persistence and migration | **Pass**: v1.1.0 schema 8 migrated to 9 on device without data loss |
| AI opt-in and revocation | **Pass**: a user who had "Use AI" on in 1.1.0 kept it, but automatic reading stayed **off**. The consent dialog names DeepSeek and api.deepseek.com. Decline keeps it off, Agree turns it on, the switch revokes without a dialog |
| Notification disclosure, permission and detection | **Pass**: the corrected disclosure shows before the system screen. Notification access was granted through Android's own dialog. A bank SMS sent into the emulator was read from the Messages notification, parsed (Carrefour Maadi, EGP 345.50, Food & Drinks) and put in the inbox |
| Redaction at capture | **Pass**: the full card number `4111 1111 1111 1111` was stored as `••••1111` |
| Cloud backup | **Pass**: `bmgr backupnow` → "Backup is not allowed" (a control package backed up fine) |
| Device-to-device transfer | **Pass**: the D2D transport measured 0 bytes and logged "Package com.flourish.app doesn't have any backup data" |
| Encrypted daily backup and restore | **Pass**: history restore decrypted with the Keystore key; files encrypted at rest (debug-build inspection) |
| Unencrypted export warning | **Pass** |
| Reset All Data | **Pass**: screens zero immediately, AI settings back to Off, no errors |
| Offline use | **Pass**: Wi-Fi and data off (ping unreachable); cold start and adding an expense worked |
| Tablet and landscape | **Works, not optimized**. On an 800 dp-wide display, Android 16 ignores the portrait lock. Layouts stretch full width without clipping; in landscape the floating nav bar covers the quick-action labels; the net-worth counter replays its count-up after rotation |
| Performance | **Inconclusive on an emulator.** First launch after install: 13.5–15.4 s. Later cold starts: 1.5–8.4 s while the host was busy building. Sideloaded installs are only "verify"-compiled |

**Still to verify on a physical phone** (ideally a low-end Android 7–9 device
and a current Pixel or Samsung). Install through the Play **internal testing**
track:

1. Install from Play over a real GitHub v1.1.0 install, which confirms Play
   App Signing keeps the certificate. Data must survive.
2. First-launch and cold-start time with a Play-installed (cloud-profiled)
   build.
3. Real bank SMS and real bank/wallet app notifications (CIB, NBE, Vodafone
   Cash, InstaPay, …) in Arabic and English.
4. AI with a **test** API key on a throwaway account: Ask AI, automatic
   reading after consent, and that the request text is masked. Use the
   provider's request log, or a proxy on a test network.
5. Encrypted export to Files or Drive, uninstall, reinstall, restore with the
   password.
6. Biometric app lock: enrol, lock, background, unlock, wrong attempts.
7. Home-screen widgets with app lock on: amounts must be hidden.
8. Payment reminders after reboot (`RECEIVE_BOOT_COMPLETED`).
9. Share text or an image from another app into Smart Import. Arabic
   screenshot with AI only after consent.
10. TalkBack pass over Home, Add transaction and Settings, plus 200% font
    size.
11. Tablet or foldable: landscape and multi-window.
12. Google Drive backup on a phone signed in to a Google account: Settings →
    Google → Backup must not list Flourish data.

## 9. Remaining items

### Owner blockers (P0, before production)

1. **Signing decision** (Option A or B, §3) and creation of an upload key.
   Irreversible; needs your approval.
2. **Publish the privacy policy** (fill its placeholders), then set
   `AppConstants.privacyPolicyUrl` (`lib/core/constants/app_constants.dart`).
3. **Developer name and support email:** in the policy, the listing and the
   Play account.
4. **Play Console forms:** Data Safety, financial features, ads (No), content
   rating, target audience 18+, app access.
5. **Closed test** (personal accounts created after 2023-11-13): 12+ testers
   for 14 days.

### Engineering (none blocks an internal-testing upload)

| Severity | Item | Where |
|---|---|---|
| P1 | Physical-device checks in §8 | — |
| P2 | Notification-access status doesn't refresh when returning from Android settings; it updates only after re-entering the screen | `lib/presentation/detection/detection_settings_screen.dart` |
| P2 | `main()` awaits recurring processing before the first frame; measure first launch on a real device | `lib/main.dart:31-37` |
| P2 | Large-screen layouts: no maximum content width; floating nav overlaps quick actions in landscape | Home, Ledger |
| P2 | Database not encrypted at rest (SQLCipher). Acceptable with Android sandbox + file-based encryption | `lib/data/database/database.dart` |
| P3 | Home content scrolls under a transparent status bar (text overlaps the clock) | Dashboard |
| P3 | Net-worth counter replays from 0 after rotation | `net_worth_hero.dart` |
| P3 | Temporary export copies stay in the cache until Reset or the OS clears it | `settings_screen.dart`, `finance_tools_view.dart` |
| P3 | `.github/workflows/release.yml` (untracked) uses `secrets` in step `if:`, which Actions rejects, and builds split APKs | `.github/` |
| Owner | No LICENSE file, but the README refers to one | repo root |

## 10. Play Console submission guide

1. **Account.** Create or confirm a Play Console developer account (one-time
   US$25), verify identity, set the public developer name and contact email.
2. **Create app.** Name "Flourish", default language English (add Arabic),
   App, Free. Accept the declarations.
3. **App integrity → App signing.** Choose "Use existing app signing key".
   Export it with Google's PEPK tool, then generate and register the upload
   key (§3). *Needs your approval; irreversible.*
4. **Build.** Update `android/key.properties` to the upload key, then:

   ```bash
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android-1.2.0
   ```

   Keep the symbols folder. Upload `build/app/outputs/bundle/release/app-release.aab`.
5. **Internal testing.** Create a release, upload the AAB, and add yourself
   and a few testers. Install from the opt-in link over a v1.1.0 install.
   Run §8 on physical phones. Read the pre-launch report.
6. **App content.**
   - Privacy policy URL.
   - App access: "All functionality available without special access".
   - Ads: No.
   - Content rating questionnaire.
   - Target audience: 18+.
   - Data safety, from PLAY_DATA_SAFETY.md.
   - Financial features declaration.
   - Government apps: No.
   - Health: No.
7. **Store listing.**
   - Name and descriptions (EN, AR) from `store/google-play/listing.md`.
   - Icon: `icon-512.png`.
   - Feature graphic.
   - 7 phone screenshots.
   - Category Finance, contact email.
8. **Closed testing** (if required): at least 12 testers opted in for 14
   consecutive days. Fix anything found; then apply for production access
   from the Dashboard.
9. **Production.** Staged rollout (for example 10% → 50% → 100%). Watch
   Android vitals (crashes, ANRs) and reviews; halt the rollout if needed.
10. **After launch.**
    - Point README and GitHub release notes to Play.
    - Tell v1.0.0 users to back up and reinstall.
    - Stop split-APK GitHub releases.
    - Tag `v1.2.0` only when you choose to.

## 11. Decisions that need your approval

1. **Play App Signing:** Option A (reuse `cf04e2…`, new upload key) vs.
   Option B. Irreversible.
2. **Exporting the release key** through PEPK for Option A. It leaves this
   machine once, encrypted for Google.
3. **Public URL, developer name and support email** for the policy and
   listing.
4. **Committing these changes** to `main`, and when to push or tag. Nothing
   has been committed.
