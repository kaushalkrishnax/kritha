package expo.modules.kritha

import expo.modules.kritha.wakeword.*

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import expo.modules.kritha.intelligence.IntelligencePipeline
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

internal class NativeAssistantSession(
    private val context: Context,
    private val callback: Callback
) : RecognitionListener {

    interface Callback {
        fun onListening()
        fun onRmsChanged(rmsdB: Float)
        fun onPartial(transcript: String)
        fun onProcessing(transcript: String)
        fun onStreaming(transcript: String, chunk: String)
        fun onFinished(transcript: String?, response: String)
        fun onError(message: String)
        fun onSessionFinished()
        fun onTtsStart() {}
        fun onTtsPause() {}
        fun onTtsDone() {}
    }

    private val appContext   = context.applicationContext
    private val mainHandler  = Handler(Looper.getMainLooper())
    private val scope        = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val pipeline     = IntelligencePipeline(appContext)

    enum class TtsStatus { IDLE, SPEAKING, PAUSED }

    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech?            = null
    private var ttsReady                      = false
    private var pendingTts: String?           = null
    private var done                          = false

    private var fullTtsText: String = ""
    private var remainingTtsText: String = ""

    @Volatile var ttsStatus = TtsStatus.IDLE
        private set

    val isTtsSpeaking: Boolean get() = ttsStatus == TtsStatus.SPEAKING
    val isTtsPaused: Boolean get() = ttsStatus == TtsStatus.PAUSED

    private var pipelineJob: Job? = null

    private var ttsStreamingBuffer = StringBuilder()
    private var ttsSentenceCount = 0
    private var ttsFinishedSentences = 0
    private var isPipelineDone = false

    fun start() {
        mainHandler.post {
            initTts()
            initRecognizer()
        }
    }

    fun shutdown() {
        mainHandler.post {
            autoTts = false
            ttsStreamingBuffer.clear()
            pipelineJob?.cancel()
            pipelineJob = null
            scope.cancel()
            pipeline.close()
            cleanupRecognizer()
            tts?.stop()
            tts?.shutdown()
            tts = null
        }
    }

    fun cancelPipeline() {
        autoTts = false
        ttsStreamingBuffer.clear()
        pipelineJob?.cancel()
        pipelineJob = null
        stopTts()
    }

    fun stopListening() {
        mainHandler.post {
            try {
                recognizer?.stopListening()
            } catch (e: Exception) {
                Log.e("NativeAssistantSession", "Error stopping speech recognizer", e)
            }
        }
    }

    @Volatile var autoTts: Boolean = true

    fun processPrompt(transcript: String, shouldAutoTts: Boolean = true) {
        if (transcript.isBlank()) return
        autoTts = shouldAutoTts
        cleanupRecognizer()
        callback.onProcessing(transcript)
        runPipeline(transcript)
    }

    private fun runPipeline(transcript: String) {
        ttsStreamingBuffer.clear()
        ttsSentenceCount = 0
        ttsFinishedSentences = 0
        isPipelineDone = false

        pipelineJob = scope.launch {
            val result = pipeline.process(transcript) { chunk ->
                withContext(Dispatchers.Main) {
                    callback.onStreaming(transcript, chunk)
                    if (autoTts) {
                        handleStreamingTts(chunk)
                    }
                }
            }
            withContext(Dispatchers.Main) {
                isPipelineDone = true
                when (result) {
                    is IntelligencePipeline.Result.Hit -> {
                        callback.onFinished(transcript, result.response)
                        if (autoTts) {
                            flushRemainingTts()
                        } else {
                            finishSession()
                        }
                    }
                    is IntelligencePipeline.Result.Miss -> {
                        val msg = "I'm sorry, I couldn't process that request."
                        callback.onFinished(transcript, msg)
                        if (autoTts) {
                            speakText(msg)
                        } else {
                            finishSession()
                        }
                    }
                }
            }
        }
    }

    private fun handleStreamingTts(chunk: String) {
        ttsStreamingBuffer.append(chunk)
        
        var text = ttsStreamingBuffer.toString()
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
            val sentence = text.substring(0, splitIndex).trim()
            ttsStreamingBuffer.delete(0, splitIndex)
            if (sentence.isNotBlank()) {
                queueSentence(sentence)
            }
        }
    }

    private fun flushRemainingTts() {
        val remaining = ttsStreamingBuffer.toString().trim()
        if (remaining.isNotBlank()) {
            queueSentence(remaining)
        }
        checkIfTtsFinished()
    }

    private fun queueSentence(sentence: String) {
        val uttId = "kritha-utt-$ttsSentenceCount"
        
        if (ttsSentenceCount == 0) {
            fullTtsText = sentence
            remainingTtsText = sentence
            ttsStatus = TtsStatus.SPEAKING
            callback.onTtsStart()
            
            val params = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
            }
            tts?.speak(sentence, TextToSpeech.QUEUE_FLUSH, params, uttId)
        } else {
            fullTtsText += " $sentence"
            val params = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
            }
            tts?.speak(sentence, TextToSpeech.QUEUE_ADD, params, uttId)
        }
        
        ttsSentenceCount++
    }

    private fun checkIfTtsFinished() {
        if (isPipelineDone && ttsFinishedSentences >= ttsSentenceCount) {
            ttsStatus = TtsStatus.IDLE
            callback.onTtsDone()
            finishSession()
        }
    }

    fun speakText(text: String) {
        if (text.isBlank()) return
        fullTtsText = text
        remainingTtsText = text
        ttsStatus = TtsStatus.SPEAKING
        callback.onTtsStart()
        
        ttsSentenceCount = 1
        ttsFinishedSentences = 0
        isPipelineDone = true

        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "kritha-utt-0")
        }
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "kritha-utt-0")
    }

    fun pauseTts() {
        if (isTtsSpeaking) {
            tts?.stop()
            ttsStatus = TtsStatus.PAUSED
            callback.onTtsPause()
        }
    }

    fun resumeTts() {
        if (isTtsPaused && remainingTtsText.isNotBlank()) {
            speakText(remainingTtsText)
        } else if (fullTtsText.isNotBlank()) {
            speakText(fullTtsText)
        }
    }

    fun replayTts() {
        if (fullTtsText.isNotBlank()) {
            speakText(fullTtsText)
        }
    }

    fun stopTts() {
        autoTts = false
        ttsStreamingBuffer.clear()
        tts?.stop()
        ttsStatus = TtsStatus.IDLE
        callback.onTtsDone()
    }

    override fun onReadyForSpeech(params: Bundle?)  { callback.onListening() }
    override fun onBeginningOfSpeech()              = Unit
    override fun onRmsChanged(rmsdB: Float) {
        WakeWordEventHub.emitAssistant("rms", rms = rmsdB)
        callback.onRmsChanged(rmsdB)
    }
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech()                    = Unit
    override fun onPartialResults(partial: Bundle?) {
        val transcript = partial?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
        if (!transcript.isNullOrBlank()) {
            callback.onPartial(transcript)
        }
    }
    override fun onEvent(type: Int, params: Bundle?) = Unit

    override fun onResults(results: Bundle?) {
        val transcript = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()?.trim().orEmpty()

        cleanupRecognizer()
        WakeWordForegroundService.resumeListening()
        callback.onProcessing(transcript)
        runPipeline(transcript)
    }

    override fun onError(error: Int) {
        cleanupRecognizer()
        if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY && busyRetryCount < 10) {
            busyRetryCount++
            Log.w(TAG, "Recognizer busy, retrying ($busyRetryCount/10)...")
            mainHandler.postDelayed({ initRecognizer() }, 800)
            return
        }
        val message = when (error) {
            SpeechRecognizer.ERROR_NO_MATCH          -> "I didn't catch that."
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT    -> "I didn't hear anything."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY   -> "Speech recognition is busy."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission missing."
            else -> "Speech recognition failed (code $error)."
        }
        Log.e(TAG, "STT error $error: $message")
        callback.onError(message)
        speakText(message)
    }

    private fun initTts() {
        tts = TtsManager.getInstance(appContext)
        tts?.language = Locale.US
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                mainHandler.post {
                    ttsStatus = TtsStatus.SPEAKING
                    if (utteranceId?.endsWith("-0") == true) {
                        callback.onTtsStart()
                    }
                }
            }

            override fun onDone(utteranceId: String?) {
                mainHandler.post {
                    ttsFinishedSentences++
                    checkIfTtsFinished()
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    ttsFinishedSentences++
                    checkIfTtsFinished()
                }
            }

            override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                if (start in 0..fullTtsText.length) {
                    remainingTtsText = fullTtsText.substring(start)
                }
            }
        })
        ttsReady = true
        pendingTts?.let { text ->
            pendingTts = null
            speakText(text)
        }
    }

    private var busyRetryCount = 0

    private fun initRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(appContext)) {
            callback.onError("Speech recognition not available on this device")
            finishSession()
            return
        }

        mainHandler.postDelayed({
            if (done) return@postDelayed
            cleanupRecognizer()
            try {
                recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                    setRecognitionListener(this@NativeAssistantSession)
                    startListening(buildIntent())
                }
                Log.d(TAG, "STT started")
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to create SpeechRecognizer", e)
                onError(SpeechRecognizer.ERROR_RECOGNIZER_BUSY)
            }
        }, 150)
    }

    private fun cleanupRecognizer() {
        recognizer?.runCatching { cancel() }
        recognizer?.setRecognitionListener(null)
        recognizer = null
    }

    private fun finish(transcript: String?, response: String) {
        if (done) return
        callback.onFinished(transcript, response)
        if (response.isNotBlank() && autoTts) {
            speakText(response)
        } else {
            finishSession()
        }
    }

    private fun finishSession() {
        if (done) return
        done = true
        WakeWordForegroundService.resumeListening()
        callback.onSessionFinished()
    }

    private fun buildIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

    companion object {
        private const val TAG = "NativeAssistantSession"
    }
}
