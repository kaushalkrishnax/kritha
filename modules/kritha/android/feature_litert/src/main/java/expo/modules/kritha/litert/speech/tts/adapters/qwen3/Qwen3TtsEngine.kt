package expo.modules.kritha.litert.speech.tts.adapters.qwen3

import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.speech.tts.internal.Npy
import java.util.Random
import kotlin.system.measureTimeMillis

/**
 * Host-side Qwen3-TTS orchestration: tokenizer + embeddings + conditioning + Talker + MTP + codec.
 * LiteRTRuntime stays Qwen-agnostic.
 */
internal class Qwen3TtsEngine(
    runtime: LiteRTRuntime,
    assets: Qwen3TtsAssets,
    execution: LiteRTExecutionOptions,
    runtimeConfig: Qwen3TtsRuntimeConfig = Qwen3TtsRuntimeConfig(),
) : AutoCloseable {
    private val lock = Any()
    private val tokenizer = Qwen3TtsTokenizer(assets.vocab(), assets.merges())
    private val embeddings = Qwen3TtsEmbeddings(assets)
    private val conditioning = Qwen3TtsConditioning(embeddings)
    private val sampler = Qwen3TtsSampling()

    private val speaker = Npy.loadFloats(assets.speakerFile(0))

    private val talker = Qwen3TtsTalker(
        runtime = runtime,
        modelFile = assets.talker(runtimeConfig.useFp32Talker),
        execution = execution.copy(cpuThreads = runtimeConfig.cpuThreadsTalker),
    )
    private val mtp = Qwen3TtsMtp(
        runtime = runtime,
        modelFile = assets.mtp(),
        execution = execution.copy(cpuThreads = runtimeConfig.cpuThreadsMtp),
        embeddings = embeddings,
        sampler = sampler,
    )
    private val codec = Qwen3TtsCodec(
        runtime = runtime,
        modelFile = assets.codec(),
        execution = execution.copy(cpuThreads = runtimeConfig.cpuThreadsCodec),
    )

    init {
        require(speaker.size == Qwen3TtsConfig.HIDDEN) {
            "Demo speaker vector must contain ${Qwen3TtsConfig.HIDDEN} floats, got ${speaker.size}"
        }
    }

    fun encodeText(text: String): IntArray = tokenizer.encode(text)

    fun synthesize(
        text: String,
        language: String = "english",
        speakerEmbedding: FloatArray = speaker,
        greedy: Boolean = false,
        seed: Long? = null,
        progress: Qwen3TtsProgress? = null,
    ): Qwen3TtsEngineResult = synchronized(lock) {
        require(text.isNotBlank()) { "Qwen3-TTS text cannot be blank" }
        require(speakerEmbedding.size == Qwen3TtsConfig.HIDDEN) {
            "Speaker x-vector must contain ${Qwen3TtsConfig.HIDDEN} floats"
        }

        val random = if (seed != null) Random(seed) else Random()
        val textIds = tokenizer.encode(text)
        require(textIds.isNotEmpty()) { "Qwen3 tokenizer produced no tokens for input" }

        val prompt = conditioning.build(
            textTokenIds = textIds,
            language = language,
            speaker = speakerEmbedding,
        )

        var prefillMs = 0L
        var talkerMs = 0L
        var mtpMs = 0L
        var codecMs = 0L

        val generated = ArrayList<Qwen3TtsFrame>()
        val history = HashSet<Int>()
        var position = prompt.prefill.size - 1

        prefillMs = measureTimeMillis {
            talker.prefill(prompt.prefill)
        }
        var step = talker.decode(prompt.prefill.last(), position)

        while (generated.size < Qwen3TtsConfig.MAX_FRAMES) {
            val logits = step.logits.copyOf()
            sampler.applyTalkerControls(logits, history, generated.size)
            val semantic = sampler.sample(
                logits = logits,
                greedy = greedy,
                random = random,
                vocabLimit = Qwen3TtsConfig.CODEC_VOCAB,
            )
            history += semantic

            if (semantic == Qwen3TtsConfig.EOS) break

            lateinit var residual: IntArray
            mtpMs += measureTimeMillis {
                residual = mtp.generate(
                    hidden = step.hidden,
                    semanticCode = semantic,
                    greedy = greedy,
                    random = random,
                )
            }

            val frameCodes = IntArray(Qwen3TtsConfig.CODEBOOKS)
            frameCodes[0] = semantic
            for (i in 0 until Qwen3TtsConfig.MTP_CODEBOOKS) frameCodes[i + 1] = residual[i]
            generated += Qwen3TtsFrame(frameCodes)
            progress?.onFrame(generated.size)

            val nextEmbedding = embeddings.codecRow(semantic)
            for (i in 0 until Qwen3TtsConfig.MTP_CODEBOOKS) {
                embeddings.addMtpRow(nextEmbedding, i, residual[i])
            }
            val conditioningIndex = generated.size - 1
            val textCondition = prompt.trailingTextConditions.getOrNull(conditioningIndex)
            if (textCondition != null) {
                for (i in 0 until Qwen3TtsConfig.HIDDEN) nextEmbedding[i] += textCondition[i]
            }

            position++
            require(position < Qwen3TtsConfig.TALKER_CACHE) {
                "Qwen3 Talker KV cache exhausted at position $position"
            }
            talkerMs += measureTimeMillis {
                step = talker.decode(nextEmbedding, position)
            }
        }

        lateinit var pcm: FloatArray
        codecMs = measureTimeMillis {
            pcm = codec.decode(generated)
        }

        Qwen3TtsEngineResult(
            pcm = pcm,
            sampleRate = Qwen3TtsConfig.SAMPLE_RATE,
            channels = 1,
            frames = generated.size,
            timings = Qwen3TtsTimings(
                prefillMs = prefillMs,
                talkerMs = talkerMs,
                mtpMs = mtpMs,
                codecMs = codecMs,
            ),
        )
    }

    override fun close() {
        synchronized(lock) {
            codec.close()
            mtp.close()
            talker.close()
            embeddings.close()
        }
    }
}
