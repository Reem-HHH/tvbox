package ae.kiddytube.app.remote

import android.media.AudioManager
import android.view.KeyEvent
import ae.kiddytube.app.parent.ParentPinManager

sealed class RemoteAction {
    data object EnsurePlaying : RemoteAction()
    data object TogglePlayPause : RemoteAction()
    data object NextItem : RemoteAction()
    data object PreviousItem : RemoteAction()
    data object VolumeUp : RemoteAction()
    data object VolumeDown : RemoteAction()
    data object SeekForward : RemoteAction()
    data object SeekBack : RemoteAction()
    data object ParentTriggered : RemoteAction()
    data object Consume : RemoteAction()
    data object NavigateBack : RemoteAction()
}

class RemoteKeyHandler(
    private val pinManager: ParentPinManager,
    private val audioManager: AudioManager,
    private val consumeBack: Boolean = false
) {
    fun handleKeyDown(
        keyCode: Int,
        event: KeyEvent,
        nowMs: Long = System.currentTimeMillis(),
        alternateSequenceCsv: String? = null
    ): RemoteAction? {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.repeatCount == 0) pinManager.onBackDown(nowMs)
            return if (consumeBack) RemoteAction.Consume else RemoteAction.NavigateBack
        }

        val alt = ParentPinManager.parseSequenceCsv(alternateSequenceCsv)
        if (pinManager.recordKeyAndCheckTrigger(keyCode, nowMs, alt)) {
            pinManager.clearKeys()
            return RemoteAction.ParentTriggered
        }

        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_SPACE -> RemoteAction.EnsurePlaying

            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> RemoteAction.TogglePlayPause
            KeyEvent.KEYCODE_MEDIA_PLAY -> RemoteAction.EnsurePlaying
            KeyEvent.KEYCODE_MEDIA_PAUSE -> RemoteAction.TogglePlayPause

            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_MEDIA_NEXT -> RemoteAction.NextItem

            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> RemoteAction.PreviousItem

            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
            KeyEvent.KEYCODE_FORWARD -> RemoteAction.SeekForward

            KeyEvent.KEYCODE_MEDIA_REWIND -> RemoteAction.SeekBack

            KeyEvent.KEYCODE_VOLUME_UP -> {
                audioManager.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_RAISE,
                    0
                )
                RemoteAction.VolumeUp
            }

            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                audioManager.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_LOWER,
                    0
                )
                RemoteAction.VolumeDown
            }

            else -> null
        }
    }

    fun handleKeyUp(keyCode: Int, nowMs: Long = System.currentTimeMillis()): RemoteAction? {
        if (keyCode == KeyEvent.KEYCODE_BACK && pinManager.onBackUp(nowMs)) {
            return RemoteAction.ParentTriggered
        }
        return null
    }
}
