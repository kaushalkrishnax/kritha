package expo.modules.kritha.onnx

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import expo.modules.kritha.runtime.vad.VadProvider

/**
 * Silero VAD (ONNX export) — streaming speech probability for 512-sample
 * PCM-16 frames at 16 kHz. Keeps the recurrent state tensor between calls.
 */
class SileroVad : VadProvider {
    private var env: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var state: Array<Array<FloatArray>> = zeroState()

    @Synchronized
    override fun load(modelPath: String) {
        release()
        val environment = OrtEnvironment.getEnvironment()
        env = environment
        session = environment.createSession(
            modelPath,
            OrtSession.SessionOptions().apply { setIntraOpNumThreads(2) },
        )
        state = zeroState()
    }

    @Synchronized
    override fun speechProbability(frame: ShortArray): Float {
        val active = session ?: error("SileroVad not loaded")
        require(frame.size == FRAME_SAMPLES) {
            "SileroVad expects $FRAME_SAMPLES samples per frame, got ${frame.size}"
        }

        val input = FloatArray(frame.size) { frame[it] / 32768f }
        val inputs = mutableMapOf<String, OnnxTensor>()
        var probability = 0f
        var nextState = state

        OnnxTensor.createTensor(env, arrayOf(input)).use { inputTensor ->
            OnnxTensor.createTensor(env, state).use { stateTensor ->
                OnnxTensor.createTensor(env, longArrayOf(SAMPLE_RATE)).use { srTensor ->
                    inputs["input"] = inputTensor
                    inputs["state"] = stateTensor
                    inputs["sr"] = srTensor
                    active.run(inputs).use { results ->
                        val output = results.get(0).value as Array<FloatArray>
                        probability = output[0][0]

                        @Suppress("UNCHECKED_CAST")
                        val rawState = results.get(1).value as Array<Array<FloatArray>>
                        // Results are closed on exit — copy the recurrent state out.
                        nextState = Array(rawState.size) { layer ->
                            Array(rawState[layer].size) { batch ->
                                rawState[layer][batch].copyOf()
                            }
                        }
                    }
                }
            }
        }
        state = nextState
        return probability
    }

    @Synchronized
    override fun reset() {
        state = zeroState()
    }

    @Synchronized
    override fun release() {
        runCatching { session?.close() }
        session = null
        env = null
        state = zeroState()
    }

    private fun zeroState(): Array<Array<FloatArray>> =
        Array(STATE_LAYERS) { Array(1) { FloatArray(STATE_DIM) } }

    private companion object {
        const val FRAME_SAMPLES = 512
        const val SAMPLE_RATE = 16_000L
        const val STATE_LAYERS = 2
        const val STATE_DIM = 128
    }
}
