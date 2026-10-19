# Flourish — project overview

## What it is

**Flourish** is a **local-first personal finance app** for tracking money across multiple accounts, day-to-day spending, budgets, goals, and a fuller **wealth workspace** (holdings, obligations, and reports). Data stays on the device in SQLite; backup and restore are explicit user actions.

The app is built with **Flutter** so the same UI and logic run on **Android** and **iOS**. It is not a bank connector: you enter or import transactions, optionally from notification text or spreadsheets.

## Who it is for

- People who want **one place** for cash accounts, cards, transfers, and budgets.
- Users who also track **investments, property, gold, crypto, deposits, and loans** with multi-currency reporting.
- Anyone who prefers **privacy and offline control** over cloud aggregation.

Default **reporting currency** for new installs is **EGP**; you can change reporting currency without rewriting original transaction currencies (see [Finance implementation](FINANCE_IMPLEMENTATION.md)).

## Main areas of the app

| Area | Route | Purpose |
|------|--------|---------|
| **Home** | `/dashboard` | Net worth (known assets − liabilities), month cash flow, shortcuts, recent activity |
| **Ledger** | `/transactions` | Income, expense, and transfers; calendar and filters |
| **Tools** | `/tools` | Templates, accounts, FX, import/export, security, backup, and widget setup; accessible from Home and Settings |
| **Wealth** | `/wealth` | Holdings, obligations, and reports |
| **Search** | `/search` | Indexed offline search across records and app features |
| **Exchange rates** | `/exchange-rates` | Search currencies, convert amounts, save favorite pairs and manage manual rates |
| **Accounts** | `/accounts` | Banks, cash, wallets, credit; reconciliation |
| **Budgets** | `/budgets` | Category limits by period |

A floating **island navigation bar** (center **+** for context-aware add sheets) is shared on both platforms.

## Core principles

1. **Local-first** — SQLite (Drift) is the source of truth; network is used only for optional market/FX feeds.
2. **Exact amounts** — Money uses decimal semantics (`Amount` / `decimal` package); conversions and rates are stored with provenance.
3. **No silent fixes** — Ambiguous imports, missing FX, and incomplete prices surface as warnings, not fake zeros.
4. **Unified UI** — One Material-based design system (bundled fonts); platform differences are mostly system chrome, transitions, and native import entry points.

## What Flourish is not

- Not a substitute for tax, legal, or investment advice.
- Not guaranteed live exchange or broker prices (feeds are documented in [FINANCE_IMPLEMENTATION.md](FINANCE_IMPLEMENTATION.md)).
- Not a sync service across devices unless you use your own backup files.

## Repository

- **GitHub:** [github.com/Basta97/Flourish](https://github.com/Basta97/Flourish)
- **License:** See repository license file (if present); font licenses under `assets/fonts/*/OFL.txt`.

## Next steps

- **Run the app:** [Getting started](GETTING_STARTED.md)
- **Ship a version:** [Releases](RELEASE.md)
- **Deep dive on money logic:** [Finance implementation](FINANCE_IMPLEMENTATION.md)
