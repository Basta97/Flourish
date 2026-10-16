/// Words and symbols found in Egyptian bank and wallet messages, in the
/// folded form produced by MessageNormalizer.fold (lower case; أإآ→ا, ى→ي,
/// ة→ه).
class Lexicon {
  Lexicon._();

  /// Currency spellings, longest first so "جنيه استرليني" wins over "جنيه".
  static const currencies = <(String, String)>[
    ('جنيه استرليني', 'GBP'),
    ('جنيه مصري', 'EGP'),
    ('دولار امريكي', 'USD'),
    ('ريال سعودي', 'SAR'),
    ('ريال قطري', 'QAR'),
    ('دينار كويتي', 'KWD'),
    ('درهم اماراتي', 'AED'),
    ('دولار كندي', 'CAD'),
    ('دولار استرالي', 'AUD'),
    ('ريال عماني', 'OMR'),
    ('دينار بحريني', 'BHD'),
    ('دينار اردني', 'JOD'),
    ('ليره تركيه', 'TRY'),
    ('فرنك سويسري', 'CHF'),
    ('ين ياباني', 'JPY'),
    ('يوان صيني', 'CNY'),
    ('درهم مغربي', 'MAD'),
    ('l.e.', 'EGP'),
    ('l.e', 'EGP'),
    ('ج.م.', 'EGP'),
    ('ج.م', 'EGP'),
    ('ج م', 'EGP'),
    ('جنيها', 'EGP'),
    ('جنيه', 'EGP'),
    ('جم', 'EGP'),
    ('egp', 'EGP'),
    ('le', 'EGP'),
    ('e£', 'EGP'),
    ('us\$', 'USD'),
    ('ca\$', 'CAD'),
    ('a\$', 'AUD'),
    ('cn¥', 'CNY'),
    ('usd', 'USD'),
    ('دولار', 'USD'),
    ('\$', 'USD'),
    ('eur', 'EUR'),
    ('€', 'EUR'),
    ('يورو', 'EUR'),
    ('gbp', 'GBP'),
    ('£', 'GBP'),
    ('sar', 'SAR'),
    ('ر.س', 'SAR'),
    ('ريال', 'SAR'),
    ('aed', 'AED'),
    ('د.ا', 'AED'),
    ('درهم', 'AED'),
    ('kwd', 'KWD'),
    ('د.ك', 'KWD'),
    ('qar', 'QAR'),
    ('bhd', 'BHD'),
    ('omr', 'OMR'),
    ('jod', 'JOD'),
    ('ر.ع', 'OMR'),
    ('د.ب', 'BHD'),
    ('try', 'TRY'),
    ('₺', 'TRY'),
    ('cny', 'CNY'),
    ('jpy', 'JPY'),
    ('¥', 'JPY'),
    ('cad', 'CAD'),
    ('aud', 'AUD'),
    ('chf', 'CHF'),
    ('sek', 'SEK'),
    ('nok', 'NOK'),
    ('dkk', 'DKK'),
    ('sgd', 'SGD'),
    ('hkd', 'HKD'),
    ('nzd', 'NZD'),
    ('inr', 'INR'),
    ('₹', 'INR'),
    ('myr', 'MYR'),
    ('thb', 'THB'),
    ('zar', 'ZAR'),
    ('mad', 'MAD'),
    ('tnd', 'TND'),
    ('krw', 'KRW'),
    ('rub', 'RUB'),
    ('brl', 'BRL'),
    ('mxn', 'MXN'),
  ];

  /// Messages that are not payments at all.
  static final otp = RegExp(
    r'\botp\b|one[- ]time|verification code|passcode|security code|'
    r'activation code|do not share|don.t share|رمز التحقق|كود التحقق|'
    r'رمز التفعيل|كلمه المرور لمره واحده|كلمه سر|لا تشارك|لا تفصح',
  );
  static final declined = RegExp(
    r'declined|rejected|insufficient|unsuccessful|was not (completed|processed)|'
    r'\bfailed\b|could not be|مرفوض|تم رفض|لم تتم|غير ناجح|عدم كفايه|فشل|'
    r'لم يتم تنفيذ',
  );

  /// Statements, due-date and limit notices: informative, not payments.
  static final notice = RegExp(
    r'statement (is ready|has been issued|balance)|minimum (payment|amount) due|'
    r'payment due date|due on \d|كشف حساب|كشف الحساب|الحد الادني للسداد|'
    r'تاريخ الاستحقاق|موعد السداد',
  );

  /// Wording that confirms money actually moved; promotions lack it.
  static final confirmed = RegExp(
    r'was (charged|debited|credited|used)|has been|have been|you (paid|sent|received|spent)|'
    r'\b(purchase|transaction|payment|transfer) of|charged|debited|credited|'
    r'withdrawn|\btrx\b|تم |عمليه شراء|عمليه بقيمه|سحب نقدي',
  );
  static final promo = RegExp(
    r'cashback up to|up to \d+%|\boffer\b|\bwin\b|enjoy|don.t miss|'
    r'apply now|خصم يصل|عرض|استمتع|اربح|لا تفوت|احصل علي',
  );

