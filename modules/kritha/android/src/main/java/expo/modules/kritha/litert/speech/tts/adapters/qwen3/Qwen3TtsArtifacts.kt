package expo.modules.kritha.litert.speech.tts.adapters.qwen3

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.speech.tts.TtsAdapter
import expo.modules.kritha.litert.speech.tts.TtsArtifact
import expo.modules.kritha.litert.speech.tts.TtsModelAssets
import expo.modules.kritha.litert.speech.tts.TtsModelId
import expo.modules.kritha.litert.speech.tts.TtsModelSpec
import expo.modules.kritha.litert.speech.tts.adapters.TtsAdapterProvider
import java.io.File

object Qwen3TtsConfig {
    const val MODEL_ID = "qwen3-tts-12hz-0.6b-base"

    const val HIDDEN = 1024
    const val CODEC_VOCAB = 3072
    const val TALKER_CACHE = 1024
    const val TALKER_LAYERS = 28

    const val MTP_LAYERS = 5
    const val MTP_CACHE = 17
    const val MTP_VOCAB = 2048
    const val MTP_CODEBOOKS = 15
    const val MTP_INNER_STEPS = 16

    const val CODEBOOKS = 16
    const val CODEC_CHUNK = 64
    const val CODEC_CONTEXT = 25
    const val CODEC_SAMPLES_PER_FRAME = 1920
    const val SAMPLE_RATE = 24_000

    const val MAX_FRAMES = 512
    const val EOS = 2150
    const val PAD_ID = 2148
    const val BOS_ID = 2149
    const val THINK = 2154
    const val THINK_BOS = 2156
    const val THINK_EOS = 2157
    const val NOTHINK = 2155
    const val TTS_BOS = 151672
    const val TTS_EOS = 151673
    const val TTS_PAD = 151671

    const val NEGATIVE_INFINITY = -1e9f
    const val TEMPERATURE = 0.9
    const val TOP_K = 50
    const val REPETITION_PENALTY = 1.05f
    const val MIN_NEW_FRAMES = 2

    const val TALKER_FILE_INT4 = "talker_int4.tflite"
    const val TALKER_FILE_FP32 = "talker_fp32.tflite"
    const val MTP_FILE = "mtp_fp32.tflite"
    const val CODEC_FILE = "codec_decoder_fp32.tflite"

    const val VOCAB_FILE = "vocab.json"
    const val MERGES_FILE = "merges.txt"
    const val CODEC_EMBEDDING_FILE = "codec_embedding_fp32.npy"
    const val MTP_EMBEDDING_FILE = "mtp_embeddings_fp16.npy"
    const val TEXT_EMBEDDING_FILE = "text_embedding_fp16.npy"
    const val TEXT_PROJECTION_FILE = "text_projection_fp32.npz"
    const val DEMO_SPEAKER_FILE = "demo_speaker.npy"

    const val PREFILL_SIGNATURE = "prefill_32"
    const val TALKER_PREFILL_SIZE = 32
    const val DECODE_SIGNATURE = "decode"

    val PROMPT_PREFIX = intArrayOf(151644, 77091, 198)
    val PROMPT_SUFFIX = intArrayOf(151645, 198, 151644, 77091, 198)

    val LANGUAGE_IDS: Map<String, Int> = mapOf(
        "chinese" to 2055,
        "english" to 2050,
        "german" to 2053,
        "italian" to 2070,
        "portuguese" to 2071,
        "spanish" to 2054,
        "japanese" to 2058,
        "korean" to 2064,
        "french" to 2061,
        "russian" to 2069,
    )
}

data class Qwen3TtsRuntimeConfig(
    val useFp32Talker: Boolean = false,
    val cpuThreadsTalker: Int = 4,
    val cpuThreadsMtp: Int = 2,
    val cpuThreadsCodec: Int = 4,
)

/**
 * Qwen3 file contract. Downloads flatten the upstream repo layout (`tables/…`,
 * `voices/…`) into the model root, so every artifact accepts both locations.
 */
object Qwen3TtsSpec {
    private const val REPO =
        "https://huggingface.co/litert-community/Qwen3-TTS-12Hz-0.6B-Base/resolve/main"

