package ae.kiddytube.app.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NavFocusMemoryTest {
    @Test
    fun remembersChannelAndPerChannelVideo() {
        NavFocusMemory.rememberChannel("omar_hana")
        assertEquals("omar_hana", NavFocusMemory.lastChannelId)
        assertNull(NavFocusMemory.lastVideoId("omar_hana"))

        NavFocusMemory.rememberVideo("omar_hana", "vid1")
        NavFocusMemory.rememberVideo("peppa", "vid2")
        assertEquals("peppa", NavFocusMemory.lastChannelId)
        assertEquals("vid1", NavFocusMemory.lastVideoId("omar_hana"))
        assertEquals("vid2", NavFocusMemory.lastVideoId("peppa"))
    }
}
