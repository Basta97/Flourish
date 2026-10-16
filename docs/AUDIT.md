# Flourish audit — October 2026

Findings from a full review of the ledger, currency handling, credit cards,
payment methods and the import pipeline. Every row was checked against the code
at commit `ab550ec`. Severity: **C** critical, **H** high, **M** medium,
**L** low. Paths are relative to `lib/` unless they start with another folder.

Fix status is tracked in the "Status" section at the end; the implementation
plan follows the phases listed there.


### A1. Database / migrations
| Sev | Finding | Where |
|---|---|---|
| C | v5 migration rebuilds tables with `created_at DATETIME ... DEFAULT CURRENT_TIMESTAMP` (TEXT). Drift stores DateTime as unix-seconds INTEGER and inserts omit `created_at`, so on databases upgraded from <v5 every new row gets a text date; reading it as int fails, breaking the whole table stream. Existing migration test starts at v5 so never hits it. | `lib/data/database/database.dart:113-248` |
| H | `category_id` declared NOT NULL but `onDelete: setNull`. Fresh installs: deleting a category with no same-type fallback throws (uncaught in `categories_management_screen.dart:184`). Upgraded DBs: column is nullable → NULL written → `row.read<int>('category_id')` crashes. | `tables/transactions_table.dart:9`, `recurring_transactions_table.dart:9`, `database.dart:697, 728-786` |
| H | v5 migration is not idempotent/transactional (`CREATE TABLE x_new` without IF NOT EXISTS, no cleanup) — a failure mid-way bricks every later launch. Upgraded schema also differs from fresh (no FK on `linked_transaction_id`, nullable category). | `database.dart:113-248` |
| M | v1-era credit balances used the old sign (expense −); `FinanceStore.create` assumes the new sign → wrong opening for legacy credit cards. | `data/finance/finance_store.dart:25-39` |

### A2. Ledger / balances
| Sev | Finding | Where |
|---|---|---|
| H | Two balance-mutation paths. Legacy `AppDatabase.insertTransactionAndUpdateBalance / updateTransactionAndUpdateBalance / transferBetweenAccounts` (same amount both legs, no currency check, no FX snapshot, no archived check) still used by **recurring processing**. | `database.dart:511, 570, 602, 869` |
| H | Recurring batch is all-or-nothing: one bad rule (archived account, mismatched category, `Infinity` amount) rolls back every rule on every launch; error only logged. | `database.dart:842-901`, `main.dart:27-33` |
| H | Pausing a recurring rule just flips `isActive`; resuming back-fills every missed period. A past start date also silently posts every missed occurrence (no cap/confirm). No edit, end date, or transfer-type recurring. | `recurring_transactions_screen.dart:155-160, 439-470` |
| M | Default category for ledger kinds is `'Transfer $kind'` → categories literally named "Transfer transfer"; legacy path uses "Transfer In/Out"; transfer fees filed under "Investment fees". | `financial_ledger_service.dart:36-44` |
| M | Screens decide "is this a transfer" differently (linkedTransactionId vs details kind vs category-name prefix) → Home, Reports and Budgets can disagree; a user category named "Transfer …" vanishes from Reports. | `dashboard_screen.dart:210-216`, `reports_view.dart:417-420`, `budgets_screen.dart:498-509` |
| M | Same-currency transfer still accepts a different "received" amount → creates/destroys money. | `add_transaction_sheet.dart:166-174`, `financial_ledger_service.dart:274-279` |
| M | Editing a transaction onto an account in another currency relabels 100 USD → 100 EGP with no conversion or warning. | `edit_transaction_sheet.dart:315-330`, `financial_ledger_service.dart:166-195` |
| M | Category delete silently reassigns (may pick "Transfer …" → spending disappears; Salary → Freelance) and cascade-deletes its budgets without warning. | `database.dart:728-786`, `tables/budgets_table.dart:7` |
| M | Account delete cascades transactions/goals/recurring without reverting; the other transfer leg survives as plain income/expense. UI guard runs outside the transaction. | `database.dart:400-413`, `account_detail_screen.dart:192-199` |
| M | Future-dated transactions (up to 5 years) change today's balance immediately. | `transaction_form_parts.dart:356-358` |
| M | Monthly auto-income only checks the current month (missed months never posted) and can double-count with a recurring salary. | `finance_runtime.dart:99-135` |
| L | Undo after swipe-delete re-inserts without kind/rates/attachments. | `transaction_swipe_tile.dart:316-335` |
| L | Contract card payment transfers principal+interest but interest is never charged to the card; "Pay card" fails when the contract has no cash account. | `contract_service.dart:191-198`, `contracts_view.dart:444-449` |