    val spec = TtsModelSpec(
        id = TtsModelId("qwen3-tts"),
        displayName = "Qwen3-TTS 12Hz 0.6B (LiteRT)",
        version = "0.6b-base",
        languages = Qwen3TtsConfig.LANGUAGE_IDS.keys,
        sampleRate = Qwen3TtsConfig.SAMPLE_RATE,
        displaySize = "1.9 GB",
        directoryName = Qwen3TtsConfig.MODEL_ID,
        artifacts = listOf(
            TtsArtifact(
                name = Qwen3TtsConfig.TALKER_FILE_INT4,
                // A manually placed fp32 talker satisfies the contract; the
                // manager only ever downloads the int4 graph.
                alternatives = listOf(Qwen3TtsConfig.TALKER_FILE_FP32),
                remoteUrl = "$REPO/${Qwen3TtsConfig.TALKER_FILE_INT4}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.MTP_FILE,
                remoteUrl = "$REPO/${Qwen3TtsConfig.MTP_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.CODEC_FILE,
                remoteUrl = "$REPO/${Qwen3TtsConfig.CODEC_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.VOCAB_FILE,
                remoteUrl = "$REPO/${Qwen3TtsConfig.VOCAB_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.MERGES_FILE,
                remoteUrl = "$REPO/${Qwen3TtsConfig.MERGES_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.CODEC_EMBEDDING_FILE,
                alternatives = listOf("tables/${Qwen3TtsConfig.CODEC_EMBEDDING_FILE}"),
                remoteUrl = "$REPO/tables/${Qwen3TtsConfig.CODEC_EMBEDDING_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.MTP_EMBEDDING_FILE,
                alternatives = listOf("tables/${Qwen3TtsConfig.MTP_EMBEDDING_FILE}"),
                remoteUrl = "$REPO/tables/${Qwen3TtsConfig.MTP_EMBEDDING_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.TEXT_EMBEDDING_FILE,
                alternatives = listOf("tables/${Qwen3TtsConfig.TEXT_EMBEDDING_FILE}"),
                remoteUrl = "$REPO/tables/${Qwen3TtsConfig.TEXT_EMBEDDING_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.TEXT_PROJECTION_FILE,
                alternatives = listOf("tables/${Qwen3TtsConfig.TEXT_PROJECTION_FILE}"),
                remoteUrl = "$REPO/tables/${Qwen3TtsConfig.TEXT_PROJECTION_FILE}",
            ),
            TtsArtifact(
                name = Qwen3TtsConfig.DEMO_SPEAKER_FILE,
                alternatives = listOf("voices/${Qwen3TtsConfig.DEMO_SPEAKER_FILE}"),
                remoteUrl = "$REPO/voices/${Qwen3TtsConfig.DEMO_SPEAKER_FILE}",
            ),
        ),
    )
}

internal class Qwen3TtsAssets(private val assets: TtsModelAssets) {
    fun talker(useFp32: Boolean): File {
        val preferred = if (useFp32) Qwen3TtsConfig.TALKER_FILE_FP32 else Qwen3TtsConfig.TALKER_FILE_INT4
        val preferredFile = assets.file(preferred)
        if (preferredFile.isFile) return preferredFile
        val fallback = assets.file(if (useFp32) Qwen3TtsConfig.TALKER_FILE_INT4 else Qwen3TtsConfig.TALKER_FILE_FP32)
        require(fallback.isFile) {
            "No Qwen3 talker graph found. Expected $preferred or ${fallback.name} in model directory."
        }
        return fallback
    }

    fun mtp(): File = requireFile(Qwen3TtsConfig.MTP_FILE)
    fun codec(): File = requireFile(Qwen3TtsConfig.CODEC_FILE)
    fun vocab(): File = requireFile(Qwen3TtsConfig.VOCAB_FILE)
    fun merges(): File = requireFile(Qwen3TtsConfig.MERGES_FILE)
    fun codecEmbedding(): File = requireTable(Qwen3TtsConfig.CODEC_EMBEDDING_FILE)
    fun mtpEmbedding(): File = requireTable(Qwen3TtsConfig.MTP_EMBEDDING_FILE)
    fun textEmbedding(): File = requireTable(Qwen3TtsConfig.TEXT_EMBEDDING_FILE)
    fun textProjection(): File = requireTable(Qwen3TtsConfig.TEXT_PROJECTION_FILE)

    fun speakerFile(voice: Int): File {
        require(voice == 0) {
            "Built-in Qwen3 voice index $voice is unsupported. Pass an enrolled x-vector through Qwen3TtsEngine instead."
        }
        val preferred = assets.file("voices/${Qwen3TtsConfig.DEMO_SPEAKER_FILE}")
        return if (preferred.isFile) preferred else requireFile(Qwen3TtsConfig.DEMO_SPEAKER_FILE)
    }

    fun requireAll() {
        val missing = Qwen3TtsSpec.spec.missing(assets)
        require(missing.isEmpty()) {
            "Missing Qwen3 assets: ${missing.joinToString { it.name }}"
        }
    }

    private fun requireTable(name: String): File {
        val direct = assets.file(name)
        if (direct.isFile) return direct
        val nested = assets.file("tables/$name")
        if (nested.isFile) return nested
        error("Missing Qwen3 table '$name' in model root or tables/")
    }

    private fun requireFile(name: String): File {
        val f = assets.file(name)
        require(f.isFile) { "Missing Qwen3 asset '$name'" }
        return f
    }
}

object Qwen3TtsProvider : TtsAdapterProvider {
    override val spec: TtsModelSpec = Qwen3TtsSpec.spec

    override fun create(
        runtime: LiteRTRuntime,
        assets: TtsModelAssets,
        execution: LiteRTExecutionOptions,
    ): TtsAdapter = Qwen3Tts(runtime, assets, execution)

    // The exported graph only exposes the bundled demo voice.
    override fun voiceIndex(voice: String?): Int = 0
}
