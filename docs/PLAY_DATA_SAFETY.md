# Google Play Data Safety — worksheet

> **Draft for the owner. Nothing has been submitted.** Checked against the
> code for 1.2.0 (`1.2.0+10200`) on 2026-10-22, and against Google's Data
> safety help page (support.google.com/googleplay/android-developer/answer/10787469,
> fetched 2026-10-21). Re-check against the exact build you upload.

## 1. How Google's definitions apply to Flourish

**Collected** means transmitted off the device by the app, including straight
to a third party. Two kinds of handling are out of scope:

- data processed only on the device;
- data transmitted with end-to-end encryption that the developer can't read.

Flourish having no backend does **not** make it "no data collected": its AI
and market-data requests leave the device.

**Shared** means transferred to a third party. The exceptions are:

| Exception | Covers |
|---|---|
| (a) Service providers acting on the developer's behalf | — |
| (b) Legal | — |
| (c) A specific user-initiated action where the user expects the transfer, or a prominent in-app disclosure plus consent that meets the User Data policy | — |
| (d) Fully anonymous data | — |

How Flourish's flows map to these:

| Flow | Exception that may apply | Assessment |
|---|---|---|
| Ask AI, Smart Import, PDF / spreadsheet / screenshot AI | (c) user-initiated: the user picks the provider, enters their own key and taps | Strong |
| Automatic AI reading of alerts | (c) prominent disclosure + consent: `confirmAutomaticAi`, which names the provider and host, what is sent and why, retention, and revocation | Reasonable |
| FX and price requests (Frankfurter, Gold API, Coinbase, Alpha Vantage) | — | Currency codes, tickers, transaction dates. Automatic, no user identifier, but derived from the user's finances |
| Google ML Kit telemetry | — | Google's own SDK telemetry; Google says to declare it |

**Recommendation: declare conservatively.**

- Mark AI-bound data as **collected and shared**, rather than relying on
  exception (c).
- Mark FX/price lookups as **collected** "Other financial info".

Over-declaring is allowed and safer under review. Under-declaring is a policy
violation. Do **not** tick "processed ephemerally": what AI providers keep is
outside the developer's control.

## 2. Top-level answers

| Question | Answer | Basis |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Sections 1 and 3 |
| Is all user data collected by your app encrypted in transit? | **Yes** | Every built-in endpoint is `https://`. Android blocks cleartext at targetSdk 36 (no `usesCleartextTraffic`, no network security config). A user-typed `http://` custom AI URL fails to connect |
| Do you provide a way for users to request that their data is deleted? | **Yes** | Settings → Reset all data, and uninstall. The developer holds no copy; data at an AI provider is deleted through that provider. State this in the policy |
| Does your app require account creation / login? | **No** | — |
| Independent security review (MASA) | **No** | — |

## 3. Data types

"Optional" means the user can avoid that collection and still use the app.

| Data type | Collected | Shared | Required or optional | Purposes | Where it goes / code |
|---|---|---|---|---|---|
| **Financial info → Purchase history** | Yes | Yes | Optional | App functionality | Alert, statement and spreadsheet text, only to the AI provider the user configured (`ai_payment_assist.dart`, `ai_statement_reader.dart`, `ai_column_mapper.dart`) |
| **Financial info → Other financial info** | Yes | Yes | **Required**: FX lookups run automatically | App functionality | AI provider (optional flows). Frankfurter: currency codes and dates of foreign-currency transactions. Coinbase / Gold API / Alpha Vantage: held tickers (`market_data_service.dart`) |
| **Messages → SMS or MMS** | Yes | Yes | Optional | App functionality | Bank SMS text (read from notifications), to the AI provider only (`detection_service.dart` `_tryAi`, `assistPending`) |
| **Messages → Other in-app messages** | Yes | Yes | Optional | App functionality | Bank or wallet app alert text, to the AI provider only |
| **Photos and videos → Photos** | Yes | Yes | Optional | App functionality | Screenshot sent to a vision-capable AI provider (`ai_screenshot_reader.dart`) |
| **Personal info → Name** | Yes | Yes | Optional | App functionality | Names can appear in alerts, statements and screenshots; masking does not remove names |
| **App info and performance → Diagnostics** | Yes | No (Google ML Kit, an SDK) | Optional: only when the user reads an image | Analytics | ML Kit data disclosure |
| **Device or other IDs** | Yes | No | Optional: as above | Analytics | ML Kit per-installation identifier |

**Not collected:** location; contacts; calendar; email; audio; health and
fitness; web browsing; app activity or interactions; search history;
installed apps; crash logs; advertising ID.

Notes:

- **Installed apps:** the app-picker list stays on the device.
- **Crash logs:** no crash SDK; Play's own vitals are Google's, not the app's.

## 4. On-device only (out of scope, but stated in the privacy policy)

- the ledger database and receipts;
- encrypted daily backups;
- captured alerts while AI is off or the user doesn't tap;
- API keys in secure storage;
- user-initiated exports: the user chooses where they go, and the developer
  never receives them.

## 5. Other Play Console declarations

| Declaration | Answer |
|---|---|
| Ads | Contains ads: **No** |
| Advertising ID | **No**. The merged manifest has no `com.google.android.gms.permission.AD_ID` |
| Financial features | No money transfer, lending, trading, crypto exchange or custody. Pick the closest personal-finance / budgeting option; otherwise "Other: on-device expense tracking and budgeting; no financial transactions" |
| Target audience and content | Ages **18+** only |
| Content rating (IARC) | Utility/productivity; answer No to violence, sexuality, gambling, user-to-user communication, location sharing and digital purchases |
| App access | All functionality available without login. Notification-based detection needs the user to grant notification access in system settings |
| Government apps / health / news / COVID | No |
| Notification access | No declaration form. The prominent disclosure is the `readAlertsBody` dialog shown before the system setting. Keep a short screen recording of opt-in → system setting → inbox for review questions |
| Privacy policy URL | The public URL of `docs/privacy-policy.md`, the same value as `AppConstants.privacyPolicyUrl` |
