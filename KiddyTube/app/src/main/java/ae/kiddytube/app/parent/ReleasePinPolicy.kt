package ae.kiddytube.app.parent

/**
 * Rules for the factory development PIN (`2580`) and release-ready gating.
 *
 * Debug builds keep the factory PIN for day-to-day development until Release ready is on.
 * Release builds allow the factory PIN only for first-run parent setup (until the PIN is
 * changed), then reject it. Kid playback on release builds requires a non-default PIN.
 */
object ReleasePinPolicy {
    /**
     * When true, an entered PIN equal to [ParentPinManager.DEFAULT_DEV_PIN] must be rejected
     * even if it still matches the stored hash.
     */
    fun rejectDefaultDevPin(
        isDebugBuild: Boolean,
        releaseReady: Boolean,
        pinChangedFromDefault: Boolean
    ): Boolean {
        if (releaseReady) return true
        // Release APK: after parent leaves the factory PIN, never accept 2580 again.
        if (!isDebugBuild && pinChangedFromDefault) return true
        return false
    }

    /** Release APKs block channel/player launch until the factory PIN is replaced. */
    fun requirePinChangeForKidPlayback(
        isDebugBuild: Boolean,
        pinChangedFromDefault: Boolean
    ): Boolean = !isDebugBuild && !pinChangedFromDefault

    /** True when the stored hash is still the factory development PIN. */
    fun matchesDefaultDevPin(salt: String?, hash: String?): Boolean {
        if (salt.isNullOrBlank() || hash.isNullOrBlank()) return false
        val expected = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt) ?: return false
        return expected.equals(hash, ignoreCase = true)
    }

    /**
     * Reconcile flags with the actual stored hash: default hash clears change/ready;
     * release-ready never sticks while still on the factory PIN.
     */
    fun sanitizePinFlags(
        pinSalt: String?,
        pinHash: String?,
        pinChangedFromDefault: Boolean,
        releaseReady: Boolean
    ): SanitizedPinFlags {
        val stillDefault = matchesDefaultDevPin(pinSalt, pinHash)
        val changed = pinChangedFromDefault && !stillDefault
        val ready = releaseReady && changed
        return SanitizedPinFlags(
            pinChangedFromDefault = changed,
            releaseReady = ready
        )
    }

    data class SanitizedPinFlags(
        val pinChangedFromDefault: Boolean,
        val releaseReady: Boolean
    )
}
