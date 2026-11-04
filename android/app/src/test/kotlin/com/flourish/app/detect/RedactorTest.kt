package com.flourish.app.detect
import org.junit.Assert.*
import org.junit.Test
/** Same cases as the Dart redact() tests, so both sides agree. */
class RedactorTest {
    @Test fun matchesDartRedaction() {
        assertEquals("card ••••1111 used", Redactor.redact("card 4111 1111 1111 1111 used"))
        assertEquals("ID [ID]", Redactor.redact("ID 29801011234567"))
        assertEquals("your code is [CODE]", Redactor.redact("your code is 482913"))
        assertEquals("sent to 010*****678", Redactor.redact("sent to 01012345678"))
    }
    @Test fun keepsPaymentDetails() {
        val text = "Purchase EGP 250.00 card ending 1234 at Carrefour"
        assertEquals(text, Redactor.redact(text))
    }
}
