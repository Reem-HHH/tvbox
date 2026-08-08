package ae.kiddytube.app.parent

import android.content.Intent
import android.text.InputType
import android.util.TypedValue
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import kotlinx.coroutines.launch

/**
 * Shared PIN dialog used by channel home and video library (touch + TV).
 */
class ParentUnlockCoordinator(
    private val activity: AppCompatActivity,
    private var pinManager: ParentPinManager
) {
    fun updatePinManager(manager: ParentPinManager) {
        pinManager = manager
    }

    /**
     * @param onUnlocked when non-null, called after a successful PIN instead of opening
     * [ParentActivity] (used for gated home Mix/Shows toggle).
     */
    fun beginParentAccess(onUnlocked: (() -> Unit)? = null) {
        val now = System.currentTimeMillis()
        pinManager.refreshLockout(now)
        if (pinManager.isLockedOut(now)) {
            Toast.makeText(activity, R.string.parent_locked_out, Toast.LENGTH_SHORT).show()
            return
        }
        val input = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = activity.getString(R.string.parent_pin_title)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            // Help TV remotes land on the field.
            isFocusable = true
            isFocusableInTouchMode = true
            minHeight = (48 * resources.displayMetrics.density).toInt()
        }
        val dialog = AlertDialog.Builder(activity)
            .setTitle(R.string.parent_pin_title)
            .setView(input)
            .setPositiveButton(R.string.unlock, null)
            .setNegativeButton(R.string.cancel, null)
            .create()
        dialog.setOnShowListener {
            input.requestFocus()
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val pin = input.text.toString()
                activity.lifecycleScope.launch {
                    val repo = (activity.application as KiddyTubeApp).catalogRepository
                    val latest = repo.current()
                    if (latest.releaseReady && pin == ParentPinManager.DEFAULT_DEV_PIN) {
                        val locked = pinManager.registerFailure(System.currentTimeMillis())
                        repo.update {
                            it.copy(
                                failCount = pinManager.failureCount,
                                lockedUntilMs = pinManager.lockedUntilMs
                            )
                        }
                        if (locked) {
                            dialog.dismiss()
                            Toast.makeText(activity, R.string.parent_locked_out, Toast.LENGTH_SHORT)
                                .show()
                        } else {
                            Toast.makeText(activity, R.string.parent_pin_wrong, Toast.LENGTH_SHORT)
                                .show()
                            input.text?.clear()
                        }
                        return@launch
                    }
                    if (pinManager.verifyPin(pin, latest.pinSalt, latest.pinHash)) {
                        pinManager.registerSuccess()
                        repo.update { it.copy(failCount = 0, lockedUntilMs = 0L) }
                        ParentSession.grant()
                        dialog.dismiss()
                        if (onUnlocked != null) {
                            onUnlocked()
                        } else {
                            activity.startActivity(Intent(activity, ParentActivity::class.java))
                        }
                    } else {
                        val locked = pinManager.registerFailure(System.currentTimeMillis())
                        repo.update {
                            it.copy(
                                failCount = pinManager.failureCount,
                                lockedUntilMs = pinManager.lockedUntilMs
                            )
                        }
                        if (locked) {
                            dialog.dismiss()
                            Toast.makeText(activity, R.string.parent_locked_out, Toast.LENGTH_SHORT)
                                .show()
                        } else {
                            Toast.makeText(activity, R.string.parent_pin_wrong, Toast.LENGTH_SHORT)
                                .show()
                            input.text?.clear()
                        }
                    }
                }
            }
        }
        dialog.show()
    }
}
