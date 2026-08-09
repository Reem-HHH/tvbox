package ae.kiddytube.app.catalog

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ContentTitleFilterTest {
    @Test
    fun allowsNormalKidsTitles() {
        assertTrue(ContentTitleFilter.isAllowed("Peppa Pig Muddy Puddles"))
        assertTrue(ContentTitleFilter.isAllowed("سورة الفاتحة للأطفال"))
        assertTrue(ContentTitleFilter.isAllowed(null))
    }

    @Test
    fun blocksFamilyUnsafeTitles() {
        assertTrue(ContentTitleFilter.isBlocked("Halloween Songs for Kids"))
        assertTrue(ContentTitleFilter.isBlocked("Happy Thanksgiving Nursery Rhymes"))
        assertTrue(ContentTitleFilter.isBlocked("Pride Month Parade for Kids"))
        assertTrue(ContentTitleFilter.isBlocked("LGBTQ Story Time"))
        assertTrue(ContentTitleFilter.isBlocked("أغاني هالوين للأطفال"))
    }
}