### A3. Currency
| Sev | Finding | Where |
|---|---|---|
| C | Defaults disagree: reporting currency EGP, but table default and seeded Cash/Bank accounts are **USD**, and an account's currency can't be changed later. `AppConstants.defaultCurrency/defaultAccounts` unused; backup import falls back to USD. | `tables/accounts_table.dart:8`, `database.dart:350-363`, `theme_providers.dart:29-31`, `finance_tools_view.dart:274`, `settings_screen.dart:538` |
| H | No way to record a foreign-currency purchase (USD spent on an EGP card). `recordCash` always stamps the account currency; the notification importer drops the parsed currency (USD 50 → EGP 50). | `financial_ledger_service.dart:65`, `notification_import_screen.dart:232-238` |
| H | FX snapshots accept a rate of any age and are cached forever; the backfill then skips them (pre-devaluation EGP rate frozen). | `financial_ledger_service.dart:76-100`, `valuation_service.dart:63-118`, `market_data_service.dart:281-283` |
| M | Search and Recurring label amounts with the global currency instead of the account's. | `search_screen.dart:66,162`, `recurring_transactions_screen.dart:79,146,249,286` |
| M | Amount entry allows only ASCII digits and 2 decimals: Arabic-Indic digits / `٫` / comma decimals rejected, KWD/BHD/OMR rounded (edit sheet pre-fills `toStringAsFixed(2)` → re-saving changes balances). Fee/destination use `double.parse` → crash on empty/“1,000”. | `transaction_form_parts.dart:93`, `edit_transaction_sheet.dart:48,315`, `add_transaction_sheet.dart:356-361` |
| L | `CurrencyFormatter`: JPY and CNY both "¥", `formatCompact` drops the minus sign, default `'USD'` when a caller forgets; decimals rule duplicated in `contract_service.dart:51-55`. | `core/utils/currency_formatter.dart` |
| L | Dead code that mixes currencies: `dashboard_providers.dart` (DashboardStats), most of `insights_service.dart`, `sumTransactionsByType`, `getNetWorth`, `totalBalanceProvider`. Home/Budgets/Reports themselves are FX-correct via `ValuationService.transactionValue`. | — |

### A4. Credit cards, payment methods, fees
| Sev | Finding | Where |
|---|---|---|
| H | Credit sign is never shown: debt is stored positive, "Initial Balance"/"Reconciled balance" give no hint; entering −5000 turns the card into an asset (net worth off by 2× debt). `AccountCard` shows debt as a normal balance and an overpaid card in red. | `accounts_screen.dart:196-204`, `finance_tools_view.dart:260-264`, `valuation_service.dart:129-131`, `account_card.dart:45,159` |
| H | No credit limit, available credit, utilization, minimum payment, APR interest, FX-fee %, cash-advance fee, late fee, or installments. Card billing exists only as a generic Wealth → Obligations "contract" (statement/due day) that most users won't find. | `domain/finance/models.dart:150-176`, `contract_service.dart:273-367` |
| H | No payment method on a transaction: no debit/credit/prepaid card, network (Visa/Mastercard/Meeza), last-4, wallet (InstaPay, Vodafone Cash…), nor a debit card linked to a bank account. | `tables/transactions_table.dart` |
| M | Budgets count only the exact category (not subcategories), periods anchor on the creation instant (not `month_start_day`), duplicate budgets allowed, creation not atomic with its currency record. | `budgets_screen.dart:466-523, 688-714` |

### A5. Import / detection (today)
| Sev | Finding | Where |
|---|---|---|
| H | Parser is English-only and returns only amount/type/merchant: "EGP 1,234" → 1, dates/balances/card numbers taken as amounts, Arabic digits ignored, OTP/declined/promo saved as expenses, refunds become income, merchant over-captures ("at" inside "Sat"). | `core/services/transaction_notification_parser.dart` |
| H | Saves with date = now, first account, first category; duplicate check only warns and uses `createdAt`. | `notification_import_screen.dart:112-276` |
| M | One pending-import slot on Android (`pending`) and iOS (one UserDefaults key) → second share overwrites the first; only the Home tab pulls imports. | `MainActivity.kt:14,41-59`, `SharedImportStore.swift`, `dashboard_screen.dart:44-78` |
| L | ML Kit Latin OCR / Vision default languages can't read Arabic. iOS bundle + app group still `com.basta.bastasaving` (CHANGELOG claims `com.flourish.app`) — flag only, changing it breaks installs. Docs claim deep links that don't exist. | `MainActivity.kt:27`, `ios/Runner.xcodeproj`, `docs/PLATFORMS.md:30` |

---

Also (L): `AppDatabase.updateAccount` replaces the whole row incl. balance
(latent desync with `exact_balances`); fresh installs never create the
transaction indexes (only upgrade paths do); goals can be created with
`accountId -1` when no account exists and credit accounts are selectable but
can't receive contributions; "Reset all data" is not transactional.

## Status

Remaining items intentionally not changed: the iOS bundle / app-group id
`com.basta.bastasaving` (changing it would break existing installs), and the
v1-era credit-card sign (only affects databases created by the first
release; reconcile those cards once via Manage account).


| Phase | Scope | Status |
|---|---|---|
| 1A | One write path for money, recurring/undo/auto-income, legacy DB repair | done |
| 1B | Amount parsing, currency guards and defaults, credit wording | done |
| 1C | Transfer classification, system categories, FX freshness, dead code | done |
| 2A | Schema v7: cards & wallets, payment method/merchant/source on entries, FX purchases, refunds, cash advances, recurring transfers | done |
| 2B–2D | Credit card terms (limit, APR, minimum due, fees), paid-with / foreign currency / refund in forms, card panel, reports by method/card/currency/fees | done |
| 3A | English/Arabic bank & wallet message parser with 44 fixtures | done |
| 3B | Detected-payments inbox (schema v8), matching, dedupe, auto-confirm, settings | done |
| 3C | Android notification listener + durable queue (compile-checked; needs device test) | done |
| 3D | iOS Shortcuts actions + app-group queue (needs Xcode build and device test) | done |
| 3E | Settings, privacy controls, documentation | done |
