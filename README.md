# Flourish

Flourish is a smart multi-account finance tracker built with Flutter, Riverpod,
Drift, and SQLite. It helps track accounts, transactions, budgets, recurring
payments, goals, and notification-based transaction imports.

## Features

- Multi-account balance tracking, including bank, cash, e-wallet, and credit accounts
- Income, expense, and linked transfer transactions
- Category, budget, recurring transaction, and savings goal management
- Smart transaction import from shared notification text
- Local-first SQLite storage with JSON backup and restore
- Light, dark, and system theme modes

## Getting Started

Install Flutter, then run:

```bash
flutter pub get
flutter run
```

## Quality Checks

Before opening a pull request or shipping a build, run:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Code Generation

Drift uses generated database code. If table definitions change, regenerate with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Data Safety

Flourish stores user data locally. Backup and restore currently cover accounts,
categories, transactions, budgets, recurring transactions, and goals.

## Complete finance workspace

Flourish now includes exact financial amounts, multi-currency valuation, holdings,
contracts and liabilities, reporting, reconciliation, encrypted backups, and
spreadsheet portability. Open **Wealth** for Holdings, Obligations, Reports, and
Tools. The reporting currency defaults to EGP for new installations.

See [finance implementation and verification](docs/FINANCE_IMPLEMENTATION.md) for
financial rules, price coverage, migration behavior, test commands, and release
signing requirements.
