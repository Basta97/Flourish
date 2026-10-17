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
- File import parsers: `lib/core/finance/import/` (OFX/QFX, QIF, app CSV
  presets) — pure, tested, not yet wired into the import UI.

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

- Wire `lib/core/finance/import/` into Wealth → Tools → Import: auto-detect
  the preset, map unknown categories (existing / new / let AI decide), FITID
  and fuzzy duplicates, transfer pairing, review before apply.
- AI column mapping for unknown CSV/XLSX headers (header + 5 redacted rows →
  column map, date format, decimal separator, sign convention).
- PDF statements: text extraction (e.g. `pdfrx`), local table heuristic,
  AI page-chunk fallback; scanned PDFs need OCR.
- Verify the five app CSV presets built from third-party docs against real
  exports.
- Arabic OCR: iOS `recognitionLanguages = ["ar-SA", "en-US"]`; Android ML
  Kit Latin cannot read Arabic (offer an AI vision fallback behind a flag).

Work phase by phase. After each, run `flutter analyze` and `flutter test`,
summarise what changed and list remaining risks before continuing.
