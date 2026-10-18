# Master prompt — smart detection, AI categories and universal import

Reusable brief for an AI coding agent working on Flourish's detection and
import features. Paste it as the task, then name the phase to work on.

---

You are a senior Flutter engineer working on **Flourish**, a personal-finance
app (Flutter, Riverpod 2.6 hand-written providers, Drift/SQLite, `FinanceStore`
JSON collections, `FinancialLedgerService` as the only write path for money).
Read `docs/ARCHITECTURE.md`, `docs/FINANCE_IMPLEMENTATION.md` and
`docs/AUDIT.md` first and match the existing code style.

**Where things live**

- Parsing: `lib/core/detection/payment_parser.dart` (+ `lexicon.dart`,
  `issuers.dart`, `normalizer.dart`) → `ParsedPayment`.
- Pipeline: `DetectionService` (`ingest` → account/card match → duplicate
  checks → category → `detected_payments` row; `confirm` books through the
  ledger). Review UI: `/inbox`. Paste/share/OCR: `/smart-import`.
- AI (optional): `lib/core/ai/` — OpenAI-compatible `AiClient`,
  `AiPaymentAssist` (validated merge, cache, usage), `Redactor`, versioned
  `AiPrompts`. Settings: `/settings/ai`.
- Categories: merchant rules (`merchantRules`) → AI pick/proposal →
  `CategorySuggester` (history + keywords) → `CategoryConcepts` →
  fallback. `CategoryResolver` dedups near-identical names and creates
  proposals (`CategoryResolver.ensure`) only on confirm.
- File import: `lib/core/finance/import/` parsers (OFX/QFX, QIF, app CSV
  presets, PDF statements) → `FileImportService.plan` (account map, category
  decisions, FITID/row keys, possible duplicates) → `ImportReviewScreen` →
  `apply` (one DB transaction, `sourceRef` = batch id) → `undo`.
- PDF statements: `PdfTextReader` (pdfrx/pdfium text layer with word
  positions) → `PdfStatementParser` (header columns by x position, running
  balance as the tie-breaker) → `AiStatementReader` only when the table
  heuristic finds nothing (page chunks, `Redactor`, amount must be printed
  on the page). Fixtures: `tool/make_statement_pdfs.dart`.
- Screenshots: on-device OCR over `flourish/imports` (iOS Vision `ar-SA` +
  `en-US`; Android ML Kit Latin). Android can opt in to
  `AiScreenshotReader` (image sent to a vision model, after a disclosure;
  `AiSettings.screenshotOcr`).

**Non-negotiables**

1. Money is `Amount`/`Decimal`, never `double`, in new code. All writes go
   through the ledger inside a DB transaction.
2. The on-device parser always runs first and the app works fully without
   AI. AI only sees messages the parser is unsure about, or ones the person
   asks about.
3. Redact before any network call: stored-text redaction (`redact`) plus
   `Redactor` (emails, IBANs, phones, long account numbers; keep card last 4
   and the amount).
4. AI output is strict JSON validated in Dart: the amount must appear in the
   message, enums must be known, category ids must exist. Cache by message
   fingerprint and prompt version.
5. Never create data silently: new categories, accounts and duplicates are
   shown in review and created on confirm.
6. Every bug fix gets a named regression test (`test/detection/
   parser_regression_test.dart`); every format gets fixture tests.
   `flutter analyze` clean and `flutter test` green before finishing.

**Open phases**

- "Let AI decide" for categories not in Flourish during file import.
- Verify the five app CSV presets built from third-party docs against real
  exports, and the PDF heuristic against real bank statements (Egyptian
  banks, Arabic layouts).
- Scanned PDFs: today they get a "needs a text PDF" message; OCR of the
  rendered pages (Vision / ML Kit, or the AI vision path) is not built.

**Done**

- PDF statements (2026-10-18): pdfrx 2.4.7 text extraction, table
  heuristic, AI page-chunk fallback, password prompt, scanned-PDF message.
- Arabic OCR (2026-10-18): iOS Vision `["ar-SA", "en-US"]` where supported
  (app and share extension); Android opt-in AI vision fallback.

Work phase by phase. After each, run `flutter analyze` and `flutter test`,
summarise what changed and list remaining risks before continuing.
