package expo.modules.kritha.liveTalk

/** Canonical Live Talk session states (spec §7). Wire values are lowercase. */
enum class LiveTalkState(val wire: String) {
    IDLE("idle"),
    LISTENING("listening"),
    USER_SPEAKING("user_speaking"),
    PROCESSING("processing"),
    THINKING("thinking"),
    SPEAKING("speaking"),
    INTERRUPTED("interrupted"),
    PAUSED("paused");

    companion object {
        fun fromWire(value: String?): LiveTalkState? =
            entries.firstOrNull { it.wire == value }
    }
}

/** Coded error surfaced through the `error` Live Talk event. */
class LiveTalkException(val code: String, message: String) : Exception(message) {
    companion object {
        const val ERR_MIC_PERMISSION = "MIC_PERMISSION_DENIED"
        const val ERR_AUDIO_INIT = "AUDIO_INIT_FAILED"
        const val ERR_AEC_UNAVAILABLE = "AEC_UNAVAILABLE"
        const val ERR_WEBRTC_INIT = "WEBRTC_INIT_FAILED"
        const val ERR_VAD = "VAD_FAILURE"
        const val ERR_ASR = "ASR_FAILURE"
        const val ERR_INTELLIGENCE = "INTELLIGENCE_FAILURE"
        const val ERR_TTS = "TTS_FAILURE"
        const val ERR_PLAYBACK = "PLAYBACK_FAILURE"
        const val ERR_MODEL_MISSING = "MODEL_MISSING"
        const val ERR_RUNTIME_MISSING = "RUNTIME_MISSING"
        const val ERR_AUDIO_FOCUS = "AUDIO_FOCUS_LOST"
    }
}
