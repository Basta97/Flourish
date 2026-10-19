# Changelog

All notable changes to Flourish are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Cards & wallets per account (debit, credit, prepaid, mobile wallet, InstaPay, BNPL) and, on every entry, what paid, the merchant and its source.
- Purchases in another currency with the original price and the bank's foreign-transaction fee as a separate entry; refunds that reduce spending.
- Credit card terms and status: limit, available credit, how much of the limit is used, statement, minimum due, interest estimate, cash advances with fees, and reminders with the minimum due.
- Reports by payment method, card or wallet, currency, and fees and interest paid; CSV export columns for merchant, payment and original amount.
- Payment detection: English/Arabic parser for Egyptian banks and wallets, a review inbox with duplicate detection, merchant category learning and optional automatic adding; Android notification listener and iOS Shortcuts actions.
- Detected payments in USD and other currencies: the Android filter and the parser know foreign codes, symbols and Arabic names; without the bank's EGP figure the charge is estimated at the day's exchange rate plus the card's foreign-transaction fee.
- Payment detection on Android: pick bank and wallet apps from every installed app, before they post an alert; repeat notifications are ignored for 24 hours, even after the app restarts.
- Catch up on the last 7 days: paste last week's bank alerts or import a statement, and Flourish asks only about the payments it doesn't have yet; plus a step-by-step guide for the iPhone Messages and Wallet automations.
- Gemini works with Google's newer `AQ.` API keys (native Gemini API instead of the OpenAI-compatible layer), and Settings › AI Assistant can list the models your key can use.
- Optional AI for unclear payment alerts (DeepSeek, OpenRouter, Groq, Gemini or any OpenAI-compatible server, with your own key): answers are checked against the message, personal data is masked first, and the AI can propose new categories that are only created when you add the payment.
- Smart Import takes many alerts at once and sends them to Payments to review; a screenshot can be kept as the payment's receipt.
- Import from other apps: Money Manager, Wallet, Monefy, Spendee, YNAB, Flourish CSV, bank CSV, OFX/QFX, QIF and Excel, with a review step (account mapping, categories not in Flourish, totals per account), duplicate detection by bank transaction id and possible-duplicate warnings, paired transfers, optional AI column mapping for unknown spreadsheets, and undo.
- PDF bank statements in Import from other apps: the transaction table is read on the phone (date, description, debit/credit or signed amounts, the running balance as a check); password-protected PDFs ask for the password; when no table is recognised and AI is set up, pages can be read by the AI with account numbers, phones, emails and customer lines removed, keeping only rows whose amount is printed on the page. Scanned PDFs get a clear "needs a text PDF" message.
- Arabic screenshots: iOS reads Arabic and English on the phone; on Android, where on-device reading is Latin-only, a screenshot can be read by an image-capable AI model after you agree (off by default, AI settings → Read Arabic screenshots with AI).
- Recurring transfers (card autopay, savings), end dates and editing; a "Cards & wallets" screen; [audit](docs/AUDIT.md) of known issues.

### Changed

- Excel import uses `excel_community`, the maintained fork of `excel`, so the app can use the current `archive` package that PDF import needs.

### Fixed

- Databases upgraded from older versions could become unreadable after adding accounts or transactions (text `created_at` values); they are repaired on open.
- New installs created USD accounts while reporting in EGP; amounts could be booked in the wrong currency when editing; stale exchange rates could be frozen into entries.
- Amount fields now accept Arabic-Indic digits and comma decimals, respect 0- and 3-decimal currencies, and no longer fail on a blank transfer fee.
- Pausing and resuming a recurring payment no longer back-fills the paused months; one failing rule no longer blocks the rest; missed auto-income months are posted once.
- Transfers no longer create "Transfer transfer" categories; Home, Budgets and Reports agree on what is a transfer; deleting a category can no longer hide spending.
- Credit card debt is shown and entered as the amount owed; undo restores the full entry; accounts with history are archived instead of deleted.

## [1.0.0] - 2026-10-15

### Added

- Multi-account tracking (bank, cash, e-wallet, credit) with categories, budgets, goals, and recurring transactions.
- **Home** dashboard with known net worth, month cash flow, and quick actions.
- **Ledger** with calendar views, filters, and swipe actions on transactions.
- **Wealth** workspace: holdings, obligations, reports, and tools (FX overrides, encrypted backup, spreadsheet import/export).
- Multi-currency reporting with decimal-safe `Amount` handling and documented FX/price feeds.
- Island-style bottom navigation with context-aware **+** add sheets.
- Smart import from shared notification text; Android share intents and iOS share extension.
- Local-first SQLite (Drift) storage, JSON and encrypted backup paths.
- Light, dark, and system themes with bundled Manrope / Space Grotesk fonts.
- Widget, finance, and integration tests; CI workflow for analyze and test.

### Changed

- Rebrand to **Flourish** (`com.flourish.app`) with updated icons and typography.
- Replaced legacy analytics screen with Wealth reporting flows.

### Security

- Encrypted backups use AES-256-GCM with PBKDF2; optional device biometric lock.
- Release Android builds require an explicit keystore (no debug signing for release).

[1.0.0]: https://github.com/Basta97/Flourish/releases/tag/v1.0.0
