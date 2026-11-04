# Flourish: project and architecture guide

Reviewed 28 October 2026 · Current working tree · Companion to the 25-slide presentation

The most urgent reliability finding is failed detection messages being acknowledged. The strongest performance candidates are bounded transaction queries, batched valuation reads and narrower refresh notifications. These performance candidates need physical-device profiling; no speedup is claimed.

## Reading map

Slides 1–8 introduce the product and architecture. Slides 9–20 explain the features and suggestions. Slides 21–25 cover priorities, measurement, implementation and evidence.

## 1. Flourish: Project & architecture review

### Current behavior

- Understand the app.

- Protect financial correctness.

- Make growth affordable.



### Suggestions

- Code review • 28 October 2026

- Flutter • Riverpod • Drift / SQLite



### Explanation

This presentation explains the current working tree, including local edits present at review time. It is a learning guide and an improvement proposal, not a certification of every feature. Read the speaker notes for deeper explanations and source paths. No application code was intentionally changed for this review. Existing repository screenshots are illustrations of earlier states, not screenshots of today’s test run.



### Source trail

- [README.md](/Users/basta97/DEV/flutter/Flourish/README.md)

- [pubspec.yaml](/Users/basta97/DEV/flutter/Flourish/pubspec.yaml)

- git working tree



## 2. What the product does

### Current behavior

- Record money across accounts, cards and wallets.

- Plan spending with budgets, goals and recurring rules.

- Track holdings, debts and reports in Wealth.



### Suggestions

- Keep everyday tasks easy to discover.

- Explain cash, debt, investment value and missing valuations in plain language.



### Explanation

Flourish is a local-first personal finance application for Android and iOS, with English and Arabic localization. SQLite is the primary local store. Network access is optional for market and currency data and configurable AI assistance. New installations use EGP for reporting. The core user journey is account setup, recording or reviewing activity, then understanding balances and planning. Offline ownership is a product strength; preserve it when adding features.



### Source trail

- [README.md](/Users/basta97/DEV/flutter/Flourish/README.md)

- [lib/core/router/app_router.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/router/app_router.dart)

- [lib/l10n/app_en.arb](/Users/basta97/DEV/flutter/Flourish/lib/l10n/app_en.arb)

- [lib/l10n/app_ar.arb](/Users/basta97/DEV/flutter/Flourish/lib/l10n/app_ar.arb)



## 3. How to read this review

### Current behavior

- Confirmed: behavior visible in source code.

- Checked: static analysis and selected tests.

- Hypothesis: expected cost that needs profiling.



### Suggestions

- Prioritize financial reliability first.

- Then measure the largest data paths before changing them.



### Explanation

The oracle for money movement is the project’s central-ledger rule, exact arithmetic, balanced transfer handling and established financial scenarios. A passing automated test is evidence for its tested scenario only. Code inspection can establish that a query loads all transactions or that a failed queue item is acknowledged; it cannot tell us how many frames users lose on a physical phone. Recommendations in this deck are proposals unless explicitly described as existing behavior.



### Source trail

- [test/architecture_test.dart](/Users/basta97/DEV/flutter/Flourish/test/architecture_test.dart)

- [test/finance/ledger_test.dart](/Users/basta97/DEV/flutter/Flourish/test/finance/ledger_test.dart)

- AGENTS.md instructions



## 4. Architecture as implemented

### Current behavior

- Screens and shared widgets → Riverpod providers

- Providers → finance services, search or AppDatabase

- Services → FinanceStore and Drift → SQLite



### Suggestions

- Keep the useful layers; avoid a full rewrite.

- Introduce focused read repositories where query logic is repeated.



### Explanation

This is a pragmatic layered application, not strict Clean Architecture. Many providers directly expose AppDatabase; finance services import database and storage types. The domain folder contains Amount and finance models. PortfolioRepository and ContractRepository are defined inside finance_store.dart, and SearchRepository has its own data module. The architecture document mentions domain repository contracts and lib/data/repositories, but those do not exist in this working tree. The target should be clearer ownership and testable boundaries, not interfaces around every trivial method.



### Source trail

- [lib/presentation/providers/database_provider.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/database_provider.dart)

