# Flourish finance and holdings implementation

The app remains local-first. SQLite schema 9 extends the original Drift tables with exact account balances, immutable transaction conversion metadata and versioned financial records (v6), cards and wallets with payment details on every entry (v7), detected payments awaiting review (v8), and rebuildable local FTS5 search indexes (v9).

## Available flows

- Home shows known assets, liabilities, net worth, liquid balances, and current-month cash activity. Missing prices/rates qualify totals as incomplete.
- Ledger provides month/day/calendar history, date ranges, search, account/category/type filtering, and original-currency daily totals.
- Accounts supports editing, institutions, groups, archiving, exclusion from totals, and audited reconciliation through Manage account or Tools (Home or Settings).
- Wealth → Holdings supports opening positions, purchases, sales, fees, distributions, splits, custody/quantity/cost adjustments, manual resale quotes, and resuming automatic feeds. Gold is measured in grams and records karat. Property and other shared holdings apply the entered ownership fraction. Property details can link an existing mortgage; its liability is included once globally.
- Wealth → Obligations supports certificates/deposits, fixed loans, receivables, manually agreed schedules, credit billing, installments, early settlements, confirmation, and reversal. Expected payments never change cash. Original schedules can be restored by reversing an early settlement.
- Wealth → Reports shows historical cash activity, category rollups, income sources, allocation, currency exposure, recorded net-worth history, separate asset-price/FX gains, realized gains, and a scheduled-cash-flow forecast.
- Tools (Home or Settings) provides dated FX overrides, account management, templates, subcategories, receipts, reporting month start, reminders, device-auth locking, optional secure stock-feed credentials, encrypted backups, local backup history, CSV/XLSX import, and CSV export.
- Cards & wallets: every bank, wallet or credit account can hold its debit/credit/prepaid cards, mobile wallets, InstaPay address or BNPL line (network, last 4, bank or wallet, FX fee). Entries record what paid (card or method), the merchant and where they came from (manual, recurring, detected…).
- Spending in another currency: the add sheet records the price in the original currency and what the account was charged, with the card's foreign-transaction fee booked as a linked "Bank fees" entry. Refunds are filed under the expense category they reverse.
- Credit cards: limit, purchase and cash-advance APR, statement and due days, minimum payment (% and floor) and fees live on the card. The account page shows available credit, how much of the limit is used, the last statement, what is still unpaid, the minimum due, an interest estimate and cash advances, with Pay card and "Interest or fee". Withdrawing cash from a card is a cash advance with its fee.
- Payment detection: bank SMS and bank/wallet app alerts (Android notification listener) or Shortcuts automations (iOS) feed a review inbox. See "Payment detection" below.
- Settings retains legacy JSON restoration and exports the complete new backup format. Goal and recurring-payment creation and budget editing are reachable. Budgets support current and past periods with retained limit changes.

## Financial rules

`Amount` wraps Decimal; money, quantities, prices, and rates are stored as decimal text. Existing REAL account balances remain a display/compatibility projection. All new account/holding mutations use the central ledger service. Transfer legs, fees, and contract payment components are protected as linked operations.

Opening holdings do not move cash. New funded contracts explicitly move principal when requested. Purchases and principal movements are excluded from spending; fees and interest remain in income/expense reporting. Weighted-average cost is used for management reporting, not tax filing. Unknown opening cost stays unknown. Enter holding changes in chronological date order; use an audited adjustment to reconcile an existing position.

Changing the reporting currency never rewrites the original amounts. Transaction-date rates and acquisition conversions are retained once available. Historical conversions that cannot be sourced remain incomplete. Legacy budgets have no stored currency and therefore require explicit confirmation through Edit before conversion.

Rates and prices show source and effective date. A manual quote remains authoritative until explicitly cleared. Missing values are not zero valuations. Net-worth history starts with recorded observations rather than fabricated past appraisals.

