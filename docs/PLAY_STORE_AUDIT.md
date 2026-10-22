# Flourish — Google Play Release Readiness Audit

Audit date: 2026-10-21 · Commit audited: `9228ec8` (main) · Scope: Android / Google Play.
This is an audit only. No source, configuration or dependency files were changed.

**How to read this report**

- **Verified** means checked against code, a build artifact, a command run during this audit, or an official Google page fetched today.
- **Assumption** means a judgement or policy reading that could not be confirmed directly.
- Line references are `path:line` at the audited commit.

Commands run (approved by the owner; they wrote only to git-ignored `.dart_tool/` and `build/`):

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **397 passed, 2 failed**. Both failures are 30 s timeouts in `test/finance/import/pdf_statement_test.dart` ("text PDF fixture (pdfium)" group). These tests call `pdfrxInitialize`, which fetches a desktop PDFium binary on the host. Most likely an environment or network issue, not an app defect: **UNKNOWN until rerun with network**. |
| `flutter build appbundle --release` | **Succeeded**: `build/app/outputs/bundle/release/app-release.aab`, 64.7 MB, signed (`jarsigner -verify` → "jar verified"). A first attempt with `--no-pub` failed because a stale `GeneratedPluginRegistrant.java` from an integration-test run still referenced `integration_test`. Always build without `--no-pub`, or run `flutter pub get` first. |
| Inspection of the existing `build/app/outputs/flutter-apk/app-release.apk` (built 2026-10-19 16:09, *before* HEAD) with `aapt2`, `zipalign -P 16`, `llvm-readelf`, `apksigner` | Results in §A |

> **Phase 2 (final release preparation) results:**
> [PLAY_RELEASE_READINESS.md](PLAY_RELEASE_READINESS.md). It has the current
> blockers, signing and versioning, assets, device tests and the GO/NO-GO
> decision. It supersedes the "Still open" list below.

## Phase 1 remediation status (2026-10-22)

Changes are made in the working tree; nothing has been committed, pushed or uploaded.

| Finding | Status | Where |
|---|---|---|
| Automatic AI on captured alerts without specific consent | **Fixed.** A separate "Read unclear alerts automatically" consent, off by default, recorded per provider host, revocable; older settings never grant it | `lib/core/ai/ai_config.dart`, `lib/core/detection/detection_service.dart`, `lib/presentation/settings/ai_settings_screen.dart`, `screenshot_ai_disclosure.dart` (`confirmAutomaticAi`) |
| Redaction could be off on the automatic path | **Fixed.** Automatic requests are always masked | `ai_payment_assist.dart` (`forceRedact`) |
| Smart Import sent *all* pending unclear alerts (found during remediation) | **Fixed.** Only the pasted messages are sent | `notification_import_screen.dart` |
| "Nothing leaves your phone" disclosure | **Fixed** (EN + AR) | `lib/l10n/app_en.arb`, `app_ar.arb` (`readAlertsBody`), `PaymentNotificationListener.kt` comment |
| Android Auto Backup / device transfer of plaintext data and keys | **Fixed.** `allowBackup="false"` plus every domain excluded for cloud backup and device transfer (API 31+) and full backup (API 30 and lower) | `AndroidManifest.xml`, `res/xml/data_extraction_rules.xml`, `res/xml/backup_rules.xml` |
| Incomplete Reset all data | **Fixed.** Clears DB (incl. detected alerts, AI cache, search index; then VACUUM), receipts, auto-backups, temp export copies, picked-file cache, native queue, API keys, finance/AI prefs | `lib/core/finance/data_reset_service.dart`, `settings_screen.dart` |
| No privacy policy | **Drafted, not published** | `docs/privacy-policy.md` |
| Data safety answers | **Worksheet drafted, not submitted** | `docs/PLAY_DATA_SAFETY.md` |
| versionCode / signing | **Recommendation documented; owner decision pending** | `docs/RELEASE.md` § Google Play |
| PDF test timeouts | **Fixed (test-only).** `flutter test` does not hand PDFium to the test runner, and pdfrx hangs instead of failing; tests now point pdfrx at the host build | `test/finance/import/pdf_statement_test.dart` |

Verification:

- `flutter analyze`: clean.
- `flutter test`: **414 passed, 0 failed**. 15 tests are new:
  - `test/ai/ai_consent_test.dart`
  - consent group in `test/ai/ai_payment_assist_test.dart`
  - `test/finance/data_reset_test.dart`
  - `test/android_backup_rules_test.dart`
- `flutter build appbundle --release`: built and signed (64.8 MB).
  - Release lint vital: "No issues found".
  - The merged manifest contains the three backup attributes.

Still open:

- plaintext automatic backups on the device (P1; now kept out of cloud backup);
- plaintext JSON export label (P1);
- adaptive icon (P1);
- large-screen check (P1);
- README / LICENSE (P1);
- store assets and Play Console forms (P0);
- signing decision (P0).

---

## Executive Summary

**Overall readiness:** Flourish is technically close to publishable. It targets API 36, its native libraries are 16 KB-aligned, it has a release-signing setup and a clean static analysis, and it needs no backend. It is **not ready to submit as-is**. The blockers are compliance and privacy items, not engineering ones:

1. **No privacy policy exists** anywhere (repo, app, or hosted). Play requires one for this app, and the Data safety form needs a URL.
2. **The in-app disclosure for notification reading is inaccurate.** It says "nothing leaves your phone" (`lib/l10n/app_en.arb`, key `readAlertsBody`). When AI assist is on, low-confidence bank alerts are sent automatically to a third-party AI provider (`lib/core/detection/detection_service.dart:433-445`). Under the User Data policy this is a prominent-disclosure defect.
3. **Plaintext financial data goes into Android cloud backup.** `allowBackup` is not set (default `true`) and there are no `dataExtractionRules` (`android/app/src/main/AndroidManifest.xml:6-9`). As a result these files are backed up to the user's Google account:
   - the unencrypted SQLite DB (`app_flutter/flourish.db`);
   - 7 days of **plaintext** JSON backups (`app_flutter/backups/`);
   - the raw notification queue (`files/detection/queue.jsonl`);
   - the `flutter_secure_storage` prefs file. Its Keystore keys are not backed up, which causes known "Failed to unwrap key" failures after a restore.
