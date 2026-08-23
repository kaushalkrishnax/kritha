package expo.modules.kritha

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import expo.modules.kritha.wakeword.WakeWordEventHub
import java.util.Locale

object TtsManager {
    @Volatile
    private var ttsInstance: TextToSpeech? = null
    @Volatile
    var isReady: Boolean = false
        private set

    private val streamingBuffer = StringBuilder()
    private var sentenceCount = 0

    fun prewarm(context: Context) {
        if (ttsInstance != null) return
        val appContext = context.applicationContext
        ttsInstance = TextToSpeech(appContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsInstance?.language = Locale.US
                isReady = true
                ttsInstance?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        WakeWordEventHub.emitAssistant("tts_start")
                    }
                    override fun onDone(utteranceId: String?) {
                        WakeWordEventHub.emitAssistant("tts_done")
                    }
                    override fun onError(utteranceId: String?) {
                        WakeWordEventHub.emitAssistant("tts_done")
                    }
                })
            }
        }
    }

    fun getInstance(context: Context): TextToSpeech? {
        if (ttsInstance == null) {
            prewarm(context)
        }
        return ttsInstance
    }

    fun speak(context: Context, text: String) {
        if (text.isBlank()) return
        stop()
        val tts = getInstance(context) ?: return
        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "kritha-single-utt")
        }
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, "kritha-single-utt")
    }

    fun stop() {
        streamingBuffer.clear()
        sentenceCount = 0
        ttsInstance?.stop()
    }

    fun handleStreamingChunk(context: Context, chunk: String) {
        val tts = getInstance(context) ?: return
        streamingBuffer.append(chunk)

        var text = streamingBuffer.toString()
        var splitIndex = -1

        for (i in 0 until text.length) {
            val c = text[i]
            if (c == '.' || c == '!' || c == '?' || c == '\n' || c == ',' || c == ';' || c == ':') {
                if (i == text.length - 1 || text[i + 1].isWhitespace()) {
                    splitIndex = i + 1
                    break
                }
            }
        }

        if (splitIndex == -1 && text.length >= 35) {
            val spaceIndex = text.indexOf(' ', 25)
            if (spaceIndex > 0) {
                splitIndex = spaceIndex + 1
            }
        }

        if (splitIndex > 0) {
            val clause = text.substring(0, splitIndex).trim()
            streamingBuffer.delete(0, splitIndex)
            if (clause.isNotBlank()) {
                queueClause(tts, clause)
            }
        }
    }

    fun flushStreaming(context: Context) {
        val remaining = streamingBuffer.toString().trim()
        streamingBuffer.clear()
        if (remaining.isNotBlank()) {
            ttsInstance?.let { queueClause(it, remaining) }
        }
    }

    private fun queueClause(tts: TextToSpeech, clause: String) {
        val uttId = "kritha-utt-$sentenceCount"
        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
        }
        val mode = if (sentenceCount == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
        tts.speak(clause, mode, params, uttId)
        sentenceCount++
    }
}
