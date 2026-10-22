# Flourish Privacy Policy

> **DRAFT. Not published.** Checked against the code for version 1.2.0
> (`pubspec.yaml` `1.2.0+10200`) on 2026-10-22.
>
> Before publishing:
> 1. Replace every `[BRACKETED]` field.
> 2. Host this page at a public HTTPS URL, for example GitHub Pages.
> 3. Put that URL in `AppConstants.privacyPolicyUrl`
>    (`lib/core/constants/app_constants.dart`) and in Play Console.
> 4. Re-check the policy whenever data handling changes.
>
> Delete this box when you publish.

- **Effective date:** [DATE OF FIRST GOOGLE PLAY RELEASE]
- **Developer:** [DEVELOPER OR ORGANIZATION NAME AS SHOWN ON GOOGLE PLAY]
- **Contact:** [SUPPORT EMAIL]

Flourish is a personal finance tracker for Android. It has:

- no server and no user accounts;
- no advertising and no analytics;
- no crash-reporting service.

Your financial records are stored on your own phone. This policy explains
when information leaves your phone, what is sent, and who receives it.

## 1. Information stored on your phone

Flourish keeps the following in its private app storage:

- **Your finance records:** accounts, balances, transactions, budgets, goals,
  recurring payments, holdings, loans, templates and categories. They are kept
  in a database on the phone.
- **Payment alerts** captured from notifications (section 3). The full text of
  an alert is kept for the number of days you choose (30 by default, or none).
- **Receipt photos** you attach.
- **Seven automatic daily backups**, kept so a restore or import can be
  undone. Since version 1.2 they are encrypted (AES-256-GCM) with a random key
  held in Android's secure key storage, so only this installation can read
  them. Older unencrypted daily backups are encrypted automatically the next
  time Flourish saves a backup.
- **Your settings**, and any API keys you enter (section 6).

The database itself relies on Android's app sandbox and your phone's storage
encryption. Flourish does not add a separate layer of encryption to it. You
can lock the app with your fingerprint, face or device passcode
(Wealth → Tools → Device authentication lock).

The developer cannot see, access or recover any of this information.

## 2. Backups and moving to a new phone

Flourish **opts out** of Android's automatic Google backup and of
device-to-device transfer for all of its data. Your records are not copied to
your Google account or to a new phone automatically.

To keep a copy or move to a new phone, use **Export encrypted backup**
(Settings or Wealth → Tools). It creates a file protected by a password you
choose, using AES-256-GCM with a key derived from your password. You decide
where the file goes. It is never sent to the developer.

Flourish also offers files that are **not encrypted**. They are clearly
labelled, and the app warns you before creating the unencrypted backup:

- **Export unencrypted backup** (JSON);
- **Export transactions as CSV**.

Anyone who obtains a copy of these files can read them.

## 3. Payment-alert detection (Android notification access)

If you turn on payment detection and grant **notification access** in Android
settings, Flourish reads notifications from your messaging app and from the
bank or wallet apps you choose:

- Notifications that don't look like payment alerts are ignored and not
  stored.
- One-time codes and declined payments are never saved.
- Card numbers are reduced to their last four digits.
- Detected payments wait in an inbox for you to review, unless you turn on
  automatic adding.

Flourish does not request SMS permissions and cannot read your message inbox.

Alerts are read and stored on your phone. They leave it **only** through the
optional AI assistant (section 4): when you tap **Ask AI**, or automatically
if you separately agree to automatic reading.

You can turn detection off in the app, and remove notification access in
Android settings, at any time.

## 4. Optional AI assistant (third-party processing)

The AI assistant is **off by default**. To use it, you must:

1. choose a provider: Google Gemini, DeepSeek, Groq, OpenRouter, or a custom
   server compatible with the OpenAI API;
2. enter **your own API key** for that provider.

Requests then go **directly from your phone to that provider**, under your
account with them. The developer does not operate, relay or see these
requests.

| Feature | When information is sent | What is sent |
|---|---|---|
| **Ask AI** (payments inbox) | Only when you tap it | That alert's text and your category names |
| **Smart Import** | When you paste or share text and tap Read | Only the text you provided, and your category names |
| **Read unclear alerts automatically** | Only after you turn it on and accept a notice that names the provider. It stops when you turn it off, and must be accepted again if you change provider | Captured alerts Flourish could not read confidently, and your category names |
| **PDF statement reading** | When you choose AI reading for a statement | Statement page text. Lines that begin with name or address labels are removed |
| **Spreadsheet column detection** | When you tap it | The header row and up to five sample rows |
| **Screenshot reading** (Android) | When you tap Read with AI, after a one-time notice | The screenshot image itself |

