package expo.modules.kritha.runtime.asr

/**
 * Utterance-level ASR capability exposed by a runtime
 * (initially the ONNX dynamic feature running Moonshine).
 *
 * The conversation runtime depends only on this contract, never on a
 * specific model.
 */
interface AsrProvider {
    /** Load the model artifacts from an absolute directory path. */
    fun load(modelDirectory: String)

    /** Blocking transcription of a complete PCM-16 mono utterance. */
    fun transcribe(pcm: ShortArray, sampleRate: Int): String

    fun release()
}
