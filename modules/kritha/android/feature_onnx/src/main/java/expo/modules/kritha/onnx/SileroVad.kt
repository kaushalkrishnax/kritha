package expo.modules.kritha.onnx

import com.k2fsa.sherpa.onnx.SileroVadModelConfig
import com.k2fsa.sherpa.onnx.Vad
import com.k2fsa.sherpa.onnx.VadModelConfig
import expo.modules.kritha.runtime.vad.VadProvider

class SileroVad : VadProvider {
    private var vad: Vad? = null

    @Synchronized
    override fun load(modelPath: String) {
        release()
        
        val sileroConfig = SileroVadModelConfig(
            model = modelPath,
            threshold = 0.5f,
            minSilenceDuration = 0.5f,
            minSpeechDuration = 0.25f,
            // Silero VAD at 16 kHz requires exactly 512 samples per window;
            // sherpa's native compute() rejects any other length.
            windowSize = EXPECTED_WINDOW_SAMPLES,
            maxSpeechDuration = 20.0f
        )
        
        val vadConfig = VadModelConfig(
            sileroVadModelConfig = sileroConfig,
            tenVadModelConfig = com.k2fsa.sherpa.onnx.TenVadModelConfig("", 0f, 0f, 0f, 0, 0f),
            sampleRate = 16000,
            numThreads = 1,
            provider = "cpu",
            debug = false
        )
        
        vad = Vad(assetManager = null, config = vadConfig)
    }

    @Synchronized
    override fun speechProbability(frame: ShortArray): Float {
        val active = vad ?: error("SileroVad not loaded")
        // Must be exactly the model window: sherpa's native compute() aborts
        // the process on any other length.
        require(frame.size == EXPECTED_WINDOW_SAMPLES) {
            "SileroVad expects $EXPECTED_WINDOW_SAMPLES samples per frame, got ${frame.size}"
        }
        // sherpa-onnx Vad manages the recurrent state internally in C++;
        // compute() advances it and returns the window speech probability.
        val input = FloatArray(frame.size) { frame[it] / 32768f }
        return active.compute(input)
    }

    @Synchronized
    override fun reset() {
        vad?.reset()
    }

    @Synchronized
    override fun release() {
        runCatching { vad?.release() }
        vad = null
    }

    companion object {
        /**
         * Silero VAD analysis window at 16 kHz (32 ms). sherpa-onnx requires
         * exactly 512 samples per compute() call.
         */
        const val EXPECTED_WINDOW_SAMPLES = 512
    }
}
