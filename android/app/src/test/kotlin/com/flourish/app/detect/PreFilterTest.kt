package com.flourish.app.detect
import org.junit.Assert.*
import org.junit.Test
class PreFilterTest {
    @Test fun acceptsEgyptianPoundSpellings() {
        for (token in listOf("LE", "le", "Le", "L.E", "L.E.")) {
            for (text in listOf("Purchase ${token}125.50", "Purchase 125.50$token", "Purchase $token ١٢٥٫٥٠"))
                assertTrue(text, PreFilter.looksLikePayment(text))
        }
    }
    @Test fun rejectsCodesAndUnrelatedWords() {
        assertFalse(PreFilter.looksLikePayment("OTP for LE 125.50: 123456"))
        assertFalse(PreFilter.looksLikePayment("Sale 125.50 at Cafe"))
    }
}
