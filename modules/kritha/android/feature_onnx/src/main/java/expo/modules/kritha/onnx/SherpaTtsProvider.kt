package expo.modules.kritha.onnx

import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import expo.modules.kritha.runtime.tts.SpeechAudio
import expo.modules.kritha.runtime.tts.StaticTtsSpecs
import expo.modules.kritha.runtime.tts.SynthesisOptions
import expo.modules.kritha.runtime.tts.SynthesisResult
import expo.modules.kritha.runtime.tts.TtsFileAssets
import expo.modules.kritha.runtime.tts.TtsModelAssets
import expo.modules.kritha.runtime.tts.TtsModelId
import expo.modules.kritha.runtime.tts.TtsModelSpec
import expo.modules.kritha.runtime.tts.TtsProvider
import java.io.File

/**
 * Sherpa-ONNX piper (VITS) TTS for the ONNX runtime feature package.
 * Model layout per directory: <name>.onnx, tokens.txt, espeak-ng-data/.
 */
class SherpaTtsProvider : TtsProvider {
    private val lock = Any()
    private var cachedModelId: TtsModelId? = null
    private var cachedRoot: File? = null
    private var tts: OfflineTts? = null

    override fun getAvailableSpecs(): List<TtsModelSpec> = StaticTtsSpecs.allSpecs

    override fun synthesize(
        model: TtsModelAssets,
        text: String,
        options: SynthesisOptions,
    ): SynthesisResult {
        require(text.isNotBlank()) { "text cannot be blank" }
        val root = rootOf(model)
        synchronized(lock) {
            if (tts == null || cachedModelId != model.modelId || cachedRoot != root) {
                releaseAll()
                tts = createOfflineTts(root)
                cachedModelId = model.modelId
                cachedRoot = root
            }
            val start = System.nanoTime()
            val audio = tts!!.generate(text, options.voice, options.speed)
            val elapsedMs = (System.nanoTime() - start) / 1_000_000
            return SynthesisResult(
                audio = SpeechAudio(
                    pcm = audio.samples,
                    sampleRate = audio.sampleRate,
                ),
                elapsedMs = elapsedMs,
            )
        }
    }

    override fun release(modelId: TtsModelId) {
        synchronized(lock) {
            if (cachedModelId == modelId) {
                tts?.release()
                tts = null
                cachedModelId = null
                cachedRoot = null
            }
        }
    }

    override fun releaseAll() {
        synchronized(lock) {
            tts?.release()
            tts = null
            cachedModelId = null
            cachedRoot = null
        }
    }

    private fun rootOf(model: TtsModelAssets): File =
        (model as TtsFileAssets).canonicalRootFile

    private fun createOfflineTts(root: File): OfflineTts {
        val onnxFile = root.listFiles()?.firstOrNull { it.name.endsWith(".onnx") }
            ?: error("No .onnx model file in ${root.absolutePath}")
        val tokens = File(root, "tokens.txt")
        require(tokens.isFile) { "Missing tokens.txt in ${root.absolutePath}" }
        val dataDir = File(root, "espeak-ng-data")
        require(dataDir.isDirectory) { "Missing espeak-ng-data in ${root.absolutePath}" }
        val vits = OfflineTtsVitsModelConfig(
            onnxFile.absolutePath, // model
            "",                    // lexicon
            tokens.absolutePath,   // tokens
            dataDir.absolutePath,  // dataDir
            "",                    // dictDir
            0.667f,                 // noiseScale
            0.8f,                   // noiseScaleW
            1.0f,                   // lengthScale
        )
        val modelConfig = OfflineTtsModelConfig().apply { this.vits = vits }
        val config = OfflineTtsConfig().apply { this.model = modelConfig }
        return OfflineTts(null, config)
    }

    private companion object {
        const val TAG = "SherpaTtsProvider"
    }
}
