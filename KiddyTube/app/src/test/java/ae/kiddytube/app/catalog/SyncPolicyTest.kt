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

    @Test
    fun forceAndEmptyLibrariesBypassTtl() {
        assertTrue(SyncPolicy.shouldBypassTtl(force = true, emptyPlaylistLibraries = false))
        assertTrue(SyncPolicy.shouldBypassTtl(force = false, emptyPlaylistLibraries = true))
        assertFalse(SyncPolicy.shouldBypassTtl(force = false, emptyPlaylistLibraries = false))
    }

    @Test
    fun autoSkipsClosedNonEmptyPlaylistLibrary() {
        assertFalse(
            SyncPolicy.shouldRefreshChannel(
                force = false,
                hasPlaylist = true,
                hasYoutubeVideos = true,
                importPlaylist = false
            )
        )
    }

    @Test
    fun forceMetadataEnrichsClosedLibraryWithExistingVideos() {
        assertTrue(
            SyncPolicy.shouldRefreshChannel(
                force = true,
                hasPlaylist = true,
                hasYoutubeVideos = true,
                importPlaylist = false
            )
        )
    }

    @Test
    fun forceSkipsClosedEmptyLibraryWithOnlyPlaylist() {
        assertFalse(
            SyncPolicy.shouldRefreshChannel(
                force = true,
                hasPlaylist = true,
                hasYoutubeVideos = false,
                importPlaylist = false
            )
        )
    }

    @Test
    fun emptyLibraryImportsEvenWithoutFollowThenRefreshes() {
        val import = SyncPolicy.shouldImportPlaylist(followUploads = false, videoCount = 0)
        assertTrue(import)
        assertTrue(
            SyncPolicy.shouldRefreshChannel(
                force = false,
                hasPlaylist = true,
                hasYoutubeVideos = false,
                importPlaylist = import
            )
        )
    }

    @Test
    fun skipsChannelsWithNoPlaylistAndNoYoutubeIds() {
        assertFalse(
            SyncPolicy.shouldRefreshChannel(
                force = true,
                hasPlaylist = false,
                hasYoutubeVideos = false,
                importPlaylist = true
            )
        )
    }
}
