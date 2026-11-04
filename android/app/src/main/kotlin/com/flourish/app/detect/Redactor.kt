package com.flourish.app.detect

/**
 * Removes what must never be stored before a message is queued: full card
 * numbers (kept as the last 4), national ID numbers and one-time codes;
 * phone numbers keep their last 3 digits. Mirrors lib/core/detection/redact.dart.
 */
object Redactor {
    private val longNumber = Regex("(?<!\\d)(?:\\d[ -]?){12,18}\\d(?!\\d)")
    private val nationalId = Regex("^[23]\\d{13}$")
    private val code = Regex(
        "((?:otp|code|passcode|pin|رمز|كود|الرمز)\\D{0,12})(\\d{4,8})",
        RegexOption.IGNORE_CASE,
    )
    private val phone = Regex("(?<!\\d)(\\+?20|0)(1[0125])(\\d{5})(\\d{3})(?!\\d)")

    fun redact(text: String): String {
        var out = longNumber.replace(text) { m ->
            val digits = m.value.replace(Regex("[ -]"), "")
            when {
                luhn(digits) -> "••••" + digits.takeLast(4)
                nationalId.matches(digits) -> "[ID]"
                else -> m.value
            }
        }
        out = code.replace(out) { m -> m.groupValues[1] + "[CODE]" }
        out = phone.replace(out) { m -> m.groupValues[1] + m.groupValues[2] + "*****" + m.groupValues[4] }
        return out
    }

    private fun luhn(digits: String): Boolean {
        var sum = 0
        for (i in digits.indices) {
            var d = digits[digits.length - 1 - i] - '0'
            if (i % 2 == 1) {
                d *= 2
                if (d > 9) d -= 9
            }
            sum += d
        }
        return sum % 10 == 0
    }
}