**Masking.** Before text is sent, Flourish masks the following:

- card, account, IBAN and national ID numbers;
- phone numbers and email addresses;
- one-time codes.

This masking is **always applied** to automatic reading, PDF statements and
spreadsheet samples. For Ask AI and Smart Import it is on by default. You can
turn it off only for paid providers; for free tiers it is always on. Names of
people and merchants are not masked.

An **image cannot be masked**: everything visible in a screenshot is sent, and
the app tells you so before you agree.

**What the provider does with it.** Each provider handles what it receives
under its own terms and privacy policy. It may store it, and may process it in
other countries. Some free tiers use submitted content to improve their
products, and people may review it. Google, for example, says this about the
free (unpaid) Gemini API. Read your provider's terms before you agree:

- Google Gemini API: https://ai.google.dev/gemini-api/terms
- DeepSeek: https://chat.deepseek.com/downloads/DeepSeek%20Privacy%20Policy.html
  and https://platform.deepseek.com/downloads/DeepSeek%20Open%20Platform%20Terms%20of%20Service.html
- Groq: https://groq.com/privacy-policy/
- OpenRouter: https://openrouter.ai/privacy
- A custom server: its operator's terms.

Requests use your API key and may be billed to your account with that
provider. To delete what was sent, contact that provider.

## 5. Exchange rates and market prices

To value accounts and holdings in your chosen currency, Flourish fetches
public data over HTTPS. It does this automatically when you open the app, at
most about once a day per currency pair:

- **Frankfurter** (`api.frankfurter.dev`, European Central Bank reference
  rates): exchange rates and the list of currencies. Requests contain currency
  codes. For transactions in an account held in another currency, the request
  also contains the transaction's date, to look up the rate for that day.
- **Gold API** (`api.gold-api.com`): the gold price, if you track gold.
- **Coinbase** (`api.coinbase.com`): prices for the crypto symbols you hold.
- **Alpha Vantage** (`www.alphavantage.co`): stock prices for the tickers you
  hold, only if you add your own Alpha Vantage key. The request contains the
  ticker and your key.

These requests contain no balances, amounts, names or account details. Like
any internet request, they reveal your IP address to the service.

## 6. API keys

Keys you enter for an AI provider or for Alpha Vantage are stored in Android's
encrypted secure storage, backed by the Android Keystore. Each key is sent
only to the service it belongs to. Keys are never included in backups or
exports, and never sent to the developer. **Reset all data** deletes them.

## 7. Text recognition (Google ML Kit)

When you import a screenshot or shared image, Android reads its text **on your
phone** using Google's ML Kit through Google Play services. The image is not
sent to Google for this.

ML Kit may send Google diagnostic and usage information, such as:

- device model and Android version;
- app package name and version;
- performance metrics;
- a per-installation identifier.

Google describes this at
https://developers.google.com/ml-kit/android-data-disclosure.

## 8. What Flourish does not do

- No advertising, and no advertising ID.
- No analytics, tracking or crash-reporting libraries.
- No sign-in.
- No selling or renting of information.
- No transfer of your financial records to the developer.

## 9. Keeping and deleting information

- **Your records** stay on your phone until you delete them.
- **The text of captured alerts** is deleted after the number of days you
  choose.
- **Settings → Reset all data** deletes everything Flourish keeps about your
  finances on this phone:
  - records and saved alerts;
  - receipt photos and daily backups;
  - temporary export copies and queued alerts;
  - AI settings and API keys.

  It does not touch files you exported to other apps or places. It keeps your
  app lock and language settings.
- **Uninstalling Flourish** removes all of its data from your phone.
- **Information already sent to an AI provider** is governed by that
  provider's retention policy.

## 10. Children

Flourish is meant for adults and is not directed to children.
[OWNER: confirm the minimum age you want to state.]

## 11. Changes to this policy

When the way Flourish handles information changes, we will update this page
and its effective date, and mention the change in the release notes.

## 12. Contact

Questions or requests about privacy: [SUPPORT EMAIL]