- [lib/presentation/providers/finance_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/finance_providers.dart)

- [lib/data/finance/finance_store.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/finance/finance_store.dart)

- [lib/domain/finance](/Users/basta97/DEV/flutter/Flourish/lib/domain/finance)

- [docs/ARCHITECTURE.md](/Users/basta97/DEV/flutter/Flourish/docs/ARCHITECTURE.md)



## 5. Startup and lifecycle

### Current behavior

- main initializes preferences and one database.

- Recurring processing runs before the first frame.

- Runtime wrappers handle refresh, imports and widgets.



### Suggestions

- Measure time spent before runApp.

- Preserve recurring idempotency if moving it after first paint.

- Separate local refresh from optional network work.



### Explanation

main.dart awaits RecurringService.processDue before mounting the UI. FinanceRuntime runs another refresh after the first frame and on resume; it includes ledger maintenance, recurring, auto-income, market refresh, snapshots, backup and reminder scheduling. This makes responsibility easy to find but creates sequential dependency chains. If moving work later, show loading or pending states where balances are not settled. Do not display incorrect settled totals just to improve apparent startup time. A single coordinator should own refresh ordering and prevent redundant work. Recurring processing already includes duplicate protection and month-end anchors; preserve those guarantees when changing scheduling.



### Source trail

- [lib/main.dart](/Users/basta97/DEV/flutter/Flourish/lib/main.dart)

- [lib/presentation/wealth/finance_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/finance_runtime.dart)

- [lib/presentation/detection/detection_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/detection/detection_runtime.dart)

- [lib/presentation/home_widgets/home_widget_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/home_widgets/home_widget_runtime.dart)



## 6. Navigation and feature discovery

### Current behavior

- go_router owns shell routes and full-screen routes.

- Home, Ledger, Wealth, Accounts and Budgets form the main workspace.

- Tools, Search and Settings expose supporting flows.



### Suggestions

- Audit route labels and entry points together.

- Keep account detail, payment method and import review links predictable.



### Explanation

The route file is the most reliable map of entry points. ShellRoute includes dashboard, transactions, wealth, search, accounts and budgets. Tools, templates and exchange rates are root routes, contrary to the older documentation’s shell listing. Wealth also accepts a reports query parameter. Search hits and home widgets navigate into the same application. Prefer explicit route contracts and smoke tests for malformed account IDs, unknown routes and preserved selected tabs. Do not add navigation layers without a user need.



### Source trail

- [lib/core/router/app_router.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/router/app_router.dart)

- [lib/presentation/search/search_navigation.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/search/search_navigation.dart)

- [docs/ARCHITECTURE.md](/Users/basta97/DEV/flutter/Flourish/docs/ARCHITECTURE.md)



## 7. Storage and the money model

### Current behavior

- Drift tables store operational records.

- FinanceStore adds JSON finance records and exact decimal balances.

- Schema version 9 handles migration and repair.



### Suggestions

- Document which representation is authoritative.

- Use typed records for frequently queried collections.

- Preserve exact amounts through every read path.



### Explanation

Eight declared Drift tables cover accounts, transactions, categories, budgets, goals, recurring rules, payment instruments and detected payments. FinanceStore also creates finance_records, exact_balances and transaction_details. Accounts and transactions retain numeric fields for legacy/UI compatibility while Amount uses Decimal and extended stores preserve decimal text. This hybrid avoids an immediate disruptive migration, but creates a requirement to keep representations synchronized. JSON collections are flexible but weakly constrained and can force whole-collection reads. Migrate only collections whose relationships and query costs justify typed schema. WAL, foreign keys, indexes and a background database connection already exist.



### Source trail

- [lib/data/database/database.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/database/database.dart)

- [lib/data/database/tables](/Users/basta97/DEV/flutter/Flourish/lib/data/database/tables)

- [lib/data/finance/finance_store.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/finance/finance_store.dart)

- [lib/domain/finance/amount.dart](/Users/basta97/DEV/flutter/Flourish/lib/domain/finance/amount.dart)



## 8. The ledger: the app’s financial engine

### Current behavior

- A form, import or rule calls FinancialLedgerService.

- The service validates and writes related changes in a database transaction.

