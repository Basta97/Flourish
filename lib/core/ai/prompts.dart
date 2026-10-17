/// Versioned prompts. Bump the version when changing wording so cached
/// replies from an older prompt are not reused.
class AiPrompts {
  AiPrompts._();

  static const extractionVersion = 'tx-v1';

  static String extractionSystem(Iterable<String> icons) =>
      '''
You read bank, card and wallet SMS / push notifications (English or Arabic) and extract the transaction. Reply with one JSON object only: {"results": [...]}, one result per input message, same "i".

Each result:
{"i": int,
 "is_transaction": bool,
 "kind": "purchase"|"refund"|"atm"|"transfer_in"|"transfer_out"|"salary"|"fee"|"declined"|"otp"|"promo"|"payment_due"|"balance_only",
 "type": "expense"|"income",
 "amount": "1250.50" (string, copied from the message, no thousands separators) or null,
 "currency": ISO 4217 code or null,
 "date": "YYYY-MM-DD" or null,
 "merchant": shop or counterparty name, cleaned (no card/account numbers, no "POS", no city) or null,
 "category": {"existing_id": int} or {"new": {"name": "Title Case, 1-3 words, generic", "icon": one of ICONS, "parent": existing category name or null}},
 "confidence": 0..1}

Rules:
- One-time codes, declined/failed payments, offers/promotions, payment-due reminders and balance-only notices: is_transaction=false.
- Never invent or compute an amount; it must appear in the message. Ignore balances, limits, card and reference numbers.
- Refunds, reversals, salaries and incoming transfers are income.
- Choose an existing category whenever one reasonably fits. Propose "new" only when none fits; name it generically ("Groceries", "Pets", "Pharmacy" — never the merchant name) and give a parent when an existing category is broader.
- "[email]", "[phone]", "****1234" are redactions; ignore them.

ICONS: ${icons.join(', ')}

Example input: {"today":"2026-10-17","categories":[{"id":2,"name":"Food & Drinks","type":"expense"},{"id":9,"name":"Other","type":"expense"}],"messages":[{"i":0,"text":"POS purchase EGP 1,250.50 at SPINNEYS ZAYED card ****4521 on 15/10"},{"i":1,"text":"رمز التحقق 482913 لعملية دفع بقيمة 300 جنيه"}]}
Example output: {"results":[{"i":0,"is_transaction":true,"kind":"purchase","type":"expense","amount":"1250.50","currency":"EGP","date":"2026-10-15","merchant":"Spinneys","category":{"new":{"name":"Groceries","icon":"local_grocery_store","parent":"Food & Drinks"}},"confidence":0.93},{"i":1,"is_transaction":false,"kind":"otp","type":"expense","amount":"300","currency":"EGP","date":null,"merchant":null,"category":{"existing_id":9},"confidence":0.9}]}''';

  static const columnMappingVersion = 'map-v1';

  static const columnMappingSystem = '''
You map the columns of a spreadsheet exported from a finance app or bank to Flourish fields. Reply with one JSON object only:
{"columns": {"date": int|null, "type": int|null, "account": int|null, "category": int|null, "amount": int|null, "currency": int|null, "note": int|null, "destination": int|null},
 "date_format": ICU pattern such as "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "dd.MM.yyyy HH:mm",
 "decimal_separator": "." or ",",
 "signed_amounts": true when expenses are negative numbers in the amount column,
 "income_values": [values of the type column meaning income],
 "expense_values": [values meaning expense],
 "transfer_values": [values meaning transfer]}
Columns are 0-based indexes into the header. Use null when a field is absent. If the file has separate debit and credit columns, map "amount" to the debit column, put the credit column index in "credit", and set signed_amounts false.''';

  static const statementVersion = 'stmt-v1';

  static const statementSystem = '''
You extract transactions from the text of a bank or card statement page. Reply with one JSON object only:
{"rows": [{"date": "YYYY-MM-DD", "description": string, "amount": "123.45" (positive, copied from the text), "type": "expense"|"income", "currency": ISO code or null}]}
Skip opening/closing balances, totals, headers, page numbers and running-balance columns. Debits/withdrawals are expenses; credits/deposits are income. Never invent rows or amounts.''';
}
