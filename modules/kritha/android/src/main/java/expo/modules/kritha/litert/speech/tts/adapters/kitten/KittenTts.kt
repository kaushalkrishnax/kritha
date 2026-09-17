package expo.modules.kritha.litert.speech.tts.adapters.kitten

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.speech.tts.SpeechAudio
import expo.modules.kritha.litert.speech.tts.SynthesisOptions
import expo.modules.kritha.litert.speech.tts.SynthesisResult
import expo.modules.kritha.litert.speech.tts.TtsAdapter
import expo.modules.kritha.litert.speech.tts.TtsModelAssets

class KittenTts(
    runtime: LiteRTRuntime,
    modelAssets: TtsModelAssets,
    execution: LiteRTExecutionOptions = LiteRTExecutionOptions(),
) : TtsAdapter {

    init {
        require(modelAssets.modelId.value == KittenTtsConfig.MODEL_ID) {
            "Expected ${KittenTtsConfig.MODEL_ID}, got ${modelAssets.modelId.value}"
        }
    }

    private val assets = KittenTtsAssets(modelAssets).also { it.requireAll() }
    private val engine = KittenTtsEngine(
        runtime = runtime,
        assets = assets,
        execution = execution,
    )

    override fun synthesize(
        text: String,
        options: SynthesisOptions,
    ): SynthesisResult {
        require(text.isNotBlank()) { "KittenTTS text cannot be blank" }
        require(options.language.equals("english", ignoreCase = true)) {
            "KittenTTS nano 0.8 supports English only"
        }
        require(options.voice in 0 until KittenTtsConfig.VOICE_COUNT) {
            "Invalid KittenTTS voice index ${options.voice}; expected 0..7"
        }
        require(options.speed > 0f && options.speed.isFinite()) {
            "KittenTTS speed must be finite and greater than 0"
        }

        val start = System.nanoTime()
        val result = engine.synthesize(
            text = text,
            voice = options.voice,
            speed = options.speed,
        )

        return SynthesisResult(
            audio = SpeechAudio(
                pcm = result.pcm,
                sampleRate = result.sampleRate,
                channels = result.channels,
            ),
            elapsedMs = (System.nanoTime() - start) / 1_000_000L,
        )
    }

    fun synthesizeKitten(
        text: String,
        voice: Int = 0,
        speed: Float = 1f,
    ): KittenTtsEngineResult = engine.synthesize(text, voice, speed)

    fun voiceNames(): List<String> = KittenTtsConfig.VOICES

    override fun close() = engine.close()
}
