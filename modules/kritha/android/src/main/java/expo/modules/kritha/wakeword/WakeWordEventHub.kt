package expo.modules.kritha.wakeword

object WakeWordEventHub {
    var listener: ((keyword: String, confidence: Float) -> Unit)? = null
    var assistantListener: ((state: String, transcript: String?, response: String?, error: String?, chunk: String?, rms: Float?) -> Unit)? = null

    fun emit(keyword: String, confidence: Float) {
        listener?.invoke(keyword, confidence)
    }

    fun emitAssistant(
        state: String,
        transcript: String? = null,
        response: String? = null,
        error: String? = null,
        chunk: String? = null,
        rms: Float? = null
    ) {
        assistantListener?.invoke(state, transcript, response, error, chunk, rms)
    }
}
