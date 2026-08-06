package ae.kiddytube.app.parent

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ParentSessionTest {
    @Before
    fun clearSession() {
        ParentSession.clear()
    }

    @Test
    fun grantIsActiveWithinTtl() {
        val now = 1_000_000L
        assertFalse(ParentSession.isActive(now))
        ParentSession.grant(now)
        assertTrue(ParentSession.isActive(now + 1))
        assertTrue(ParentSession.isActive(now + 4 * 60 * 1000L))
        assertFalse(ParentSession.isActive(now + 5 * 60 * 1000L))
    }

    @Test
    fun clearEndsSession() {
        ParentSession.grant(1_000L)
        assertTrue(ParentSession.isActive(1_001L))
        ParentSession.clear()
        assertFalse(ParentSession.isActive(1_001L))
    }
}