- Exact balances, transaction details and UI updates follow.



### Suggestions

- Keep all money mutations behind this boundary.

- Add a reconciliation diagnostic for stored balances and linked entries.



### Explanation

An expense of EGP 100 should decrease cash by EGP 100. For a credit account it increases debt. A transfer needs both legs, any fee, currency rules and reversal behavior to stay consistent. FinancialLedgerService centralizes those invariants and has operations for cash, purchases, refunds, transfers and investment activity. The architecture test scans source for unauthorized write patterns; it is useful but cannot establish semantic correctness or cover every raw SQL path. Reconciliation should compare exact current balance with opening balance plus valid ledger impacts, and report discrepancies without silently rewriting data.



### Source trail

- [lib/core/finance/financial_ledger_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/financial_ledger_service.dart)

- [lib/data/finance/finance_store.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/finance/finance_store.dart)

- [test/architecture_test.dart](/Users/basta97/DEV/flutter/Flourish/test/architecture_test.dart)

- [test/finance/ledger_test.dart](/Users/basta97/DEV/flutter/Flourish/test/finance/ledger_test.dart)



## 9. Home and monthly summaries

### Current behavior

- Home combines wealth, current-period cash flow, goals and recent activity.

- MonthlySummaryService classifies transfers and refunds consistently.



### Suggestions

- Query the current period and latest eight records directly.

- Share one cached summary between Home and phone widgets.



### Explanation

Home subscribes to transactionsProvider, which watches all transactions, even though recent activity displays eight. MonthlySummaryService filters the supplied list to the active period, batches transaction details, classifies flows and calls transactionValue per relevant entry. The screen caches its monthly future using transaction identity, reporting currency and finance revision; this already prevents some repeated work. Narrow the data source rather than removing that useful cache. Define summary keys using period, reporting currency, transaction revision, classification inputs and relevant FX state so cached numbers cannot become stale.



### Source trail

- [lib/presentation/dashboard/dashboard_screen.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/dashboard/dashboard_screen.dart)

- [lib/core/finance/monthly_summary_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/monthly_summary_service.dart)

- [lib/presentation/providers/transaction_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/transaction_providers.dart)

- [lib/presentation/home_widgets/home_widget_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/home_widgets/home_widget_runtime.dart)



## 10. Ledger and transaction entry

### Current behavior

- The Ledger filters and groups activity by date.

- Forms capture account, amount, category, merchant and payment details.

- An amount calculator is present in current local edits.



### Suggestions

- Move date, account and category filtering into SQLite.

- Paginate history and build long day groups lazily.

- Use exact arithmetic for displayed daily totals.



### Explanation

TransactionsScreen loads transactionsProvider and filters the list in Dart. _daySlivers groups matching transactions and computes daily per-currency totals with double arithmetic. A day card can contain many rows, so inspect the actual widget build cost before changing its visual structure. Prefer cursor pagination ordered by date and ID; use a separate bounded summary query when totals must cover the whole filtered result. Pagination must not turn totals into totals of only the loaded page. Amount-calculator additions are local changes observed in the working tree, not a claim that a published release contains them.



### Source trail

- [lib/presentation/transactions/transactions_screen.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/transactions/transactions_screen.dart)

- [lib/presentation/transactions/widgets](/Users/basta97/DEV/flutter/Flourish/lib/presentation/transactions/widgets)

- [lib/core/utils/amount_calculator.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/utils/amount_calculator.dart)



## 11. Accounts, cards and payment methods

### Current behavior

- Accounts hold balances and currency.

- Payment instruments describe how money was paid.

- CreditCardService derives debt, available credit and billing information.



### Suggestions

- Explain positive debt and overpayments at entry points.

- Refresh only the changed account’s credit status.

- Make reconciliation visible in account details.



### Explanation

A bank account and the debit card attached to it are different entities: one owns money and the other is a payment instrument. A wallet can also be a payment method. Credit card debt is treated as a liability, with special sign rules in the ledger. creditStatusProvider watches the broad financeChanges stream, so unrelated finance writes may recalculate card status. Narrow invalidation by account while keeping linked contract and payment changes in scope. Retain tests for credit signs, fees, refunds, statements and avoiding double-counting linked liabilities.



