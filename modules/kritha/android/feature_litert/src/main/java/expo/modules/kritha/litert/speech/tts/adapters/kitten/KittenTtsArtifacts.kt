package expo.modules.kritha.litert.speech.tts.adapters.kitten

import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.runtime.tts.TtsAdapter
import expo.modules.kritha.runtime.tts.TtsArtifact
import expo.modules.kritha.runtime.tts.TtsModelAssets
import expo.modules.kritha.runtime.tts.TtsModelId
import expo.modules.kritha.runtime.tts.TtsModelSpec
import expo.modules.kritha.litert.speech.tts.adapters.TtsAdapterProvider
import expo.modules.kritha.litert.speech.tts.internal.Npy
import java.io.File
import java.util.zip.ZipFile

object KittenTtsConfig {
    const val MODEL_ID = "kitten-tts-nano"
    const val VERSION = "0.8"

    const val SAMPLE_RATE = 24_000
    const val VOICE_COUNT = 8

    const val STYLE_ROWS = 400
    const val STYLE_DIM = 256
    const val D_DIM = 256
    const val ASR_DIM = 128
    const val HAR_DIM = 22
    const val SAMPLES_PER_FRAME = 600

    const val NUM_THREADS = 4
    const val G2P_MAX_TOKENS = 96
    const val MAX_TEXT = 256

    const val PREDICTOR_FILE = "kitten_predictor_fp16.tflite"
    const val PROSODY_FILE = "kitten_prosody_fp16.tflite"
    const val VOCODER_FILE = "kitten_vocoder_fp16.tflite"
    const val G2P_FILE = "dp_g2p_matcha_fp16.tflite"
    const val VOICES_FILE = "voices.bin"
    const val VOICES_NPZ_FILE = "voices.npz"
    const val CONFIG_FILE = "config.json"
    const val G2P_META_FILE = "g2p_meta.json"
    const val G2P_DICT_FILE = "g2p_dict.txt"
    const val G2P_DICT_GZIP_FILE = "g2p_dict.txt.gz"

    val VOICES = listOf(
        "expr-voice-2-m",
        "expr-voice-2-f",
        "expr-voice-3-m",
        "expr-voice-3-f",
        "expr-voice-4-m",
        "expr-voice-4-f",
        "expr-voice-5-m",
        "expr-voice-5-f",
    )

    val VOICE_ALIASES = mapOf(
        "Bella" to "expr-voice-2-f",
        "Jasper" to "expr-voice-2-m",
        "Luna" to "expr-voice-3-f",
        "Bruno" to "expr-voice-3-m",
        "Rosie" to "expr-voice-4-f",
        "Hugo" to "expr-voice-4-m",
        "Kiki" to "expr-voice-5-f",
        "Leo" to "expr-voice-5-m",
    )

    const val TAIL_TRIM = 5000
    const val MIN_SAMPLES = 1200
}

/**
 * Kitten file contract: graphs/voice table from the kitten repo, G2P frontend from Matcha-TTS.
 * `voices.bin` is built on-device from `voices.npz` (see [KittenTtsProvider]).
 */
object KittenTtsSpec {
    private const val KITTEN_REPO =
        "https://huggingface.co/litert-community/kitten-tts-nano-0.8/resolve/main"
    private const val G2P_REPO =
        "https://huggingface.co/litert-community/Matcha-TTS/resolve/main"

    val spec = TtsModelSpec(
        id = TtsModelId(KittenTtsConfig.MODEL_ID),
        displayName = "KittenTTS Nano 0.8 (LiteRT)",
        version = KittenTtsConfig.VERSION,
        languages = setOf("english"),
        sampleRate = KittenTtsConfig.SAMPLE_RATE,
        displaySize = "45 MB",
        artifacts = listOf(
            TtsArtifact(
                name = KittenTtsConfig.PREDICTOR_FILE,
                remoteUrl = "$KITTEN_REPO/${KittenTtsConfig.PREDICTOR_FILE}",
            ),
            TtsArtifact(
                name = KittenTtsConfig.PROSODY_FILE,
                remoteUrl = "$KITTEN_REPO/${KittenTtsConfig.PROSODY_FILE}",
            ),
            TtsArtifact(
                name = KittenTtsConfig.VOCODER_FILE,
                remoteUrl = "$KITTEN_REPO/${KittenTtsConfig.VOCODER_FILE}",
            ),
            // Built on-device from voices.npz; never downloaded directly.
            TtsArtifact(name = KittenTtsConfig.VOICES_FILE),
            TtsArtifact(
                name = KittenTtsConfig.VOICES_NPZ_FILE,
                required = false,
                remoteUrl = "$KITTEN_REPO/${KittenTtsConfig.VOICES_NPZ_FILE}",
            ),
            TtsArtifact(
                name = KittenTtsConfig.G2P_FILE,
                remoteUrl = "$G2P_REPO/${KittenTtsConfig.G2P_FILE}",
            ),
            TtsArtifact(
                name = KittenTtsConfig.CONFIG_FILE,
                remoteUrl = "$G2P_REPO/${KittenTtsConfig.CONFIG_FILE}",
            ),
            TtsArtifact(
                name = KittenTtsConfig.G2P_META_FILE,
                remoteUrl = "$G2P_REPO/${KittenTtsConfig.G2P_META_FILE}",
            ),
            // Either dictionary layout satisfies the frontend; the frontend
            // also works without one, so both stay optional.
            TtsArtifact(name = KittenTtsConfig.G2P_DICT_FILE, required = false),
            TtsArtifact(
                name = KittenTtsConfig.G2P_DICT_GZIP_FILE,
                required = false,
                remoteUrl = "$G2P_REPO/${KittenTtsConfig.G2P_DICT_GZIP_FILE}",
            ),
        ),
    )
}

