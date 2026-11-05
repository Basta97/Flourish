# Flourish Privacy Policy

- **Effective date:** [DATE OF FIRST APP STORE RELEASE]
- **Developer:** Flourish
- **Contact:** [SUPPORT EMAIL]

Flourish is a personal finance tracker for Android and iPhone. It has:

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
  An alert still waiting for your review keeps its text for at most 30 days.
- **Receipt photos** you attach.
- **Seven automatic daily backups**, kept so a restore or import can be
  undone. Since version 1.2 they are encrypted (AES-256-GCM) with a random key
  held in the phone's secure key storage (the Android Keystore or the iPhone
  Keychain), so only this installation can read them. Older unencrypted daily backups are encrypted automatically the next
  time Flourish saves a backup.
- **Your settings**, and any API keys you enter (section 6).

The database itself relies on the phone's app sandbox and storage encryption
(on iPhone, Data Protection). Flourish does not add a separate layer of encryption to it. You
can lock the app with your fingerprint, face or device passcode
(Settings → Security & privacy → Device authentication lock). While the lock
is on, Flourish covers its screen in the recent-apps view and app switcher,
and on Android also keeps it out of screenshots and screen recordings.

Optional **payment reminders** (Settings → Automation) appear on your lock
screen. While the app lock or "Hide amounts" is on, they leave amounts out,
and on Android a secure lock screen hides their text entirely.

The developer cannot see, access or recover any of this information.

## 2. Backups and moving to a new phone

Flourish **opts out** of Android's automatic Google backup and of
device-to-device transfer for all of its data. On iPhone, its data is likewise
excluded from iCloud and computer backups. Your records are not copied to
your Google or Apple account, or to a new phone, automatically.

To keep a copy or move to a new phone, use **Export encrypted backup**
(Settings → Data). It creates a file protected by a password of at least 12
characters that you choose, using AES-256-GCM with a key derived from your
password (PBKDF2-SHA256, 600,000 rounds). You decide where the file goes. It
is never sent to the developer.

Flourish also offers files that are **not encrypted**. They are clearly
labelled; the app warns you, and asks for your device lock, before creating
the unencrypted backup. The temporary copy made for the share sheet is
deleted as soon as you finish sharing:

- **Export unencrypted backup** (JSON);
- **Export transactions as CSV**.

Anyone who obtains a copy of these files can read them.

## 3. Payment-alert detection

**On Android**, if you turn on payment detection and grant **notification access** in Android
settings, Flourish reads notifications from your messaging app and from the
bank or wallet apps you choose:

- Notifications that don't look like payment alerts are ignored and not
  stored.
- One-time codes and declined payments are never saved. Codes, full card
  numbers and national ID numbers are removed before an alert is written
  anywhere on the phone, including the queue that holds alerts until Flourish
  opens.
- Card numbers are reduced to their last four digits.
- Detected payments wait in an inbox for you to review, unless you turn on
  automatic adding.

Flourish does not request SMS permissions and cannot read your message inbox.

Alerts are read and stored on your phone. They leave it **only** through the
optional AI assistant (section 4): when you tap **Ask AI**, or automatically
if you separately agree to automatic reading.

You can turn detection off in the app, and remove notification access in
Android settings, at any time.

**On iPhone**, apps cannot read your messages or notifications. If you set up
the optional Shortcuts automation that Flourish describes, iOS hands each new
payment message you choose to Flourish, which treats it exactly as above.
Nothing is read unless you create that automation, and you can delete it in
the Shortcuts app at any time.

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

Keys you enter for an AI provider or for Alpha Vantage are stored in the
phone's encrypted secure storage (the Android Keystore, or the iPhone Keychain,
where they are readable only after the phone is first unlocked and are never
synced to iCloud or restored onto another device). Each
AI key is stored for the server address it was entered for and is sent only
there; switching provider never sends one provider's key to another. AI
servers must use HTTPS, except a server on your phone or home network. Keys are never included in backups or
exports, and never sent to the developer. **Reset all data** deletes them.

## 7. Text recognition on Android (Google ML Kit)

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
  choose, and at most 30 days after arrival while it waits for review.
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

Flourish is not directed to children under 13, and we do not knowingly
collect information from them. Flourish has no accounts and sends nothing to
the developer, so no one's information, including a child's, reaches us.

## 11. Changes to this policy

When the way Flourish handles information changes, we will update this page
and its effective date, and mention the change in the release notes.

## 12. Contact

Questions or requests about privacy: [SUPPORT EMAIL]
