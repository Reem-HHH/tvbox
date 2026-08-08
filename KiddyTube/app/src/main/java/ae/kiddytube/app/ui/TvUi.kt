package ae.kiddytube.app.ui

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

/** Shared Android TV / Leanback detection for layout and chrome. */
object TvUi {
    @Suppress("DEPRECATION")
    fun isTelevision(context: Context): Boolean {
        val uiMode = context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        if (uiMode == Configuration.UI_MODE_TYPE_TELEVISION) return true
        val pm = context.packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
    }
}
