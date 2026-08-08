package ae.kiddytube.app.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenDebouncerTest {
    @Test
    fun blocksRapidDuplicateOpens() {
        assertTrue(OpenDebouncer.tryOpen("video:a", windowMs = 10_000L))
        assertFalse(OpenDebouncer.tryOpen("video:a", windowMs = 10_000L))
        assertTrue(OpenDebouncer.tryOpen("video:b", windowMs = 10_000L))
    }
}
