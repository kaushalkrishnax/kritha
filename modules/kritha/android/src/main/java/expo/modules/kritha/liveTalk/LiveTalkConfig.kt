package expo.modules.kritha.liveTalk

/**
 * Configurable thresholds for the Live Talk pipeline.
 * All values are tunable; defaults target low-latency conversational use.
 */
data class LiveTalkConfig(
    /** Sample rate for AudioRecord capture (Hz). */
    val sampleRate: Int = 16_000,
    /** Frame size fed to VAD (samples). 512 = 32ms at 16kHz. */
    val vadFrameSize: Int = 512,
    /** Silero VAD speech probability threshold (0–1). */
    val vadSpeechThreshold: Float = 0.5f,
    /** Silero VAD silence probability threshold (0–1). */
    val vadSilenceThreshold: Float = 0.35f,
    /** Consecutive silent frames before turn ends (frames × 32ms ≈ 700ms). */
    val silenceFrameCount: Int = 22,
    /** Absolute utterance timeout (ms). Protects against VAD stalls. */
    val absoluteUtteranceTimeoutMs: Long = 30_000L,
    /** Whether to use WebRTC APM instead of Android hardware AEC. */
    val forceWebRtcApm: Boolean = false,
)