### Source trail

- [lib/presentation/accounts](/Users/basta97/DEV/flutter/Flourish/lib/presentation/accounts)

- [lib/presentation/payment_methods](/Users/basta97/DEV/flutter/Flourish/lib/presentation/payment_methods)

- [lib/core/finance/credit_card_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/credit_card_service.dart)

- [lib/presentation/providers/finance_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/finance_providers.dart)



## 12. Budgets, goals and categories

### Current behavior

- Budgets include child categories and period-specific limits.

- Goals allocate existing cash rather than create money.

- System categories support automatic financial entries.



### Suggestions

- Calculate matching budgets from one shared period dataset.

- Explain allocation versus transfer to users.

- Keep category reassignment and deletion consequences clear.



### Explanation

Budget calculations read all transactions, then filter by period and category ancestry. They load budget versions, parent relationships, details and valuation. With many budgets, repeated calculations can multiply reads. Build a shared period read model, index transactions by category and date, and reuse conversion context while preserving each budget’s original currency and effective version. AppDatabase.contributeToGoal checks positive allocation, available cash and non-credit accounts. Category deletion moves transactions and recurring rules to a fallback category and cleans relationships. Keep the established money semantics when optimizing.



### Source trail

- [lib/presentation/budgets/budgets_screen.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/budgets/budgets_screen.dart)

- [lib/presentation/goals/goals_screen.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/goals/goals_screen.dart)

- [lib/data/database/database.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/database/database.dart)

- [lib/presentation/categories](/Users/basta97/DEV/flutter/Flourish/lib/presentation/categories)



## 13. Wealth: holdings and obligations

### Current behavior

- Holdings track quantity, cost and valuation.

- Contracts represent scheduled payments, loans and income products.

- Confirmed activity changes money through the ledger.



### Suggestions

- Make estimated value distinct from confirmed cash.

- Query activity and schedules by holding or contract ID.

- Expose incomplete valuation and stale-price details.



### Explanation

Wealth separates assets from liabilities and distinguishes liquid balances from other wealth. PortfolioRepository.activity currently reads the whole activity collection then filters in Dart. ContractRepository.payments reads all payments for each requested contract, which compounds in reports with many contracts. Dedicated indexed fields or typed tables can reduce that cost. Expected coupons and future installments are not cash until confirmed. Preserve cost-basis arithmetic, partial-sale behavior, principal/interest separation and shared-property debt handling. Missing market values should remain visibly incomplete rather than being represented as a complete zero.



### Source trail

- [lib/presentation/wealth/holdings_view.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/holdings_view.dart)

- [lib/presentation/wealth/contracts_view.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/contracts_view.dart)

- [lib/core/finance/contract_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/contract_service.dart)

- [lib/data/finance/finance_store.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/finance/finance_store.dart)

- [lib/core/finance/valuation_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/valuation_service.dart)



## 14. Reports and currency valuation

### Current behavior

- Reports explain spending, fees, instruments and forecasts.

- ValuationService applies stored or dated conversion rates.

- Missing conversions are tracked separately.



### Suggestions

- Load the report period in one query.

- Batch transaction, account and detail reads.

- Resolve rates once per pair and effective date.



### Explanation

ReportsView._report loads all transactions before filtering to two periods. Although transaction details are prefetched, the loop calls ValuationService.transactionValue for each cash-flow transaction. That method rereads the transaction, its details and its account, and may scan FX collections. This is a confirmed repeated-read pattern; actual latency has not been measured. Introduce an explicit valuation context accepting already-loaded records and a rate lookup keyed by pair, date and override policy. Keep historical snapshot semantics, refund treatment, missing conversion counts and manual precedence identical. Do not replace exact decimal financial sums with SQL REAL sums for convenience.



### Source trail

- [lib/presentation/wealth/reports_view.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/reports_view.dart)

- [lib/core/finance/valuation_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/valuation_service.dart)

- [lib/core/finance/fx_policy.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/fx_policy.dart)



## 15. Search and currency discovery

### Current behavior

- Search uses derived SQLite documents and full-text indexes.

- Arabic normalization, amount filters and cursor pagination are implemented.

