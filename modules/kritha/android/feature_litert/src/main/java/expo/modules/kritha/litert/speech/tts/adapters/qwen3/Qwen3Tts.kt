package expo.modules.kritha.litert.speech.tts.adapters.qwen3

import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.runtime.tts.SpeechAudio
import expo.modules.kritha.runtime.tts.SynthesisOptions
import expo.modules.kritha.runtime.tts.SynthesisResult
import expo.modules.kritha.runtime.tts.TtsAdapter
import expo.modules.kritha.runtime.tts.TtsModelAssets
import expo.modules.kritha.litert.speech.tts.internal.Npy

class Qwen3Tts(
    runtime: LiteRTRuntime,
    modelAssets: TtsModelAssets,
    execution: LiteRTExecutionOptions = LiteRTExecutionOptions(),
) : TtsAdapter {
    init {
        require(modelAssets.modelId.value == Qwen3TtsSpec.spec.id.value) {
            "Expected ${Qwen3TtsSpec.spec.id.value}, got ${modelAssets.modelId.value}"
        }
    }

    private val assets = Qwen3TtsAssets(modelAssets).also { it.requireAll() }
    private val engine = Qwen3TtsEngine(runtime, assets, execution)

    override fun synthesize(text: String, options: SynthesisOptions): SynthesisResult {
        require(options.speed == 1f) {
            "Qwen3-TTS speed control is not represented by the exported graph; use speed=1.0"
        }
        require(options.voice == 0) {
            "The generic TTS API exposes the bundled Qwen3 voice as voice=0; pass a speaker x-vector through synthesizeQwen3() for custom voices."
        }
        val start = System.nanoTime()
        val result = engine.synthesize(
            text = text,
            language = options.language,
            greedy = options.greedy,
            seed = options.seed,
        )
        return SynthesisResult(
            audio = SpeechAudio(
                pcm = result.pcm,
                sampleRate = result.sampleRate,
                channels = result.channels,
            ),
            elapsedMs = (System.nanoTime() - start) / 1_000_000,
        )
    }

    fun synthesizeQwen3(
        text: String,
        language: String = "english",
        speakerEmbedding: FloatArray? = null,
        greedy: Boolean = false,
        seed: Long? = null,
        progress: Qwen3TtsProgress? = null,
    ): Qwen3TtsEngineResult = engine.synthesize(
        text = text,
        language = language,
        speakerEmbedding = speakerEmbedding ?: Npy.loadFloats(assets.speakerFile(0)),
        greedy = greedy,
        seed = seed,
        progress = progress,
    )

    override fun close() = engine.close()
}