Every balance change goes through `FinancialLedgerService` (enforced by `test/architecture_test.dart`), including recurring rules, auto-income and undo. `TransactionClassifier` is the single rule for what counts as income, spending, refund, transfer, investment or principal; system categories (`SystemCategories`) are identified by a stored key and cannot be deleted or picked by hand when hidden. A dated conversion only uses a rate from within 7 days before the entry (`FxPolicy`); older snapshots are re-checked by `LedgerMaintenance`. Amounts are parsed by `AmountParser` (Arabic-Indic digits, comma or dot decimals, each currency's minor unit) and the ledger refuses an amount entered in a currency other than the account's.

## Payment detection

`lib/core/detection/` parses Egyptian bank and wallet messages in English and Arabic (`PaymentMessageParser`): amount and currency (EGP, LE, ج.م, جنيه, and foreign currencies by code, symbol or Arabic name: USD, US$, دولار, EUR, SAR, ريال, AED, GBP, TRY, THB…), the charged amount of foreign purchases, fees, card last 4, merchant or counterparty, date, balance and reference. Numbers only count as money next to a currency or amount word, so dates, phone numbers, card digits and balances are not mistaken for the payment; OTP, declined, promotional and statement messages are ignored. Messages are redacted before storage (card numbers to last 4, national IDs, codes, phone numbers).

`DetectionService` stores each message once (fingerprint), treats the SMS and app alert of one payment as one, matches the card by its last 4 digits (then the bank's only account), suggests a category from the person's earlier choice for that merchant, and flags payments already entered by hand. A foreign-currency payment uses the bank's own figure in the account currency when the message gives one; otherwise it is converted at that day's exchange rate (through USD when there is no direct rate) and the card's foreign-transaction fee is booked on top, marked as an estimate, and the inbox shows it before confirming. With no usable rate the person enters the charged amount. Confirming books purchases (including foreign ones), refunds, ATM withdrawals into cash, transfers and card payments through the ledger. Optional automatic adding is limited to purchases and refunds from a recognised bank on a saved card with no doubt or possible duplicate, and never uses an exchange-rate estimate. Message text is kept for the chosen retention period and excluded from backups unless the person opts in. Parser fixtures are synthetic; extend `test/detection/parser_fixtures_test.dart` with redacted real messages.

## Feeds and offline behavior

- Frankfurter v2: daily reference FX, including EGP. These are reference values rather than a bank's executable bid/ask.
- Gold API: USD XAU spot converted from troy ounces to grams, adjusted for karat. This is an estimate; local resale quotes are entered manually.
- Coinbase: supported crypto/USD spot pairs.
- Alpha Vantage: optional personal key in platform secure storage, verified ticker currency, end-of-day quotes, and a persisted daily request allowance. No key is bundled.
- EGX, unsupported funds/tokens, property, and custom appraisals accept dated manual quotes.

Refresh runs on opening/resume when cached retrievals are older than 24 hours, with a manual refresh action. Missing historical FX is backfilled in bounded batches of at most 31 requests per refresh. Failed requests retain cached values. Observations over 72 hours old show an age warning; weekends and holidays can legitimately produce this warning.

## Protection and portability

Device authentication uses the operating system's biometric/passcode facilities; it does not add a second custom password database. Android receives shared text/images and uses bundled ML Kit Latin OCR. iOS uses Apple Vision. Imported transactions require review; potential duplicate amounts are flagged, and images are retained only when explicitly attached.

Encrypted exports use AES-256-GCM with PBKDF2-HMAC-SHA256 (210,000 iterations), independent random salt/nonce, and authenticated decryption. API credentials are excluded. Automatic backups retain seven daily files inside the app's private documents directory; they do not survive deleting the app/device. Restore validates schema, foreign keys, financial record references, and exact values before committing. Spreadsheet imports preview mapped rows, reject invalid input atomically, and persist duplicate fingerprints. Import explicitly selects signed-bank versus typed amounts and the decimal separator; ambiguous negative amounts are rejected rather than silently reversing their meaning.

Money Manager CSV/XLSX columns can be mapped, including account, category, type, amount, currency, date, note, and destination. Legacy binary XLS is not accepted. Cross-currency spreadsheet transfers need manual entry because an exported amount alone does not establish both actual currency legs.

## Verification

Run:

```sh
dart format --set-exit-if-changed lib test integration_test
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub
flutter --no-version-check test integration_test/finance_flow_test.dart -d <isolated-simulator-id>
flutter --no-version-check build apk --debug
```

The simulator integration scenario creates an account and holding through the actual UI, buys additional units with a fee, confirms a coupon, opens reports, then reopens the real SQLite database to check persistence. Run it on a dedicated test installation: it adds timestamped QA records.

Android release signing requires the owner's keystore and `android/key.properties` (see `android/key.properties.example`). Release builds explicitly reject absent credentials rather than using debug signing. App Store distribution likewise requires the owner's signing/provisioning configuration. No signing identities were created or published.

Device-auth dialogs, scheduled-notification delivery, share extensions, OCR, the Android notification listener and the iOS Shortcuts automations still require targeted physical-device acceptance checks; an iOS simulator workflow does not prove those capabilities on every device.

## Transaction templates

Tools → Transaction templates supports create, edit, delete, and Use template. The Add menu and income/expense forms also offer Use template. Each template has 1–3 positive amount presets, a type, account, category, and optional note. Choose one preset and review/edit a single ordinary transaction before saving. Saving a template does not move money.

The `templates` finance collection stores exact decimal-string `amounts`; legacy `amount` records are read as one preset and rewritten on save. Backups accept both formats. Confirmed applications use the standard ledger (`source=template`, `sourceRef=template ID`), so balance updates, normal editing/deletion, and reporting are preserved even after the template is changed or deleted. Missing/archived accounts and invalid categories require correction before recording.

Device authentication shares one coordinator between unlocking and lock settings. Native prompt lifecycle events do not start another prompt; cancellation leaves an explicit retry control. Genuine backgrounding covers the app immediately and locks it while keeping navigation and drafts mounted.

## App-wide search and currencies

Search is available from Home, Ledger, Accounts, Wealth, Tools, Settings and Budgets. `/search` searches transactions, accounts, categories, templates, goals, budgets, holdings, obligations and app feature routes locally. Arabic variants, diacritics and Arabic/Persian digits are normalized. One/two character queries match word prefixes; longer terms match fragments. Quoted phrases match contiguous text within a field. Transaction refinements select transaction scope; amount limits use exact original-account amounts in the selected currency without conversion.

`SearchRepository` returns typed pages of 50 results with stable relevance/date/row cursors. FTS5 word/prefix and trigram indexes are maintained by SQLite triggers, including permitted JSON collections and transaction-detail currency changes. Account/category names are indexed once and expanded through indexed relationships. Backfill checkpoints resume in 500-row batches; app database work runs on a background isolate. Search tables are derived and excluded from backups; restore rebuilds them inside the same transaction. Raw messages, attachments, credentials and provider caches are excluded.

Tools → Exchange rates (`/exchange-rates`) provides searchable currencies, conversion, favorites, rate dates/freshness, dated manual overrides and resume-automatic controls. The active Frankfurter catalog is cached for seven days with a bundled offline copy. Account, reporting-currency, transaction and Wealth currency selectors share the picker. Existing historical codes remain selectable when already saved. Minor units use bundled SIX ISO 4217 metadata, including 0/3/4-digit currencies.

Requested/favorite pairs and currencies actually used by finances are refreshed in per-base batches, with request deduplication and a 24-hour automatic cache. The full currency catalog never becomes the startup fetch universe. Current effective rates prefer a usable manual override (including inverse pairs), then automatic direct/inverse observations. Conversion divides by the original inverse observation to avoid reciprocal rounding drift. Provider reference rates remain visible beside manual overrides. Neither browsing nor conversion rewrites booked transaction snapshots. Rate availability varies by pair/date; failures retain cached observations and show freshness.