- The screen debounces input and rejects stale responses.



### Suggestions

- Preserve this architecture while optimizing elsewhere.

- Benchmark broad Arabic and short-prefix queries.

- Track backfill progress and recovery behavior.



### Explanation

SearchRepository paginates ranked document IDs before loading display metadata and returns up to 50 visible hits plus a look-ahead row. Source-table triggers keep derived search data aligned with writes, including restore paths. Query variables and quoting handle user text. FinanceRuntime starts resumable preparation in the background. The search screen uses a 150 ms debounce. Existing search benchmark fixtures cover 100,000 transactions and 10,000 additional documents, but host timings are diagnostic and are not phone performance measurements. CurrencyCatalog combines bundled, cached and discovered codes; the large catalog itself does not imply fetching every currency pair.



### Source trail

- [lib/data/search/search_repository.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/search/search_repository.dart)

- [lib/data/search/search_index.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/search/search_index.dart)

- [lib/presentation/search/search_screen.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/search/search_screen.dart)

- [lib/core/finance/currency_catalog.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/currency_catalog.dart)

- [test/search_performance_test.dart](/Users/basta97/DEV/flutter/Flourish/test/search_performance_test.dart)



## 16. Payment detection and the review inbox

### Current behavior

- Android notifications and iOS sharing/Shortcuts feed native queues.

- The local parser extracts English or Arabic payment details.

- The inbox matches, deduplicates and confirms through the ledger.



### Suggestions

- Acknowledge only successfully persisted or intentionally ignored items.

- Keep failed items for retry and show a recoverable error.

- Bound retries for permanently invalid messages.



### Explanation

Confirmed reliability concern: DetectionRuntime._drain catches exceptions around service.ingest(item.message), but then passes every item ID in the batch to bridge.ack. If ingestion fails before durable storage, the queue entry can be removed without an inbox record. Correct recovery requires successful or intentional-ignore IDs to be acknowledged, transient failures to stay queued, and poison messages to have a bounded retry/dead-letter path. Demonstrate recovery with an injected storage failure and a native queue replay; unit tests alone cannot establish platform queue durability. DetectionService already has fingerprints and review/confirmation logic, so preserve deduplication on retries.



### Source trail

- [lib/presentation/detection/detection_runtime.dart: _drain](/Users/basta97/DEV/flutter/Flourish/lib/presentation/detection/detection_runtime.dart)

- [lib/core/detection/detection_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/detection/detection_service.dart)

- [lib/core/detection/detection_bridge.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/detection/detection_bridge.dart)



## 17. File imports and optional AI

### Current behavior

- File imports build a review plan before applying records.

- CSV, spreadsheet, QIF, OFX and PDF readers support different sources.

- AI can assist unclear text, column mapping or screenshots with consent.



### Suggestions

- Show row-level reasons for rejected or ambiguous data.

- Move expensive parsing off the UI thread when measured.

- Keep local parsing first and financial confirmation deterministic.



### Explanation

ImportRowPlan and related types separate preview from application. Transfer pairing, source-specific sign conventions and duplicate handling deserve realistic fixture coverage. AI configuration uses a personal key in secure storage and host-specific automatic consent. Changing the endpoint host invalidates that consent. These are observed code behaviors, not a claim about any provider’s current pricing or retention. Suggested improvements: cap input size, handle cancellation and resume, show parse progress, validate model output against explicit schemas and keep errors actionable. Profile CSV/XLSX decoding and JSON work before choosing an isolate; database I/O already has its own background connection.



### Source trail

- [lib/core/finance/import/file_import_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/import/file_import_service.dart)

- [lib/core/finance/import](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/import)

- [lib/core/ai/ai_config.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/ai/ai_config.dart)

- [lib/core/ai/ai_client.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/ai/ai_client.dart)

- [lib/presentation/providers/ai_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/ai_providers.dart)



## 18. Privacy, lock and backups

### Current behavior

- The app uses biometric/device authentication and hides sensitive views.

- Automatic backups are encrypted with an installation key.

- Exported encrypted backups support user-controlled recovery.



### Suggestions

- Explain local backup versus portable backup clearly.

