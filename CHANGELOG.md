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
- Recurring transfers (card autopay, savings), end dates and editing; a "Cards & wallets" screen; [audit](docs/AUDIT.md) of known issues.

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