internal class KittenTtsAssets(private val assets: TtsModelAssets) {
    fun predictor(): File = requireFile(KittenTtsConfig.PREDICTOR_FILE)
    fun prosody(): File = requireFile(KittenTtsConfig.PROSODY_FILE)
    fun vocoder(): File = requireFile(KittenTtsConfig.VOCODER_FILE)
    fun g2p(): File = requireFile(KittenTtsConfig.G2P_FILE)
    fun voices(): File = requireFile(KittenTtsConfig.VOICES_FILE)
    fun config(): File = requireFile(KittenTtsConfig.CONFIG_FILE)
    fun g2pMeta(): File = requireFile(KittenTtsConfig.G2P_META_FILE)

    fun dictionary(): File? {
        val plain = assets.file(KittenTtsConfig.G2P_DICT_FILE)
        if (plain.isFile) return plain
        val gzip = assets.file(KittenTtsConfig.G2P_DICT_GZIP_FILE)
        if (gzip.isFile) return gzip
        return null
    }

    fun requireAll() {
        val missing = KittenTtsSpec.spec.missing(assets)
        require(missing.isEmpty()) {
            "Missing KittenTTS assets: ${missing.joinToString { it.name }}"
        }
    }

    private fun requireFile(name: String): File {
        val file = assets.file(name)
        require(file.isFile) {
            "Missing KittenTTS asset '$name' in model directory"
        }
        return file
    }
}

object KittenTtsVoices {
    fun index(voice: String?): Int {
        if (voice.isNullOrBlank()) return 0
        val trimmed = voice.trim()
        trimmed.toIntOrNull()?.let {
            return it.coerceIn(0, KittenTtsConfig.VOICE_COUNT - 1)
        }
        if (trimmed.equals("F1", ignoreCase = true)) return 0
        KittenTtsConfig.VOICE_ALIASES[trimmed]?.let { alias ->
            return KittenTtsConfig.VOICES.indexOf(alias).coerceAtLeast(0)
        }
        KittenTtsConfig.VOICES.indexOf(trimmed).takeIf { it >= 0 }?.let { return it }
        return 0
    }
}

object KittenTtsProvider : TtsAdapterProvider {
    override val spec: TtsModelSpec = KittenTtsSpec.spec

    override fun create(
        runtime: LiteRTRuntime,
        assets: TtsModelAssets,
        execution: LiteRTExecutionOptions,
    ): TtsAdapter = KittenTts(runtime, assets, execution)

    override fun voiceIndex(voice: String?): Int = KittenTtsVoices.index(voice)

    /** Converts `voices.npz` to a flat LE float32 `[8,400,256]` table the adapter reads. */
    override fun finishDownload(modelDir: File) {
        val voicesBin = File(modelDir, KittenTtsConfig.VOICES_FILE)
        if (voicesBin.isFile && voicesBin.length() > 0L) return
        val npzFile = File(modelDir, KittenTtsConfig.VOICES_NPZ_FILE)
        require(npzFile.isFile) { "KittenTTS download finished but voices.npz is missing" }
        ZipFile(npzFile).use { zip ->
            val chunks = ArrayList<ByteArray>(KittenTtsConfig.VOICE_COUNT)
            for (voice in KittenTtsConfig.VOICES) {
                val wantedName = "$voice.npy"
                val entry = zip.getEntry(wantedName)
                    ?: zip.entries().asSequence().firstOrNull { it.name.endsWith(wantedName) }
                    ?: error("Missing voice entry $wantedName in ${npzFile.name}")
                val raw = zip.getInputStream(entry).use { it.readBytes() }
                val expectedSamples = KittenTtsConfig.STYLE_ROWS * KittenTtsConfig.STYLE_DIM
                val data = Npy.readF32Payload(raw)
                require(data.size == expectedSamples * 4) {
                    "Unexpected size for $wantedName: ${data.size} bytes"
                }
                chunks += data
            }
            val combined = ByteArray(chunks.sumOf { it.size })
            var offset = 0
            for (chunk in chunks) {
                System.arraycopy(chunk, 0, combined, offset, chunk.size)
                offset += chunk.size
            }
            voicesBin.writeBytes(combined)
        }
        val expectedBytes =
            KittenTtsConfig.VOICE_COUNT *
                KittenTtsConfig.STYLE_ROWS *
                KittenTtsConfig.STYLE_DIM *
                4L
        require(voicesBin.length() == expectedBytes) {
            "voices.bin has unexpected size ${voicesBin.length()}, expected $expectedBytes"
        }
        npzFile.delete()
    }
}
