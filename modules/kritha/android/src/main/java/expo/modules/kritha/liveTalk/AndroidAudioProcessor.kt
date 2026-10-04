package expo.modules.kritha.liveTalk

import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.util.Log

/**
 * [AudioProcessor] backed by Android's hardware [AcousticEchoCanceler] and
 * [NoiseSuppressor] effects attached to an AudioRecord session.
 *
 * The actual echo-cancellation and noise-suppression happen inside the
 * AudioRecord driver; this class only manages effect lifecycle.
 * [process] is therefore a pass-through — the cleaned audio is already present
 * in the buffer when [AudioRecord.read] returns.
 */
class AndroidAudioProcessor : AudioProcessor {
    companion object {
        private const val TAG = "AndroidAudioProcessor"
    }

    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null

    /** True when hardware AEC was successfully attached and enabled. */
    var isAecActive: Boolean = false
        private set

    /** True when hardware NS was successfully attached and enabled. */
    var isNsActive: Boolean = false
        private set

    override fun start(audioSessionId: Int) {
        aec = AecDetector.attachAec(audioSessionId)
        isAecActive = aec?.enabled == true

        ns = tryAttachNs(audioSessionId)
        isNsActive = ns?.enabled == true

        Log.i(
            TAG,
            "AEC=${if (isAecActive) "attached" else "unavailable"} " +
                "NS=${if (isNsActive) "attached" else "unavailable"} " +
                "session=$audioSessionId",
        )
    }

    /** Hardware effects are applied inside AudioRecord — pass audio through unchanged. */
    override fun process(input: ShortArray): ShortArray = input

    override fun stop() {
        runCatching { aec?.release() }
        runCatching { ns?.release() }
        aec = null
        ns = null
        isAecActive = false
        isNsActive = false
        Log.i(TAG, "AndroidAudioProcessor released")
    }

    private fun tryAttachNs(sessionId: Int): NoiseSuppressor? {
        if (!NoiseSuppressor.isAvailable()) return null
        return try {
            NoiseSuppressor.create(sessionId)?.also { it.enabled = true }
        } catch (e: Exception) {
            Log.w(TAG, "NoiseSuppressor attach failed for session $sessionId", e)
            null
        }
    }
}
