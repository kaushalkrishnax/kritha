package expo.modules.kritha.liveTalk

/**
 * Rule-based turn detection on top of per-frame VAD probabilities (spec §6).
 *
 * - speech_start fires once when probability crosses the speech threshold.
 * - Probabilities between the two thresholds keep the current state
 *   (hysteresis) so normal speech pauses do not cut the user off.
 * - speech_end fires only after a sustained run of silent frames.
 * - The session enforces the absolute utterance timeout via [maxSpeechFrames].
 */
class TurnDetector(
    private val config: LiveTalkConfig,
) {
    enum class Signal { NONE, SPEECH_START, SPEECH_END }

    private var inSpeech = false
    private var silentFrames = 0
    var speechFrames = 0
        private set
    var endedSpeechFrames = 0
        private set

    val frameDurationMs: Long
        get() = config.vadFrameSize * 1_000L / config.sampleRate

    val maxSpeechFrames: Int
        get() = (config.absoluteUtteranceTimeoutMs / frameDurationMs).toInt()

    fun accept(probability: Float): Signal {
        return when {
            probability >= config.vadSpeechThreshold -> {
                silentFrames = 0
                speechFrames += 1
                if (!inSpeech) {
                    inSpeech = true
                    Signal.SPEECH_START
                } else {
                    Signal.NONE
                }
            }
            probability <= config.vadSilenceThreshold -> {
                if (!inSpeech) return Signal.NONE
                speechFrames += 1
                silentFrames += 1
                if (silentFrames >= config.silenceFrameCount) {
                    endedSpeechFrames = speechFrames
                    reset()
                    Signal.SPEECH_END
                } else {
                    Signal.NONE
                }
            }
            else -> {
                if (inSpeech) speechFrames += 1
                Signal.NONE
            }
        }
    }

    fun reset() {
        inSpeech = false
        silentFrames = 0
        speechFrames = 0
    }
}
