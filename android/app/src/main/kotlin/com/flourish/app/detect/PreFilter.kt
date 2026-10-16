package com.flourish.app.detect

/**
 * A cheap first look so unrelated notifications never reach the queue: a
 * number next to a currency, no one-time code wording.
 */
object PreFilter {
    private val digits = Regex("[0-9٠-٩۰-۹]")

    /** Currency codes as whole words, symbols, and Arabic currency names. */
    private val money = Regex(
        "(?<![A-Za-z])(EGP|L\\.?E|USD|EUR|GBP|SAR|AED|KWD|QAR|BHD|OMR|JOD|CHF|JPY|CNY|CAD|AUD)(?![A-Za-z])|" +
            "[\$€£¥₺₹]|ج\\.?\\s?م|جنيه|جم\\b|دولار|يورو|ريال|درهم|دينار|ليرة|ليره|فرنك|يوان",
        RegexOption.IGNORE_CASE,
    )

    /** Any other ISO code in capitals next to a number ("THB 1,250"). */
    private val isoAmount = Regex(
        "(?<![A-Za-z])[A-Z]{3}\\s?[0-9]|[0-9]\\s?[A-Z]{3}(?![A-Za-z])",
    )

    private val otp = Regex(
        "(\\bOTP\\b|one[- ]time|verification code|passcode|do not share|رمز التحقق|كود التحقق|رمز التفعيل|لا تشارك|كلمة المرور لمرة واحدة)",
        RegexOption.IGNORE_CASE,
    )

    fun looksLikePayment(text: String): Boolean =
        text.length in 8..2000 && digits.containsMatchIn(text) &&
            (money.containsMatchIn(text) || isoAmount.containsMatchIn(text)) &&
            !otp.containsMatchIn(text)
}
