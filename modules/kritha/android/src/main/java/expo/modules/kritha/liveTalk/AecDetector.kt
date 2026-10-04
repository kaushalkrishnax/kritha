package expo.modules.kritha.liveTalk

import android.media.audiofx.AcousticEchoCanceler
import android.util.Log

/**
 * Detects whether the platform hardware AEC is available for a given
 * AudioRecord session. Must be called after AudioRecord is initialized.
 */
object AecDetector {
    private const val TAG = "AecDetector"

    /** True when the device advertises hardware AEC support. */
    fun isHardwareAecAvailable(): Boolean = AcousticEchoCanceler.isAvailable()

    /**
     * Try to attach platform AEC to the given AudioRecord session.
     * Returns the attached [AcousticEchoCanceler] on success, null otherwise.
     */
    fun attachAec(audioSessionId: Int): AcousticEchoCanceler? {
        if (!isHardwareAecAvailable()) {
            Log.i(TAG, "Hardware AEC not available on this device")
            return null
        }
        return try {
            val aec = AcousticEchoCanceler.create(audioSessionId)
            if (aec == null) {
                Log.w(TAG, "AcousticEchoCanceler.create() returned null for session $audioSessionId")
                null
            } else {
                aec.enabled = true
                Log.i(TAG, "Hardware AEC attached to session $audioSessionId")
                aec
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to attach AEC to session $audioSessionId", e)
            null
        }
    }
}