4. **versionCode collision with already-distributed APKs.** The v1.1.0 GitHub split APKs carry versionCodes **1002 / 2002** (Flutter's `abi*1000 + 2`). `pubspec.yaml` is at `+2`. A Play build must use a versionCode above 2002, and must be signed with the same key, or sideloaded users cannot update.

**Can Flourish be published now?** No. It can be ready with a small, well-defined set of changes (below). None needs a server.

**Main security and privacy risks:**

- The database is not encrypted at rest; only the OS sandbox protects it.
- Plaintext auto-backups are kept on the device.
- "Reset all data" leaves backups, detected-message text, attachments and API keys behind.
- With AI on, bank SMS text and statements are sent to user-chosen AI providers. Free tiers may retain or train on prompts. Screenshots are sent unmasked, which is disclosed.
- The redaction toggle can be turned off for paid providers.

**Estimated cost:** US$25 one-time for the Play developer registration (Assumption: the long-standing fee; confirm at sign-up). **US$0/month** for infrastructure. AI and market-data costs fall on users' own keys or free endpoints.

**Remaining work (scope):**

- About 6 P0 items: privacy policy, disclosure text, backup rules, versionCode/signing decision, Data safety + financial-features declarations, store assets.
- About 8 P1 items: reset completeness, plaintext backups, key-handling, adaptive icon, closed testing, and more.
- Every P0 item is a configuration, text or documentation change, plus one small code change for the backup rules.

**Final verdict:** **NOT READY — BLOCKERS IDENTIFIED** (details at the end).

---

## Readiness Scorecard

| Area | Status | Severity | Evidence | Required Action |
|---|---|---|---|---|
| Flutter/Android configuration | PASS | — | Flutter 3.41.7 / Dart 3.11.5; AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, Java 17 (`android/settings.gradle.kts:22-23`, `gradle-wrapper.properties:5`, `app/build.gradle.kts:23-31`). Built APK: `targetSdkVersion 36`, `minSdk 24`; all `.so` LOAD segments ≥ 0x4000 (16 KB OK); `flutter analyze` clean | Remove the leftover `TODO` comment (`app/build.gradle.kts:34`); optional |
| Release signing | WARN | P0 | `key.properties` + keystore outside the repo, git-ignored, release task fails without it (`app/build.gradle.kts:11-16`). APK signed v2 only (fine for minSdk 24). GitHub APKs are versionCode 1002/2002 | Decide on Play App Signing key strategy (§B.3); set versionCode > 2002 |
| Google Play policies | FAIL | P0 | No privacy policy; inaccurate disclosure for notification reading; financial-features declaration and Data safety not prepared | §P0 items 1–2, 5 |
| Local database security | WARN | P1 | Plain SQLite via `sqlite3_flutter_libs` (`database.dart:1007-1016`); app lock is UI-only; Auto Backup on | Add backup rules (P0); consider SQLCipher (P3) |
| AI privacy | WARN | P0/P1 | Opt-in (`ai_config.dart:88`), redaction forced for free tiers (`ai_config.dart:117`). But automatic sending after opt-in, the "nothing leaves your phone" text, and the redaction toggle off for paid/custom | Fix disclosure; tighten redaction (P1) |
| API-key management | PASS/WARN | P1 | Keys in `flutter_secure_storage` (`ai_settings_screen.dart:62-67`, `finance_tools_view.dart:232`); never logged. But: secure-storage prefs are included in Auto Backup; reset doesn't delete keys; Alpha Vantage key goes in a URL query (provider requirement) | Exclude from backup; delete on reset |
| Backup and restore | WARN | P0/P1 | Real implementation exists (`backup_service.dart`), with AES-256-GCM + PBKDF2 and a transactional, validated restore with tests. But auto-backups are plaintext, and a plaintext export option exists | Encrypt or exclude local backups; label the plaintext export |
| External API reliability | PASS | P2 | All calls HTTPS, timeouts 15–60 s, failures swallowed so the app works offline (`market_data_service.dart`, `finance_runtime.dart:100-104`) | Document free-tier limits |
| App quality | WARN | P2 | 397/399 tests pass; analyze clean; migrations tested (`test/finance/migration_backup_test.dart`). Portrait lock is ignored on large screens at API 36; no global error handler | §P2 |
| Store listing assets | FAIL | P0 | Only a 1024² launcher PNG (`assets/icon/app_icon.png`, RGB without alpha), no adaptive icon, no feature graphic, no store screenshots, no descriptions, no support email/site | §H |

---

## Phase A — Project Architecture (verified)

| # | Item | Finding | Evidence |
|---|---|---|---|
| 1 | Flutter / Dart | Flutter 3.41.7 stable, Dart 3.11.5; constraint `sdk: ^3.11.5` | `flutter --version`, `pubspec.yaml:6-7` |
| 2 | AGP / Gradle / Kotlin / Java | AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20, Java/JVM 17, core library desugaring on | `android/settings.gradle.kts:22-23`, `android/gradle/wrapper/gradle-wrapper.properties:5`, `android/app/build.gradle.kts:23-31` |
| 3 | SDK levels | `minSdk = max(flutter, 24)` = 24; `targetSdk = flutter.targetSdkVersion` = **36**; `compileSdk = max(flutter, 36)` = 36 | `app/build.gradle.kts:20,40-41`; Flutter's `FlutterExtension.kt:23-34`; confirmed in the built APK by `aapt2` |
| 4 | Package / application ID | `com.flourish.app` (namespace and applicationId). A `-PflourishQa=true` variant yields `com.flourish.app.qa` | `app/build.gradle.kts:19,36-37` |
| 5 | Display name | "Flourish" | `AndroidManifest.xml:7` |
| 6 | Version | `1.1.0+2` in pubspec. The existing local release APK reports versionCode **4** (built with an override). GitHub v1.1.0 split APKs: **1002** (armeabi-v7a) and **2002** (arm64-v8a) | `pubspec.yaml:4`; `aapt2 dump badging`; `FlutterPlugin.kt:621-623`; `gh release view v1.1.0` |
| 7 | ABIs / Android versions | arm64-v8a, armeabi-v7a, x86_64; Android 7.0+ (API 24) | APK `native-code` |
| 8 | Dependencies | 30 direct runtime deps, all on current major lines (e.g. drift 2.28.2, flutter_secure_storage 10.3.4, local_auth 3.0.2, http 1.6.0, pdfrx 2.4.7). `flutter pub get` reports "92 packages have newer versions incompatible with dependency constraints", mostly transitive or platform. No known-vulnerable package was identified, but **no advisory scan was run** (UNKNOWN) | `pubspec.lock`; `flutter analyze` output |
| 9 | Runtime permissions | Declared: INTERNET, USE_BIOMETRIC, POST_NOTIFICATIONS (runtime on 13+), RECEIVE_BOOT_COMPLETED. Merged from plugins: VIBRATE, USE_FINGERPRINT, ACCESS_NETWORK_STATE, `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. **No SMS, contacts, location, storage, exact alarm, AD_ID or QUERY_ALL_PACKAGES** | `AndroidManifest.xml:2-5`; APK `uses-permission` list |
| 10 | Network | Optional only. Core ledger works offline. See Phase F | — |
| 11 | Tests | 52 unit/widget test files (~8.7k lines), 3 integration tests, 1 Kotlin unit test (`PreFilterTest.kt`) | `test/`, `integration_test/`, `android/app/src/test` |
| 12 | Native integrations | `NotificationListenerService` for payment detection; 2 home-screen widgets; ACTION_SEND share target (text/image); ML Kit Text Recognition (Play services, unbundled); method channels `flourish/widgets`, `flourish/imports`, detection channel | `android/app/src/main/kotlin/com/flourish/app/**` |
| 13 | AAB buildable | **Yes.** A signed release AAB (64.7 MB) was built from HEAD during this audit. It carries versionCode 2 from pubspec, which must be raised (§B.3) | `flutter build appbundle --release` |

Additional facts:

- R8 minify and resource shrinking are on by default for Flutter release builds (`FlutterPlugin.kt:258-267`). No custom ProGuard rules are present; release-mode ML Kit and secure-storage behaviour depends on the plugins' consumer rules (Assumption: OK, since the 1.1.0 release APK shipped).
- The release CI template (`.github/workflows/release.yml`, untracked) uses `if: ${{ secrets.X != '' }}`. GitHub Actions does not allow the `secrets` context in step `if:`, so this workflow will error (P3).

---

## Phase B — Google Play Publishing Requirements

### B.1 Policy facts verified today (official Google pages)

| Policy | Requirement | Flourish |
|---|---|---|
| Target API ([answer/11926878](https://support.google.com/googleplay/android-developer/answer/11926878)) | New apps and updates must target **API 36** since 2026-08-31 (extension to 2026-11-01 possible) | **PASS**: targetSdk 36 |
| 16 KB page size ([developer.android.com/guide/practices/page-sizes](https://developer.android.com/guide/practices/page-sizes)) | Required for apps targeting 15+; updates blocked from 2027-02-01 if non-compliant | **PASS**: every `.so` has `p_align` ≥ 0x4000; zipalign `-P 16` OK |
| AAB | New apps must be published as AAB (long-standing Play rule; Assumption, not re-fetched) | **PASS**: signed AAB built |
| Testing for new personal accounts ([answer/14151465](https://support.google.com/googleplay/android-developer/answer/14151465)) | Personal accounts created after 2023-11-13: closed test with **≥ 12 testers opted in for 14 consecutive days** before applying for production | Plan for it (§Submission checklist) |
| Financial features declaration ([answer/13849271](https://support.google.com/googleplay/android-developer/answer/13849271)) | **Mandatory for almost all apps**, including on testing tracks | Not done; see B.4 |
| Data safety ([answer/10787469](https://support.google.com/googleplay/android-developer/answer/10787469)) | "Collect" means transmitting off device; on-device-only processing is out of scope. Sharing exceptions exist for service providers, user-initiated action or consent with prominent disclosure, legal and anonymous data | Matrix in Phase D |
| ML Kit data disclosure ([developers.google.com/ml-kit/android-data-disclosure](https://developers.google.com/ml-kit/android-data-disclosure)) | ML Kit sends device info, app package/version, per-installation identifiers, and usage/diagnostic metrics to Google over HTTPS | Must be reflected in Data safety |

### B.2 Manifest and release configuration

| Check | Status | Evidence / note |
|---|---|---|
| Cleartext traffic | PASS | No `usesCleartextTraffic` or network-security-config, so cleartext is blocked by default at targetSdk ≥ 28. Every hard-coded endpoint is `https`. A user-entered *custom* AI base URL using `http://` will simply fail; acceptable |
| Exported components | PASS | `MainActivity` exported (launcher + SEND, required). `PaymentNotificationListener` exported but guarded by `BIND_NOTIFICATION_LISTENER_SERVICE` (`AndroidManifest.xml:59-67`). Widget and notification receivers `exported="false"` |
| Debug-only features | PASS | No `kDebugMode` gates or driver extension in `lib/`; `debugShowCheckedModeBanner: false` (`lib/app.dart:49`). `debugPrint` stays active in release and logs exception text to logcat (`main.dart:36`, `finance_runtime.dart:58,101`, `detection_runtime.dart:37-115`). Messages are errors, not financial rows (P2) |
| Auto Backup | **FAIL** | No `android:allowBackup`, `fullBackupContent` or `dataExtractionRules` (`AndroidManifest.xml:6-9`). See Phase C |
| Package visibility | PASS | `<queries>` for LAUNCHER intents and PROCESS_TEXT only; no `QUERY_ALL_PACKAGES` (`AndroidManifest.xml:83-94`) |
| Orientation | WARN | Portrait lock (`main.dart:27`). At targetSdk 36, Android 16 ignores orientation and resizability restrictions on large screens (sw ≥ 600 dp). Tablets and foldables will get landscape and resizable windows (Assumption based on Android 16 behaviour changes; test it) |

### B.3 Play App Signing and the upload key

- **Verified:** a release keystore exists outside the repo (`~/.flourish-signing/`, mode `0600`). `android/key.properties` is git-ignored (`android/.gitignore:12`, `.gitignore`). No keystore, `key.properties` or `.env` file appears anywhere in git history. Contents were not read.
- **Decision required (P0):** GitHub users already run APKs signed with this key, with versionCode 1002/2002.
  - **Option A (recommended for continuity):** in Play Console, choose "Use a key from a Java keystore" and upload the existing key via PEPK as the **app signing key**. Then generate a **new upload key**. Play builds will then install as updates over sideloaded builds, provided versionCode is above 2002.
  - **Option B:** let Google generate the app signing key and use the existing key as the upload key. Sideloaded users must uninstall first, which **loses their local data** unless they make an encrypted backup. Communicate this.
- Either way, set the Play versionCode above **2002**, for example `1.2.0+3000`. After that, stop publishing split APKs to GitHub, or keep their versionCodes below the Play ones.

### B.4 Declarations

| Declaration | Recommended answer | Basis |
|---|---|---|
| Financial features | Flourish does not move money, lend, trade, or hold funds. Choose the option closest to **personal finance management / budgeting**; if none fits, choose "Other" and describe it as "on-device budgeting and expense tracking; no money transfers, no lending, no investment execution". *Assumption:* the help page does not name budgeting apps explicitly | `answer/13849271` |
| Ads | **No ads.** No ad SDK; no `AD_ID` permission in the merged manifest | APK permission list |
| Advertising ID | "Does not use advertising ID" | same |
| Account deletion | **Not applicable**: the app has no account creation or sign-in | No auth/backend in `lib/` |
| Target audience | **18+** (finance app reading bank alerts). Avoid "children" groups, which would trigger Families policy | Assumption |
| Content rating (IARC) | No violence, sexual content, gambling, user-to-user communication or location sharing. Expect the lowest rating (e.g. Everyone / PEGI 3). Answer "no" to unrestricted internet browsing | Assumption |
| AI-generated content policy | **Low applicability.** AI output is never shown as free-form generated content; it is parsed into validated fields (amount must appear in the source text, `ai_payment_assist.dart:229-241`) plus short category names. No chat or image generation. *Assumption:* Play's AI-generated content rules target generative apps; still describe the AI feature in the listing | Code |
| Notification access | No Play permission-declaration form exists for `BIND_NOTIFICATION_LISTENER_SERVICE`. Reading SMS and bank alerts is **personal and sensitive data** under the User Data policy, so the in-app disclosure must be accurate, shown before the system setting, and must cover the AI path. Expect reviewer scrutiny; prepare a short video of the consent flow | Assumption (policy reading) |
| Personal vs organization account | Personal works, but brings the 12-tester / 14-day closed test and shows your legal name and address to users. An organization account requires a D-U-N-S number and skips the testing requirement. No regulated financial services, so an org account is not required (Assumption) | `answer/14151465` |

---

## Phase C — Database and Local Storage Security

| Question | Finding | Evidence |
|---|---|---|
| DB location | `getApplicationDocumentsDirectory()/flourish.db` → on Android `/data/data/com.flourish.app/app_flutter/flourish.db`. A legacy `bastasaving.db` is renamed on first open; its `-wal`/`-shm` sidecars are not renamed (low risk; WAL checkpointed on close) | `lib/data/database/database.dart:1007-1016` |
| Encrypted at rest? | **No.** Plain SQLite (`sqlite3_flutter_libs`), WAL mode. Protection = Android app sandbox + file-based encryption of the device. App lock (`local_auth`) gates the UI only | `database.dart:155-158`, `lib/core/auth/authentication_coordinator.dart` |
| Plaintext sensitive data | Yes: balances, transactions, merchants, card last-4, receipt images (documents dir), detected-payment raw message text (`detected_payments.raw_text`, retention controlled by `detection_raw_text_days`), AI cache, native detection queue `files/detection/queue.jsonl` (raw notification text, ≤ 1000 lines). *(Correction 2026-10-22: `RecentAlerts` stores only SHA-256 hashes of alerts, not their text.)* | `DetectionQueue.kt:14-39`, `RecentAlerts.kt:7-11` |
| Encryption keys | Only for encrypted backups. The key is derived per export from the user's password (PBKDF2-HMAC-SHA256, 210k iterations, 16-byte random salt) and never stored | `backup_service.dart:301-343` |
| API credentials | `flutter_secure_storage` 10.x (Android Keystore-backed): `ai_api_key`, `alpha_vantage_key`. Non-secret AI settings in SharedPreferences | `ai_config.dart:98`, `finance_providers.dart:64,75` |
| Logging | No financial rows logged. Native listener logs only exception class names (`PaymentNotificationListener.kt:27,107`). Dart `debugPrint` logs exception messages in release (P2) | grep of `lib/` |
| Migration safety | Schema v9. Upgrade steps are guarded (`_hasTable`, `_addColumnIfMissing`), `repairLegacyData` is idempotent, and every upgrade path from v1→v9 has tests. A pre-restore automatic backup is taken before imports. **Remaining risk:** the v5 rebuild (`_migrateToV5`) is not wrapped in a transaction (noted as H in `docs/AUDIT.md`), but only affects users still on schema < 5 (pre-public builds) | `database.dart:74-160`, `test/finance/migration_backup_test.dart` |
| Update data loss | Low for in-place updates with the same package and signature. **High** if Play signing uses a new key for sideloaded users (§B.3) | — |
| Uninstall | Deletes all app-private data (DB, auto-backups, queue). Only files the user shared or exported survive. Cloud Auto Backup copies remain in the user's Google account and are restored on reinstall | Android behaviour |
| Android Auto Backup | **Enabled by default** (no `allowBackup`). Includes `app_flutter/` (DB + plaintext `backups/*.json` + receipts), `files/detection/`, all SharedPreferences, including `FlutterSecureStorage` prefs whose Keystore keys do *not* migrate. Google encrypts Auto Backup client-side when a screen lock is set (Android 9+). It is still an un-disclosed second copy, and restoring the secure-storage prefs onto a new device causes `InvalidKeyException: Failed to unwrap key` (documented in `flutter_secure_storage` README §"Disabling Auto Backup") | `AndroidManifest.xml:6-9`; `~/.pub-cache/.../flutter_secure_storage-10.3.4/README.md:124-136` |
| Backup/restore tested? | In-app restore: yes, unit-tested (round trip, rollback on bad references, v6→v7). Android Auto Backup / device-to-device transfer: **not tested** (UNKNOWN) | `test/finance/migration_backup_test.dart` |
| Should files be excluded? | Yes. Recommended: add `android:dataExtractionRules` (API 31+) and `android:fullBackupContent` (API ≤ 30) that **exclude** `sharedpref/FlutterSecureStorage.xml`, `file/detection/`, and `app_flutter/backups/`. Either exclude the DB too and rely on the encrypted in-app backup (simplest, most private), or keep the DB in cloud backup and disclose it | — |

**"Reset all data" is incomplete (P1).** `lib/presentation/settings/settings_screen.dart:806-817` deletes ledger tables and preferences. It does **not** delete:

- `detected_payments` (raw bank message text);
- `app_flutter/backups/*.json` (up to 7 full plaintext copies);
- receipt image files;
- the native detection queue;
- API keys.

Despite the warning "cannot be undone", all data stays recoverable on the device.

---

## Phase D — AI Integration and Privacy

### D.1 What can leave the device, when, and to whom

The provider is whichever one the user configured: DeepSeek, OpenRouter, Groq, Gemini, or a custom OpenAI-compatible URL (`ai_config.dart:32-78`). AI is **off by default** (`ai_config.dart:88`) and needs a user-supplied key.

| Flow | Trigger | Data sent | Redaction | Evidence |
|---|---|---|---|---|
| Payment assist on ingest | **Automatic** after AI is enabled: every captured alert whose local confidence is below the threshold (default 0.75), or with no amount | Message text (after `redact()`), today's date, and the **full list of category names/ids** | Always: card PANs (Luhn), Egyptian national IDs, OTPs, EG mobile numbers (`detection/redact.dart`). Plus `Redactor` (emails, IBANs, phones, ≥ 6-digit numbers) **only if** the "Hide personal data" toggle is on. The toggle is forced on for free presets but **can be turned off for DeepSeek and Custom** | `detection_service.dart:433-445`, `ai_payment_assist.dart:128-201`, `ai_config.dart:117` |
| "Ask AI" on pending inbox items | User tap | Same as above, batches of 15 | Same | `detection_service.dart:450-478` |
| Screenshot reading | User tap after a one-time consent dialog | **Raw image, unmasked** (names, account numbers, balances visible) | None possible. The dialog says so clearly | `ai_screenshot_reader.dart`, `screenshot_ai_disclosure.dart`, `notification_import_screen.dart:137-146` |
| PDF statement reading | User action when local parsing finds nothing | Page text minus lines starting with name/address labels, then `Redactor` (always) | Always on, but counterparty names and descriptions are sent | `ai_statement_reader.dart:28-50` |
| Spreadsheet column mapping | User action | Header row + 5 sample rows, each cell `Redactor`-masked (header not masked) | Always on | `ai_column_mapper.dart:44-57` |
| Model list / test connection | User tap | API key only | — | `ai_client.dart:260-304` |

### D.2 Answers to the specific questions

1. **What leaves the device:** bank and wallet alert text, statement text, spreadsheet samples, category names, and screenshots (images). Never the database, balances in bulk, or backups.
2. **Providers:** only the one configured. Gemini uses the native `generateContent` endpoint (`ai_client.dart:63,190`); the others use `/chat/completions`.
3. **Only after explicit action?** **No** for the payment-assist path. After a one-time opt-in, it runs automatically for each low-confidence alert. The opt-in subtitle explains this ("Only messages it cannot read confidently are sent to the AI"). Other flows are per-action.
4. **Redaction before every request?** Detection `redact()` runs on every payment-assist request. `Redactor` always runs for statements and columns. Payment assist depends on the toggle. Screenshots: none.
5. **Bypassable?** Yes, by turning the toggle off for non-free presets. Redaction is regex-based, so personal names, addresses without labels, and non-EG phone formats pass through. The statement reader drops only lines that *start* with a label.
6. **Screenshots with sensitive data?** Yes, disclosed to the user before enabling.
7. **Unnecessary data?** The **full category list** is sent with every payment request. It is low sensitivity but reveals spending structure. The `X-Title: Flourish` header is harmless.
8. **API keys encrypted at rest?** Yes (Keystore-backed secure storage), but the prefs file is included in Auto Backup (Phase C).
9. **Keys in logs or errors?** Not found. Errors carry the provider's message only (`ai_client.dart:306-360`). AI exceptions in detection are swallowed (`detection_service.dart:443`). The Alpha Vantage key is in the URL query string (provider design); `http.ClientException` messages can include the URI, and market errors are caught silently (`market_data_service.dart`, `catch (_)`), so no logging was found.
10. **HTTPS / certificate validation:** `package:http` default client uses platform TLS validation; no `badCertificateCallback` or overrides anywhere. Cleartext is blocked by Android at target 36. No certificate pinning (not needed).
11. **User informed?** Partly. The AI settings and screenshot dialog are good. The **notification-access disclosure contradicts the AI path** ("nothing leaves your phone"), and there is no privacy policy. **P0.**
12. **Can AI failure corrupt data?** No. Answers are validated (amount must appear in text, date bounds, category id must exist, `ai_payment_assist.dart:205-312`). Failures keep the on-device reading. Results are cached so a message is never re-sent or re-billed.

### D.3 Proposed Data safety matrix (draft for Play Console)

Defaults: no data is sold; no ads; all transmission is HTTPS; no account; users can delete everything in-app (after the reset fix); everything off-device is optional.

| Data type (Play category) | Collected? | Shared? | Optional? | Purpose | Notes |
|---|---|---|---|---|---|
| Financial info → *Purchase history*, *Other financial info* | **Yes**, when AI assist / statement / column AI is used | Declare **No**, relying on the "user-initiated action / prominent disclosure and consent" exception. *Conservative alternative:* declare **Yes, shared** with AI providers | Yes | App functionality | Transactions sent to the AI provider the user chose with their own key. Do **not** claim "processed ephemerally": provider retention is outside your control (free tiers may train on prompts) |
| Messages → *SMS or MMS*, *Other in-app messages* | **Yes**, when AI assist is on (bank SMS / app alert text) | As above | Yes | App functionality | Captured via notification access; stored on device; sent only when AI is on |
| Photos and videos → *Photos* | **Yes**, when "Read Arabic screenshots with AI" is used | As above | Yes | App functionality | Unmasked image |
| Personal info → *Name*, *Other info* | Possibly (names visible in screenshots, counterparties in alerts and statements) | As above | Yes | App functionality | Declare to be safe |
| App info and performance → *Diagnostics*; Device or other IDs | **Yes**: ML Kit Text Recognition (Google) sends usage/diagnostic metrics, device info and per-install identifiers | No (Google is the SDK provider) | **No**: happens whenever OCR runs | Analytics / app functionality | Per ML Kit disclosure page |
| Financial info → *Other* (investment tickers) | Arguably: holding symbols to Alpha Vantage / Coinbase, currency codes to Frankfurter | No | Yes | App functionality | Low risk; no user identifier is sent beyond the user's own Alpha Vantage key and IP. *Assumption:* declare under "Other financial info" if you want to be conservative |
| Everything else in the ledger | **No**: never leaves the device except by user-initiated export or share | — | — | — | Local-only processing is out of scope |

Security practices section: "Data is encrypted in transit: **Yes**". "Users can request data deletion: describe the in-app *Reset all data*", which must first be made complete (P1). Do **not** tick "Independent security review".

---

## Phase E — Backup Investigation

| Question | Answer (verified) |
|---|---|
| Exists in app or only README? | **Exists.** `lib/core/finance/backup_service.dart`; UI in Wealth → Tools (`finance_tools_view.dart:565-670`) and Settings (`settings_screen.dart:521-590`) |
| Type | Three mechanisms: (1) **automatic local snapshots**, plaintext JSON, one per day, last 7 kept, in `app_flutter/backups/`, written after every change and on resume (`backup_service.dart:270-299`, `finance_runtime.dart:55,95`); (2) **encrypted export** shared via the system share sheet (`.encrypted.json`); (3) **plaintext export** ("Export Data — Save your data as JSON", `settings_screen.dart:521-537`). Android Auto Backup applies implicitly because it was never configured. **No Google Drive integration** |
| Where files go | Local: app-private documents dir. Exports: written to the cache dir, then wherever the user sends them through the share sheet. Cache temp copies are not deleted after sharing (low risk; cache is not backed up) |
| Encryption correct? | AES-256-GCM (authenticated), random 16-byte salt, nonce from `cryptography`, PBKDF2-HMAC-SHA256 **210,000** iterations, password ≥ 10 chars. Sound. Below current OWASP guidance (600k for PBKDF2-SHA256), and the iteration count is not stored in the file, so it cannot be raised later without a format version bump. Pure-Dart PBKDF2 may take several seconds on low-end phones (UNKNOWN, not measured) |
| Restore works / integrity | Yes. Validates format and version, rejects newer schemas, whitelists columns via `PRAGMA table_info`, runs in one transaction with FK check, value validation, and a search-index rebuild; rolls back attachment files on failure; takes an automatic backup first. Covered by tests |
| API keys included? | **No.** Only listed preferences (`backup_service.dart:34-48`). Raw message text is excluded unless opted in |
| Play-policy compatible? | Yes. User-initiated exports are fine. Plaintext local snapshots and implicit cloud backup must be disclosed or fixed (Phase C) |
| Changing phones | **Supported path:** encrypted export → move file → restore. **Implicit path:** Android Auto Backup / device transfer will likely restore the DB and plaintext backups, but **API keys will break** (secure storage) and behaviour is untested |

**Unsupported or inaccurate documentation claims:**

- `README.md` "Installing a release: Download `app-release.apk`". The latest release ships `Flourish-1.1.0-arm64-v8a.apk` / `-armeabi-v7a.apk` (verified via `gh release view`).
- `README.md` "Application code: see repository license". **No LICENSE file exists** in the repo.
- `README.md` "encrypted backup optional". True, but the app *also* keeps unencrypted daily backups automatically, which is not mentioned.
- `readAlertsBody` string: "nothing leaves your phone". False when AI assist is on.
- `PaymentNotificationListener.kt:13-17` comment: "nothing leaves the device". The same caveat applies.
- `docs/RELEASE.md` "Automated release (optional)". The workflow's `secrets` in `if:` is invalid (P3).
- `docs/AUDIT.md` notes that `docs/PLATFORMS.md:30` claims deep links that don't exist. Still present (not re-verified in detail).

---

## Phase F — API and Network Dependencies

| Provider | Endpoint | Auth | Sent → received | Required? | Limits / cost | Failure / offline | Privacy |
|---|---|---|---|---|---|---|---|
| Frankfurter | `api.frankfurter.dev/v2/rates`, `/v2/currencies` | None | base + quote currency codes (+ date) → ECB reference rates | Optional (FX for multi-currency) | Free, no key; no published hard limit (Assumption) | 15 s timeout; cached rates kept; manual FX overrides | Currency codes + IP |
| Gold API | `api.gold-api.com/price/XAU` | None | — → USD spot | Optional (gold holdings) | Free (Assumption) | Errors swallowed; cached price kept | IP only |
| Coinbase | `api.coinbase.com/v2/prices/{SYM}-USD/spot` | None | crypto symbol → spot | Optional | Public endpoint, free (Assumption) | Same | Ticker + IP |
| Alpha Vantage | `www.alphavantage.co/query` (`GLOBAL_QUOTE`, `SYMBOL_SEARCH`) | User's key in query string | ticker → quote | Optional (non-EGX stocks) | Free tier ≈ 25 req/day, enforced locally (`market_data_service.dart:93-99`) | Throws "allowance reached"; cached kept | Ticker + key + IP |
| DeepSeek | `api.deepseek.com/chat/completions` | Bearer (user key) | see Phase D | Optional | Paid per token (user's account) | 25 s timeout, 1 retry on 429/5xx; falls back to on-device | Third-party processing |
| OpenRouter | `openrouter.ai/api/v1/chat/completions` | Bearer | same | Optional | `:free` models rate-limited; free tier may log prompts | same | Redaction forced |
| Groq | `api.groq.com/openai/v1/chat/completions` | Bearer | same (text only) | Optional | Free tier, rate-limited | same | Redaction forced |
| Google Gemini | `generativelanguage.googleapis.com/v1beta/models/{m}:generateContent` | `x-goog-api-key` | same + images | Optional | Free tier (Google may use free-tier data to improve products); paid tier otherwise | same | Redaction forced; images unmasked |
| Custom | any user URL + `/chat/completions` | Bearer | same | Optional | — | same; `http://` blocked by Android | User's responsibility |
| Google Play services ML Kit | Google (SDK-internal) | — | OCR runs on device; telemetry to Google; model downloaded via Play services (`AndroidManifest.xml:11-13`) | Needed for screenshot OCR | Free | If Play services missing, OCR fails gracefully (`MainActivity.kt:41-44`) | See Data safety |
| Google Fonts | none: runtime fetching disabled, fonts bundled (`main.dart:19`, `pubspec.yaml` assets) | — | — | — | — | — | — |

No owned backend. No analytics, crash-reporting or ad SDKs.

---

## Phase G — App Quality and Testing

| Area | Finding | Severity |
|---|---|---|
| Startup | `main()` awaits `RecurringService.processDue()` **before** `runApp` (`main.dart:31-37`). With many due rules this delays the first frame. DB opens on a background isolate (`createInBackground`) | P2 |
| Navigation / deep links | go_router; Android has no deep-link intent filters (only SEND/MAIN). Widget actions go through a method channel | OK |
| State management | Riverpod 2.6, DB injected once at root (`database_provider.dart`) | OK |
| Error handling | Errors caught per subsystem and shown in snackbars. **No `FlutterError.onError` / `PlatformDispatcher.onError`**: uncaught async errors only reach logcat. No crash reporting (privacy-friendly; rely on Play Console vitals) | P2 |
| Offline | Ledger, budgets, detection and reports fully local; network features degrade silently | OK |
| Money precision | Exact `Decimal` (`lib/domain/finance/amount.dart`) with exact balances in `exact_balances` (TEXT). The legacy `transactions.amount` / `accounts.balance` columns are still `REAL` (`tables/transactions_table.dart:12`, `accounts_table.dart:8`). `docs/AUDIT.md` lists earlier rounding issues and their fix status | P2 (monitor) |
| Migrations | Tested from every historical schema to v9 | OK |
| Time zones | Dates stored as local DateTime; FX lookups use UTC day bounds (`fx_policy.dart:13-14`); reminders scheduled as absolute UTC instants (`reminder_service.dart:140`). No DST-specific tests found | P3 |
| Permission denial | Notification access is optional (system settings); POST_NOTIFICATIONS failure is logged and ignored (`detection_runtime.dart:37`); biometric lock checks `isDeviceSupported` | OK |
| Import/export | CSV, XLSX, OFX, QIF, PDF + presets; well tested. 2 PDFium host tests timed out in this run (environment) | P3 |
| Crash risks | Shared image copied from a content URI with no size cap (`MainActivity.kt:80-86`); AI screenshot path caps at 6 MB | P3 |
| Low-end devices | Fat APK ≈ 94 MB (three ABIs). AAB delivery reduces this per device. PBKDF2 210k in pure Dart is unmeasured | P2 |
| Accessibility | ~50 explicit `Semantics` / `semanticsLabel` / `tooltip` usages; a large-text layout test exists (`test/widgets/large_text_layout_test.dart`). No TalkBack audit done (UNKNOWN) | P2 |
| Responsiveness | Portrait-locked, but at API 36 large screens ignore the lock. Landscape and tablet layouts are untested | P2 |
| Release mode | The 1.1.0 release APK (R8 + obfuscation) shipped. The integration tests cover finance, search and usability flows | OK |
| Screen privacy | No `FLAG_SECURE`; balances visible in the recent-apps thumbnail even with app lock on. Home widgets **do** hide amounts when lock is on (`home_widget_runtime.dart:61,104`) | P3 |

**Missing critical tests:**

- `BackupService.encrypt/decrypt` wrong-password and tamper cases (only a round trip exists).
- Reset-all-data completeness.
- Auto Backup rules: a manifest assertion test.
- A test that the notification-disclosure copy matches the AI state.
- Redactor coverage for non-Egyptian phone formats and names.

---

## Phase H — Store Listing and Release Assets

| Asset | Status | Note |
|---|---|---|
| App icon (512×512, 32-bit PNG) | **Missing**; source exists | `assets/icon/app_icon.png` is 1024² RGB (no alpha) and can be exported |
| Adaptive icon | **Missing** | No `mipmap-anydpi-v26/ic_launcher.xml`; legacy PNG mipmaps only. Android 8+ launchers will show it boxed or masked |
| App name | Exists: "Flourish" | Check trademark collisions on Play ("Flourish" is a common name) |
| Short / full description | Missing | Drafts below |
| Phone screenshots (2–8) | Missing (store-grade) | `docs/verification/android_*.png` are QA captures; reuse after cleanup |
| Feature graphic 1024×500 | Missing | — |
| Privacy policy URL | **Missing (P0)** | Host free on GitHub Pages |
| Support email | Missing | A dedicated address is recommended over a personal one |
| Developer info / website | Missing | Optional website; GitHub repo link acceptable |
| Category | Not set | **Finance** |
| Content rating | Not done | IARC questionnaire |
| Target audience | Not done | 18+ |
| Financial features | Not done | §B.4 |
| Data safety | Not done | §D.3 |

**Suggested short description (≤ 80 chars):**

> Private, on-device budget & expense tracker with bank-alert detection.

**Suggested full description (draft):**

> Flourish is a private, local-first money manager. Your accounts, transactions, budgets and goals are stored only on your phone — no sign-up, no ads, no cloud account.
>
> • Track multiple accounts and currencies, with live reference exchange rates
> • Budgets, savings goals and recurring payments
> • Credit cards: limits, statements, minimum due and interest estimates
> • Payment detection: turn bank SMS and wallet alerts (English & Arabic) into a review inbox — you approve every entry
> • Import CSV, Excel, OFX, QIF and PDF statements
> • Wealth: holdings, gold, crypto and loans in one net-worth view
> • Encrypted backups you control, plus biometric app lock
> • Home-screen widgets and quick add
>
> Optional AI assistant: bring your own key for Google Gemini, DeepSeek, Groq or OpenRouter to read alerts and statements Flourish can't read on its own. It is off by default; when on, the text you choose (or unclear alerts) is sent directly to the provider you picked, with account numbers masked.
>
> Flourish is a tracking tool. It does not move money, give financial advice or connect to your bank.

---

## Phase I — Costs and Infrastructure

| Item | Mandatory? | Cost | Verified / estimate |
|---|---|---|---|
| Google Play developer registration | Yes | **US$25 one-time** | Long-standing fee; confirm at sign-up (not re-fetched today) |
| Backend / database hosting | **No** | $0 | Verified: no backend code |
| AI APIs | No | $0 to developer (user keys) | Verified: keys are user-supplied |
| FX / market data | No | $0 (Frankfurter, Gold API, Coinbase public; Alpha Vantage user key) | Pricing pages not re-checked (estimate) |
| Privacy policy hosting | Yes (policy needed) | $0 (GitHub Pages) | Estimate |
| Domain | No | ~US$10–15/yr if wanted | Estimate |
| Support email | Yes | $0 (free mailbox) | Estimate |
| D-U-N-S (org account only) | No | Free | Assumption |
| Apple (iOS) | Out of scope | US$99/yr | — |

**Zero monthly infrastructure: Yes.**

---

## Critical Blockers (P0)

1. **No privacy policy.** Write and host one covering on-device storage; AI providers (what is sent, automatic vs on-tap, provider retention); ML Kit telemetry; market-data endpoints; Android backup; deletion via uninstall / reset; no ads or analytics; contact email. Link it in-app (Settings → Privacy) and in Play Console.
2. **Inaccurate prominent disclosure for notification access** (`readAlertsBody` in `lib/l10n/app_en.arb` and `app_ar.arb`; consent screen in `lib/presentation/detection/detection_settings_screen.dart`). The copy must state that when AI assist is on, unclear alerts are sent (masked) to the chosen provider. Also make enabling AI show a consent dialog that names the provider and says it runs automatically, like the existing screenshot dialog.
3. **Android backup configuration.** Add `dataExtractionRules` + `fullBackupContent` (or `allowBackup="false"`) to `AndroidManifest.xml`. At minimum exclude secure-storage prefs, the detection queue and plaintext auto-backups. Decide whether the DB is cloud-backed and disclose it.
4. **versionCode and signing strategy** (§B.3). Choose Option A or B, document it in `docs/RELEASE.md`, and set `version:` to a versionCode > 2002.
5. **Play Console declarations.** Data safety (§D.3), financial features, ads (no), content rating, target audience 18+, app access (no login needed).
6. **Store assets.** 512² icon, feature graphic, ≥ 2 phone screenshots, descriptions, support email.

## High Priority (P1)

1. Make **Reset all data** wipe `detected_payments`, `app_flutter/backups/`, attachment files and the native queue, and optionally the AI and Alpha Vantage keys (`settings_screen.dart:~800-820`).
2. **Plaintext automatic backups.** Encrypt them with a device Keystore key, or move them to `noBackupFilesDir` and say so in the UI (`backup_service.dart:279-299`).
3. Label the **plaintext "Export Data"** clearly as unencrypted, or route it through the encrypted export (`settings_screen.dart:521-537`).
4. **Redaction for paid/custom providers.** Keep `Redactor` always on for automatic payment assist; allow the opt-out only for manual "Ask AI" (`ai_config.dart:117`, `ai_payment_assist.dart:196-201`).
5. Add an **adaptive icon** (`mipmap-anydpi-v26`, foreground + background layers).
6. **Closed testing:** recruit ≥ 12 testers for 14 days (if using a personal account).
7. **Large-screen behaviour at API 36:** test landscape and tablet layouts, or verify the portrait lock is honoured.
8. Fix README claims (APK name, LICENSE) and add a LICENSE file.

## Medium Priority (P2)

- Move `RecurringService.processDue()` out of `main()` before `runApp`.
- Add `FlutterError.onError` / `PlatformDispatcher.instance.onError` handlers that log without data.
- Strip or guard `debugPrint` of exception text in release.
- Stop sending the full category list on every AI request; send only same-type categories, or cap it.
- Raise PBKDF2 iterations (store `iterations` in the file header with a version bump) and measure on a low-end device.
- Run a TalkBack and accessibility pass.
- Rerun the two PDFium tests with network to confirm they are environmental.

## Optional Improvements (P3)

- SQLCipher (`sqlcipher_flutter_libs`) with a Keystore-held key.
- `FLAG_SECURE` when app lock is on.
- A size cap on shared images.
- Fix the GitHub release workflow (`secrets` in `if:`) and switch it to `flutter build appbundle`.
- Remove the stray `TODO` in `build.gradle.kts`.
- Rename the `-wal`/`-shm` sidecars in the legacy DB migration.
- Add DST and time-zone tests.

---

## Implementation Roadmap

| # | Task | Priority | Files | Depends on | Acceptance criteria | Verify |
|---|---|---|---|---|---|---|
| 1 | Decide app-signing option (A/B); bump version to e.g. `1.2.0+3000` | P0 | `pubspec.yaml`, `docs/RELEASE.md` | — | versionCode > 2002; decision documented | `aapt2 dump badging` on the AAB-derived APK |
| 2 | Backup rules | P0 | `android/app/src/main/AndroidManifest.xml`, new `res/xml/data_extraction_rules.xml`, `res/xml/backup_rules.xml` | — | secure-storage prefs, `detection/`, `backups/` excluded | `adb shell bmgr backupnow com.flourish.app`, then inspect with `adb shell bmgr` / restore on a second device; keys still work |
| 3 | Correct the notification-access disclosure + AI consent dialog | P0 | `lib/l10n/app_en.arb`, `app_ar.arb`, `detection_settings_screen.dart`, `ai_settings_screen.dart` | — | Copy mentions the AI path when enabled; enabling AI requires explicit "Agree" | Widget test asserting dialog and copy |
| 4 | Privacy policy page + in-app link | P0 | new `docs/privacy-policy.md` (GitHub Pages), `settings_screen.dart` | 3 | Public URL reachable; linked in app | Open the link on a device |
| 5 | Store assets | P0 | new `store/` or `fastlane/metadata/android/` | — | Icon 512², feature graphic, ≥ 4 screenshots, EN (+AR) text | Play Console preview |
| 6 | Complete "Reset all data" | P1 | `settings_screen.dart` | — | After reset: no rows in `detected_payments`, empty `backups/`, no attachments, no queue, keys removed | New widget/integration test |
| 7 | Encrypt or relocate auto-backups; label the plaintext export | P1 | `backup_service.dart`, `finance_tools_view.dart`, `settings_screen.dart` | 2 | No plaintext financial JSON in backed-up dirs | `run-as com.flourish.app ls` on a debug build |
| 8 | Redaction always on for automatic AI | P1 | `ai_config.dart`, `ai_payment_assist.dart`, `ai_settings_screen.dart` | — | `outgoing()` masks on the auto path regardless of the toggle | Unit test |
| 9 | Adaptive icon | P1 | `android/app/src/main/res/mipmap-anydpi-v26/` | 5 | Icon renders in circle and squircle masks | Pixel launcher check |
| 10 | Large-screen check | P1 | `main.dart`, layouts | — | No broken layouts in landscape or on tablets | Emulator, tablet/foldable profile |
| 11 | README / LICENSE fixes | P1 | `README.md`, new `LICENSE` | — | Claims match reality | Review |
| 12 | Startup + global error handlers + log hygiene | P2 | `main.dart`, `finance_runtime.dart`, `detection_runtime.dart` | — | First frame before recurring processing; no exception text in release logcat | `adb logcat` on a release build |
| 13 | Missing tests (encrypt wrong password/tamper, reset, disclosure) | P2 | `test/…` | 3, 6 | Tests green | `flutter test` |
| 14 | Build signed AAB, upload to internal testing | P0 gate | — | 1–5 | Play accepts the bundle; pre-launch report clean | Play Console |

---

## Google Play Submission Checklist

1. Register a developer account (personal or organization), pay US$25, and complete identity verification. Org accounts need a D-U-N-S number.
2. Create the app: name "Flourish", default language English (add Arabic), type App, Free.
3. **App signing:** enroll in Play App Signing using Option A or B (§B.3). Keep the upload key backed up offline.
4. Build: `flutter build appbundle --release`, with versionCode > 2002. Keep `--split-debug-info` symbols and upload the native debug symbols / R8 mapping.
5. **Internal testing:** upload the AAB, add yourself, and install from Play. Check notification access, widgets, biometric lock, backup/restore, and AI with a test key.
6. Fill in App content: privacy policy URL, app access (no login), ads = No, content rating (IARC), target audience 18+, Data safety (§D.3), financial features declaration, government apps = No, health = No.
7. Store listing: icon, feature graphic, screenshots, short and full descriptions (EN/AR), category Finance, contact email.
8. **Closed testing** (personal accounts created after 2023-11-13): ≥ 12 testers opted in for 14 consecutive days. Fix the pre-launch report findings during this period.
9. Apply for production access from the Dashboard (answer the questions about testing).
10. Production: staged rollout (e.g. 10% → 50% → 100%); watch Android vitals (ANR/crash) and reviews.
11. After launch: update README "Installing a release" to point to Play; stop or segregate GitHub APK versionCodes.

---

## Final Verdict

**NOT READY — BLOCKERS IDENTIFIED**

The engineering foundation is publishable:

- target API 36;
- 16 KB-aligned native libraries;
- release signing outside git;
- no cleartext;
- no ads or trackers;
- clean `flutter analyze`;
- 397/399 tests passing, with the 2 failures likely environmental;
- zero-cost architecture.

Publishing is blocked by:

- the absence of a privacy policy;
- a notification-access disclosure that is false when AI is enabled (`readAlertsBody` vs `detection_service.dart:433-445`);
- unconfigured Android Auto Backup that copies plaintext financial data and breaks secure-storage keys (`AndroidManifest.xml:6-9`);
- a versionCode / signing-key decision needed for existing sideloaded users (GitHub APKs at 1002/2002);
- the missing Play Console declarations and store assets.

All are small, well-scoped changes. None requires a backend.