  /// Words before an amount that make it a balance or limit, not the
  /// payment.
  static final balanceLabel = RegExp(
    r'(avail(able)?\.?\s*(bal(ance)?|limit|credit)|\bbal(ance)?\b|'
    r'remaining|current balance|limit|الرصيد|رصيدك|رصيد|الحد المتاح|المتاح|'
    r'المتبقي)[^0-9]{0,24}$',
  );
  static final feeLabel = RegExp(
    r'(\bfees?\b|\bcharges?\b|\bcommission\b|رسوم|عموله|مصاريف)[^0-9]{0,16}$',
  );
  static final equivalentLabel = RegExp(
    r'(equivalent( to)?|equiv\.?|approx\.?|بما يعادل|يعادل|المعادل)[^0-9]{0,16}$',
  );

  /// Kinds, checked in this order (most specific first).
  static final refund = RegExp(
    r'refund|revers(al|ed)|returned|cancell?ed transaction|استرداد|مرتجع|'
    r'رد مبلغ|الغاء عمليه|استرجاع',
  );
  static final cardPayment = RegExp(
    r'(payment|repayment).{0,40}(credit card|card account|towards your card)|'
    r'(credit card|card).{0,30}payment (has been )?received|'
    r'سداد.{0,30}(البطاقه|بطاقه|الائتمان)|تم سداد مبلغ',
  );
  static final withdrawal = RegExp(
    r'\batm\b|cash withdrawal|withdrawn|withdrawal|سحب نقدي|سحب',
  );
  static final transferIn = RegExp(
    r'received .{0,30}from|you have received|transfer received|incoming transfer|'
    r'credited .{0,40}from|تم استلام|استلمت|تحويل وارد|حواله وارده|تم ايداع.{0,40}من|'
    r'اضافه.{0,40}من',
  );
  static final transferOut = RegExp(
    r'transferr?ed|you sent|sent to|transfer to|instapay transfer|'
    r'تم تحويل|حولت|تحويل مبلغ|ارسال مبلغ|تم ارسال',
  );
  static final bill = RegExp(
    r'\bbill\b|fawry|utility|فاتوره|فوري|شحن رصيد|recharge',
  );
  static final deposit = RegExp(
    r'deposit(ed)?|credited|salary|payroll|تم ايداع|ايداع|اضافه|تم اضافه|راتب|مرتب',
  );
  static final purchase = RegExp(
    r'purchase|spent|charged|debited|\bpaid\b|payment of|\bpos\b|'
    r'transaction (of|at|on)|used (at|for)|شراء|تم خصم|خصم|دفع|مدفوعات|'
    r'عمليه بقيمه|عمليه شراء',
  );

  /// Card or account numbers people refer to by their last 4 digits.
  static final last4 = [
    RegExp(r'(?:x{2,}|\*{2,}|•{2,}|#)\s?-?\s?(\d{4})\b'),
    RegExp(
      r'(?:ending(?: with| in)?|ends with|المنتهيه ب|المنتهي ب|المنتهيه|تنتهي ب)\s*:?\s*(?:no\.?\s*)?(\d{4})\b',
    ),
    RegExp(
      r'(?:card|بطاقه|بطاقتك|بطاقتكم|account|acc\.?|a/c|حساب|حسابك)\s*(?:no\.?|number|رقم|ب)?\s*:?\s*(?:[x*•]+\s?)?(\d{4})\b',
    ),
  ];

  /// Where a merchant name follows.
  static final merchantLead = RegExp(
    r'(?:(?<![a-z])(?:at|@|merchant:?|from merchant)|'
    r'(?<![\u0600-\u06FF])(?:لدي|عند|في محل|لصالح))\s+',
  );

  /// Where a transfer counterparty follows.
  static final toLead = RegExp(
    r'(?:(?<![a-z])to|(?<![\u0600-\u06FF])(?:الي|لصالح))\s+',
  );
  static final fromLead = RegExp(
    r'(?:(?<![a-z])from|(?<![\u0600-\u06FF])من)\s+',
  );

  /// Where a merchant or counterparty name stops.
  static final nameEnd = RegExp(
    r'\s(?:on|using|with|via|by|card|ending|for|in|at)\b|\s(?:successfully|succeeded|equivalent|equiv|has|have|was|is|were)\b|\s(?:في|بتاريخ|يوم|بواسطه|ببطاقه|بطاقه|باستخدام|رصيد|الرصيد|عبر|بنجاح|بما|يعادل|علي)(?=\s|$|[.,])|'
    r'[,;:!(]|\.(?=\s|$)|\s\d{1,2}[/-]\d{1,2}|\s(?:avail|bal|ref|trx)',
  );

  static final reference = RegExp(
    r'(?:ref(?:erence)?\.?|trx(?: id)?|transaction id|auth(?: code)?|'
    r'رقم مرجعي|رقم العمليه|الرقم المرجعي)\s*(?:no\.?|number|#|:)?\s*:?\s*([a-z0-9]{6,20})',
  );
}
