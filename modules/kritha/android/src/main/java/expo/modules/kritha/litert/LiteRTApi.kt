package expo.modules.kritha.litert

/**
 * Stable request/response vocabulary for the React Native bridge.
 */
object LiteRTApi {
    const val VERSION = 1

    const val TASK_TEXT_TO_TEXT = "text-to-text"
    const val TASK_SPEECH_TO_TEXT = "speech-to-text"
    const val TASK_ASR = "asr"
    const val TASK_TEXT_TO_SPEECH = "text-to-speech"
    const val TASK_TTS = "tts"

    const val DEVICE_CPU = "cpu"
    const val DEVICE_GPU = "gpu"
    const val DEVICE_NPU = "npu"
}
