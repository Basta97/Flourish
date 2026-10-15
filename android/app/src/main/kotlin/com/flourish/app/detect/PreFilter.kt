package com.flourish.app.detect

/**
 * A cheap first look so unrelated notifications never reach the queue: a
 * number next to a currency, no one-time code wording.
 */
object PreFilter {
    private val digits = Regex("[0-9٠-٩۰-۹]")
    private val money = Regex(
        "(EGP|L\\.?E\\b|USD|EUR|GBP|SAR|AED|KWD|QAR|\\$|€|£|ج\\.?\\s?م|جنيه|جم\\b|دولار|يورو|ريال|درهم|دينار)",
        RegexOption.IGNORE_CASE,
    )
    private val otp = Regex(
        "(\\bOTP\\b|one[- ]time|verification code|passcode|do not share|رمز التحقق|كود التحقق|رمز التفعيل|لا تشارك|كلمة المرور لمرة واحدة)",
        RegexOption.IGNORE_CASE,
    )

    fun looksLikePayment(text: String): Boolean =
        text.length in 8..2000 && digits.containsMatchIn(text) &&
            money.containsMatchIn(text) && !otp.containsMatchIn(text)
}
