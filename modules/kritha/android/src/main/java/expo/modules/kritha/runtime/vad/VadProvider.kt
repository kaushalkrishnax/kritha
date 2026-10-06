package expo.modules.kritha.runtime.vad

/**
 * Streaming voice-activity detection capability exposed by a runtime
 * (initially the ONNX dynamic feature running Silero VAD).
 *
 * Frames are PCM-16 at the rate the model was loaded for (16 kHz for
 * Silero). Callers must feed exactly the model's window (512 samples for
 * Silero at 16 kHz) — sherpa kills its compute() call on any other length.
 */
interface VadProvider {
    /** Load the VAD model from an absolute file path. */
    fun load(modelPath: String)

    /** Speech probability in [0, 1] for one model-window PCM-16 frame. */
    fun speechProbability(frame: ShortArray): Float

    /** Reset recurrent state between utterances/speakers. */
    fun reset()

    fun release()
}
