package ae.kiddytube.app.ui

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

/** Shared Android TV / Leanback detection for layout and chrome. */
object TvUi {
    fun isTelevision(context: Context): Boolean {
        val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        val pm = context.packageManager
        @Suppress("DEPRECATION")
        return isTelevision(
            uiModeType = uiMode,
            hasLeanback = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK),
            hasTelevisionFeature = pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
        )
    }

    /**
     * Pure helper for tests and shared call sites.
     * True when UI mode is television, or the device advertises Leanback / television features.
     */
    fun isTelevision(
        uiModeType: Int,
        hasLeanback: Boolean,
        hasTelevisionFeature: Boolean
    ): Boolean {
        if (uiModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true
        return hasLeanback || hasTelevisionFeature
    }
}
