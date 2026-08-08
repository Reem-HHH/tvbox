package ae.kiddytube.app.ui

import android.widget.ImageView
import coil.load
import coil.size.Scale
import ae.kiddytube.app.R

/** Shared Coil options for TV grid/list tiles — avoid per-bind transforms and crossfade jank. */
object TileImageLoad {
    /** mqdefault is 320x180; decode near that size for 3-column TV grids. */
    private const val TARGET_W = 320
    private const val TARGET_H = 180

    fun loadUrl(imageView: ImageView, url: String, placeholderRes: Int) {
        imageView.load(url) {
            crossfade(false)
            placeholder(placeholderRes)
            error(placeholderRes)
            size(TARGET_W, TARGET_H)
            scale(Scale.FILL)
        }
    }

    fun loadRes(imageView: ImageView, resId: Int) {
        imageView.load(resId) {
            crossfade(false)
            size(TARGET_W, TARGET_H)
            scale(Scale.FILL)
        }
    }

    fun clear(imageView: ImageView) {
        imageView.setImageResource(R.drawable.tile_placeholder)
    }
}
