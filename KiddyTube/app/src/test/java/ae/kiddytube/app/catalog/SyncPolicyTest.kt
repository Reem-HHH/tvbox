package ae.kiddytube.app.catalog

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncPolicyTest {
    @Test
    fun importsWhenFollowUploadsOn() {
        assertTrue(SyncPolicy.shouldImportPlaylist(followUploads = true, videoCount = 50))
    }

    @Test
    fun importsWhenLibraryEmptyEvenWithoutFollow() {
        assertTrue(SyncPolicy.shouldImportPlaylist(followUploads = false, videoCount = 0))
    }

    @Test
    fun doesNotImportWhenClosedAndAlreadyFilled() {
        assertFalse(SyncPolicy.shouldImportPlaylist(followUploads = false, videoCount = 3))
    }
}
