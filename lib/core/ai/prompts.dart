/// Versioned prompts. Bump a version when changing its wording so cached
/// replies from the older prompt are not reused.
class AiPrompts {
  AiPrompts._();

  static const paymentVersion = 'pay-v1';

  static String paymentSystem(Iterable<String> icons) =>
      '''
You read bank, card and wallet SMS / push notifications (English or Arabic, often Egyptian banks) and extract the payment. Reply with one JSON object only: {"results": [...]}, one result per input message, same "i".

Each result:
{"i": int,
 "ignore": null | "otp" | "declined" | "promo" | "notice" (statements, due-date reminders, balance-only),
 "kind": "purchase"|"withdrawal"|"transfer_out"|"transfer_in"|"deposit"|"refund"|"bill_payment"|"card_payment"|"fee" or null,
 "direction": "expense"|"income",
 "amount": "1250.50" (string, copied from the message, no thousands separators) or null,
 "currency": ISO 4217 code or null,
 "date": "YYYY-MM-DD" or null,
 "merchant": shop name, cleaned (no card/account numbers, no "POS", no city) or null,
 "counterparty": person or account for transfers, or null,
 "category": {"existing_id": int} or {"new": {"name": "Title Case, 1-3 words, generic", "icon": one of ICONS, "parent": existing category name or null}} or null for transfers,
 "confidence": 0..1}

Rules:
- Never invent or compute an amount; it must appear in the message. Ignore balances, limits, card numbers and reference numbers.
- Refunds, salaries, deposits and incoming transfers are income.
- Prefer an existing category whenever one reasonably fits. Propose "new" only when none fits; name it generically ("Groceries", "Pets", "Pharmacy" — never the merchant) and give a parent when an existing category is broader.
- "[email]", "[phone]", "[CODE]", "****1234" are redactions; ignore them.

ICONS: ${icons.join(', ')}

Example input: {"today":"2026-10-17","categories":[{"id":2,"name":"Food & Drinks","type":"expense"},{"id":9,"name":"Other","type":"expense"}],"messages":[{"i":0,"text":"POS SPINNEYS ZAYED 1,250.50 EGP card ****4521 15/10"},{"i":1,"text":"رمز التحقق [CODE] لعملية دفع بقيمة 300 جنيه"}]}
Example output: {"results":[{"i":0,"ignore":null,"kind":"purchase","direction":"expense","amount":"1250.50","currency":"EGP","date":"2026-10-15","merchant":"Spinneys","counterparty":null,"category":{"new":{"name":"Groceries","icon":"local_grocery_store","parent":"Food & Drinks"}},"confidence":0.93},{"i":1,"ignore":"otp","kind":null,"direction":"expense","amount":null,"currency":null,"date":null,"merchant":null,"counterparty":null,"category":null,"confidence":0.95}]}''';

  static const columnsVersion = 'map-v1';

  static const columnsSystem = '''
You map the columns of a spreadsheet exported from a finance app or bank to Flourish fields. Reply with one JSON object only:
{"columns": {"date": int|null, "type": int|null, "account": int|null, "category": int|null, "amount": int|null, "currency": int|null, "note": int|null, "destination": int|null},
 "date_format": ICU pattern such as "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "dd.MM.yyyy HH:mm",
 "decimal_separator": "." or ",",
 "signed_amounts": true when expenses are negative numbers in the amount column and there is no income/expense column}
Columns are 0-based indexes into "header". Use null when a field is absent. "type" is a column whose values say income, expense or transfer. "destination" is the receiving account of transfers. Rows in "sample" may be partly masked; never invent columns.''';
}