- Exercise restore on a clean installation with receipts and currencies.

- Keep raw alert text retention visible to the user.



### Explanation

SQLite is opened through NativeDatabase; no SQLCipher or equivalent database encryption is configured in this path. Biometric locking, OS protection and encrypted backups are different protections and should be described accurately. Automatic backup keys live in secure storage and local backup files are installation-bound; losing the installation key makes those backups unusable. Portable encrypted exports need a separate recovery explanation. BackupService validates restore format, schema compatibility, table references and finance payloads, then rebuilds search. Detection raw text is omitted from backup unless opted in. The review did not perform a security penetration test or independently audit native data protection.



### Source trail

- [lib/core/auth/authentication_coordinator.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/auth/authentication_coordinator.dart)

- [lib/presentation/wealth/finance_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/finance_runtime.dart)

- [lib/core/finance/backup_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/backup_service.dart)

- [lib/data/database/database.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/database/database.dart)

- [android/app/src/main/res/xml/backup_rules.xml](/Users/basta97/DEV/flutter/Flourish/android/app/src/main/res/xml/backup_rules.xml)



## 19. Background work and refresh costs

### Current behavior

- Finance changes trigger summary, snapshot, backup and reminder work.

- A one-second checkpoint debounce and a backup queue already exist.

- Market refresh caches observations and bounds historical requests.



### Suggestions

- Coalesce changes once per committed operation.

- Serialize checkpoint work and skip unchanged backups.

- Query missing FX work instead of scanning all history.



### Explanation

FinanceStore.put, remove and changeBalance emit generic financeChanges events. Broad consumers include wealth, holdings, contracts, account details and widgets. A one-second timer cancels waiting checkpoint work but cannot cancel already-running work. Backups are serialized, yet every queued backup still exports the full database and attachments and rewrites the day’s file. Propose one dirty-revision scheduler with a follow-up run if changes arrive while active. MarketDataService.refresh walks all transaction history to find missing conversions, capped at 31 historical requests; use an indexed unresolved-work query while preserving cached and historical-rate policies.



### Source trail

- [lib/data/finance/finance_store.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/finance/finance_store.dart)

- [lib/presentation/providers/finance_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/finance_providers.dart)

- [lib/presentation/wealth/finance_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/finance_runtime.dart)

- [lib/core/finance/backup_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/backup_service.dart)

- [lib/core/finance/market_data_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/market_data_service.dart)



## 20. UI, motion and accessibility

### Current behavior

- Shared theme, spacing and motion keep screens consistent.

- English and Arabic localization support RTL layouts.

- Amount privacy and locale changes force a full-tree rebuild.



### Suggestions

- Replace global formatter state with scoped reactive inputs.

- Profile blur and long lists before reducing visual quality.

- Plan layouts that support text beyond the current 1.3× cap.



### Explanation

FlourishApp.rebuildAll recursively marks the element tree dirty after amount privacy changes and some locale changes because formatting also uses global static state. It is intentional for correctness, but broad. Introduce a scoped money-format context so only consumers rebuild, then exercise every money-bearing surface including sheets, search and widgets to avoid privacy regressions. The app clamps text scaling to 1.3, an explicit limit worth revisiting with accessible layouts. There are existing large-text and motion tests. Visual cost hypotheses need frame traces; do not assume every animation is slow or remove all effects.



### Source trail

- [lib/app.dart](/Users/basta97/DEV/flutter/Flourish/lib/app.dart)

- [lib/core/utils/currency_formatter.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/utils/currency_formatter.dart)

- [lib/core/motion/motion.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/motion/motion.dart)

- [lib/shared/widgets](/Users/basta97/DEV/flutter/Flourish/lib/shared/widgets)

- [test/widgets/large_text_layout_test.dart](/Users/basta97/DEV/flutter/Flourish/test/widgets/large_text_layout_test.dart)

