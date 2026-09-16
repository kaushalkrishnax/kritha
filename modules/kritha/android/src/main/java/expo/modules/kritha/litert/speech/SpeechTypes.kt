package expo.modules.kritha.litert.speech

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import java.io.Closeable

enum class SpeechTask { ASR, STT, TTS }

data class AudioSpec(
    val sampleRate: Int = 16000,
    val channels: Int = 1
)

data class SpeechModelManifest(
    val id: String,
    val architecture: String,
    val task: SpeechTask,
    val modelPath: String,
    val signature: String = "",
    val inputNames: List<String> = emptyList(),
    val outputNames: List<String> = emptyList(),
    val outputTypes: List<String> = emptyList(),
    val audio: AudioSpec = AudioSpec(),
    val inputMilliseconds: Int? = null,
    val mel: MelSpec? = null,
    val startTokenId: Int? = null,
    val stopTokenId: Int? = null,
    val maxDecodeTokens: Int = 128,
    val tokenizerPath: String? = null,
    val metadata: Map<String, String> = emptyMap()
)

data class MelSpec(
    val fftSize: Int = 400,
    val hopLength: Int = 160,
    val nMels: Int = 80,
    val windowLength: Int = 400,
    val preEmphasis: Float = 0f,
    val normalize: Boolean = true
)

data class Transcription(
    val text: String,
    val tokenIds: IntArray = intArrayOf(),
    val elapsedMs: Long = 0L
)

data class SpeechAudio(
    val pcm: FloatArray,
    val sampleRate: Int,
    val channels: Int = 1
)

data class SynthesisResult(
    val audio: SpeechAudio,
    val elapsedMs: Long
)

interface Tokenizer {
    fun encode(text: String): IntArray
    fun decode(tokenIds: IntArray): String
}

interface AsrAdapter : Closeable {
    fun transcribe(
        audio: FloatArray,
        options: TranscriptionOptions = TranscriptionOptions()
    ): Transcription
}

interface TtsAdapter : Closeable {
    fun synthesize(
        text: String,
        options: SynthesisOptions = SynthesisOptions()
    ): SynthesisResult
}

data class TranscriptionOptions(
    val language: String? = null,
    val task: String = "transcribe",
    val maxTokens: Int? = null
)

data class SynthesisOptions(
    val voice: Int = 0,
    val speed: Float = 1f
)

interface SpeechAdapterFactory {
    fun supports(architecture: String, task: SpeechTask): Boolean
    fun create(
        runtime: LiteRTRuntime,
        manifest: SpeechModelManifest,
        execution: LiteRTExecutionOptions
    ): Closeable
}
