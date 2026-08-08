package ae.kiddytube.app.sources

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AndroidAppIdentityTest {
    @Test
    fun sha1HexLowerMatchesKnownVector() {
        // SHA-1("abc") = a9993e364706816aba3e25717850c26c9cd0d89d
        val hex = AndroidAppIdentity.sha1HexLower("abc".toByteArray(Charsets.US_ASCII))
        assertEquals("a9993e364706816aba3e25717850c26c9cd0d89d", hex)
        assertEquals(40, hex.length)
        assertEquals(hex.lowercase(), hex)
        assertFalse(hex.contains(':'))
    }

    @Test
    fun sha1HexLowerUsesUnsignedByteFormatting() {
        // Input with high bits set must not emit sign-extended ffffff.. hex runs.
        val hex = AndroidAppIdentity.sha1HexLower(byteArrayOf(0xAB.toByte(), 0xCD.toByte()))
        assertEquals(40, hex.length)
        assertFalse(hex.contains("ffffff"))
        assertEquals(hex.lowercase(), hex)
    }
}