- [Official Flutter guidance](https://docs.flutter.dev/perf/best-practices)



## 21. Performance priorities

### Current behavior

- 1  Stop loading whole history for bounded views.

- 2  Remove repeated per-entry valuation reads.

- 3  Reduce broad invalidations and repeated checkpoints.



### Suggestions

- Keep financial results identical before and after.

- Measure query count, latency, memory and dropped frames.

- Avoid speculative caching without an invalidation policy.



### Explanation

Priority is based on code structure and likely scaling impact, not measured speedups. Query bounding reduces data transferred and materialized; batching valuation reduces database round trips; scoped refresh reduces work after unrelated changes. Existing strengths to preserve: background SQLite execution, WAL and indexes, batch detail reads, debounced indexed search, cached report futures, bounded FX requests and serialized backup writes. After each focused change compare exact values on mixed-currency transfers, refunds, fees, month boundaries and missing data. A faster wrong financial result is unacceptable.



### Source trail

- [lib/presentation/providers/transaction_providers.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/providers/transaction_providers.dart)

- [lib/core/finance/valuation_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/valuation_service.dart)

- [lib/presentation/wealth/finance_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/wealth/finance_runtime.dart)

- [Official Flutter guidance](https://docs.flutter.dev/perf/best-practices)

- [Official Flutter guidance](https://docs.flutter.dev/perf/ui-performance)



## 22. A measurement plan for real phones

### Current behavior

- Profile a representative physical Android and iPhone.

- Use small, medium and large synthetic finance datasets.

- Exercise launch, save, scroll, reports, import and restore.



### Suggestions

- Record a baseline before choosing numerical targets.

- Compare p50/p95 latency, database calls and peak memory.

- Re-run the same flow after each change.



### Explanation

Suggested datasets, not current measured user data: 1k, 10k and 100k transactions; multiple accounts, cards, currencies, refunds, linked transfers and dense single-day history. Include cold and warm startup, opening a month, typing Arabic and English searches, changing reporting currency, importing a large file, refreshing unavailable feeds and exporting with receipt attachments. Use profile mode on physical devices for frame and memory measurements. The 60 Hz frame interval is about 16.7 ms; 120 Hz is about 8.3 ms, not an observed result for Flourish. Define product-specific latency targets after a baseline and device tier are agreed.



### Source trail

- [test/support/search_benchmark.dart](/Users/basta97/DEV/flutter/Flourish/test/support/search_benchmark.dart)

- [Official Flutter guidance](https://docs.flutter.dev/perf/ui-performance)

- [Official Flutter guidance](https://docs.flutter.dev/tools/devtools/performance)



## 23. A practical implementation sequence

### Current behavior

- First: queue recovery and reconciliation safeguards.

- Next: period queries and batched valuation.

- Then: scoped refresh and checkpoint scheduling.



### Suggestions

- Follow with typed hot-path collections and simpler boundaries.

- Finish by updating documentation and device benchmarks.

- Ship small changes with comparison evidence.



### Explanation

Suggested sequence rather than a committed delivery estimate. Stage 1 acceptance: failed ingestion survives and succeeds on replay without duplication; reconciliation detects injected discrepancies. Stage 2: report/home/budget totals match the baseline fixture exactly while query counts no longer grow per entry. Stage 3: one logical edit produces the intended scoped refresh and one serialized checkpoint cycle. Stage 4: migrate only a demonstrated bottleneck, preserve rollback and old backups. Update docs to reflect actual paths and root routes. Treat the old October audit as historical: its status section marks many issues done, so do not re-report the original list as current defects.



### Source trail

- [docs/AUDIT.md](/Users/basta97/DEV/flutter/Flourish/docs/AUDIT.md)

- [docs/ARCHITECTURE.md](/Users/basta97/DEV/flutter/Flourish/docs/ARCHITECTURE.md)

- [lib/presentation/detection/detection_runtime.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/detection/detection_runtime.dart)

- [lib/core/finance/valuation_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/valuation_service.dart)



## 24. How to explore and change the project

### Current behavior

- Start with main.dart, app.dart and app_router.dart.

- Follow one screen through its provider to the ledger or read service.

- Then inspect storage, fixtures and platform bridges.



### Suggestions

- Put business rules in services and exact finance types.

- Keep screens focused on interaction and presentation.

- Add abstractions only where they clarify a real boundary.



### Explanation

Suggested first exercise: trace an expense from AddTransactionSheet into recordPurchase or recordCash, then exact balance and transaction_details updates, then the subscribed screens. Next trace a transfer and its fee/reversal. Finally trace a captured native message through queue, parser, inbox and confirmation. This explains the difference between input, proposed financial activity and committed ledger activity. Read .g.dart files only for debugging generated behavior; author schema changes in database.dart and table declarations, then regenerate. Preserve existing local work and keep optimization commits narrow enough to compare outcomes.



### Source trail

- [lib/main.dart](/Users/basta97/DEV/flutter/Flourish/lib/main.dart)

- [lib/app.dart](/Users/basta97/DEV/flutter/Flourish/lib/app.dart)

- [lib/core/router/app_router.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/router/app_router.dart)

- [lib/presentation/transactions/widgets/add_transaction_sheet.dart](/Users/basta97/DEV/flutter/Flourish/lib/presentation/transactions/widgets/add_transaction_sheet.dart)

- [lib/core/finance/financial_ledger_service.dart](/Users/basta97/DEV/flutter/Flourish/lib/core/finance/financial_ledger_service.dart)

- [lib/data/database/database.dart](/Users/basta97/DEV/flutter/Flourish/lib/data/database/database.dart)



## 25. Review evidence and remaining work

### Current behavior

- Static analysis: no issues found.

- Focused checks: 102 tests passed.

- iOS simulator: template → transaction → edit passed.



### Suggestions

- Performance costs are code-based hypotheses.

- Physical-device profiling and native failure recovery remain open.

- Tests support specific scenarios; they do not prove the whole app.



### Explanation

Checks selected for this review: architecture guard; ledger arithmetic, transfers, recurring and valuation; migration/backup; search repository; parser fixtures; AI consent. flutter analyze completed successfully. Focused checks passed 102 tests; Drift warnings about multiple test database instances appeared and should be assessed as fixture lifecycle noise rather than silently treated as proof of a production race. The existing usability_flow_test passed on the iOS simulator, exercising Home → Tools → template presets → reviewed transaction → edit with the real application and local database. This is integration evidence for that flow, not physical-device performance evidence. No percentage speedup, production readiness or full security verification is claimed.



### Source trail

- Review commands run 28 October 2026

- [test/architecture_test.dart](/Users/basta97/DEV/flutter/Flourish/test/architecture_test.dart)

- [test/finance/ledger_test.dart](/Users/basta97/DEV/flutter/Flourish/test/finance/ledger_test.dart)

- [test/finance/migration_backup_test.dart](/Users/basta97/DEV/flutter/Flourish/test/finance/migration_backup_test.dart)

- [test/search_repository_test.dart](/Users/basta97/DEV/flutter/Flourish/test/search_repository_test.dart)

- [test/detection/parser_fixtures_test.dart](/Users/basta97/DEV/flutter/Flourish/test/detection/parser_fixtures_test.dart)

- [test/ai/ai_consent_test.dart](/Users/basta97/DEV/flutter/Flourish/test/ai/ai_consent_test.dart)



## Recommended first changes

1. Fix queue acknowledgment so failed ingestion survives. Test a transient failure followed by replay at the native queue boundary.

2. Create bounded transaction queries for Home, Ledger, Reports and Budgets. Preserve date boundaries and totals across pagination.

3. Add a batched valuation context using exact amounts and dated conversion rules. Compare totals on realistic mixed-currency fixtures.

4. Replace generic refresh triggers with committed, scoped revisions. Coalesce snapshot, backup and widget work.

5. Establish device baselines before choosing numerical performance targets.

## Verification record

- STATIC CHECKS PASSED: `flutter analyze` reported no issues.

- UNIT / WIDGET TESTED: 102 selected checks passed across architecture, ledger, migrations and backups, search, parser fixtures and AI consent. Drift emitted warnings about multiple database test instances.

- INTEGRATION TESTED: existing `integration_test/usability_flow_test.dart` passed on the iOS simulator. It exercises Home → Tools → template presets → reviewed transaction → edit.

- Not exercised here: physical Android notification ingestion, physical iOS Shortcuts capture, real biometric hardware, clean-install backup recovery or physical-device frame and memory profiling.

- No app feature changes were implemented as part of this review. Existing uncommitted changes were left in place.