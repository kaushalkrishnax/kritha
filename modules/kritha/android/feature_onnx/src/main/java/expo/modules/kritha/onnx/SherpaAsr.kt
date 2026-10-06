package expo.modules.kritha.onnx

import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineSenseVoiceModelConfig
import com.k2fsa.sherpa.onnx.OfflineWhisperModelConfig

import expo.modules.kritha.runtime.asr.AsrProvider
import java.io.File

class SherpaAsr : AsrProvider {
    private var recognizer: OfflineRecognizer? = null

    @Synchronized
    override fun load(modelDirectory: String) {
        release()
        val dir = File(modelDirectory)
        
        val featConfig = FeatureConfig(
            sampleRate = 16000,
            featureDim = 80
        )
        
        var tokensPath = File(dir, "tokens.txt").absolutePath
        if (!File(tokensPath).exists()) {
            val jsonTokens = File(dir, "vocab.json")
            if (jsonTokens.exists()) {
                tokensPath = jsonTokens.absolutePath
            }
        }

        val whisper = OfflineWhisperModelConfig()
        val senseVoice = OfflineSenseVoiceModelConfig()
        var modelType = ""
        
        if (File(dir, "tiny.en-encoder.int8.onnx").exists()) {
             whisper.encoder = File(dir, "tiny.en-encoder.int8.onnx").absolutePath
             whisper.decoder = File(dir, "tiny.en-decoder.int8.onnx").absolutePath
             modelType = "whisper"
        } else if (File(dir, "model.onnx").exists()) {
             senseVoice.model = File(dir, "model.onnx").absolutePath
             modelType = "sense_voice"
        } else if (File(dir, "model.int8.onnx").exists()) {
             senseVoice.model = File(dir, "model.int8.onnx").absolutePath
             modelType = "sense_voice"
        } else {
             // Fallback to Whisper default names
             if (File(dir, "encoder.onnx").exists() && File(dir, "decoder.onnx").exists()) {
                 whisper.encoder = File(dir, "encoder.onnx").absolutePath
                 whisper.decoder = File(dir, "decoder.onnx").absolutePath
                 modelType = "whisper"
             }
        }
        
        val modelConfig = OfflineModelConfig(
            tokens = tokensPath,
            whisper = whisper,
            senseVoice = senseVoice,
            numThreads = 4,
            debug = false,
            provider = "cpu",
            modelType = modelType
        )
        
        val config = OfflineRecognizerConfig(
            featConfig = featConfig,
            modelConfig = modelConfig,
            decodingMethod = "greedy_search",
            maxActivePaths = 4
        )
        
        recognizer = OfflineRecognizer(assetManager = null, config = config)
    }

    @Synchronized
    override fun transcribe(pcm: ShortArray, sampleRate: Int): String {
        val r = recognizer ?: error("SherpaAsr not loaded")
        val stream = r.createStream()
        
        val floats = FloatArray(pcm.size) { pcm[it] / 32768f }
        
        stream.acceptWaveform(floats, sampleRate)
        r.decode(stream)
        
        val result = r.getResult(stream)
        stream.release()
        return result.text
    }

    @Synchronized
    override fun release() {
        runCatching { recognizer?.release() }
        recognizer = null
    }
}
