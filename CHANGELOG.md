# Changelog

All notable changes to Flourish are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
