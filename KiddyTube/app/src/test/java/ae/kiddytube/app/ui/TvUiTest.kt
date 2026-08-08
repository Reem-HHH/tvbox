package ae.kiddytube.app.ui

import android.content.res.Configuration
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TvUiTest {

    @Test
    fun televisionUiModeIsTv() {
        assertTrue(
            TvUi.isTelevision(
                uiModeType = Configuration.UI_MODE_TYPE_TELEVISION,
                hasLeanback = false,
                hasTelevisionFeature = false
            )
        )
    }

    @Test
    fun leanbackFeatureIsTvEvenWithoutUiMode() {
        assertTrue(
            TvUi.isTelevision(
                uiModeType = Configuration.UI_MODE_TYPE_NORMAL,
                hasLeanback = true,
                hasTelevisionFeature = false
            )
        )
    }

    @Test
    fun legacyTelevisionFeatureIsTv() {
        assertTrue(
            TvUi.isTelevision(
                uiModeType = Configuration.UI_MODE_TYPE_NORMAL,
                hasLeanback = false,
                hasTelevisionFeature = true
            )
        )
    }

    @Test
    fun phoneIsNotTv() {
        assertFalse(
            TvUi.isTelevision(
                uiModeType = Configuration.UI_MODE_TYPE_NORMAL,
                hasLeanback = false,
                hasTelevisionFeature = false
            )
        )
    }
}
