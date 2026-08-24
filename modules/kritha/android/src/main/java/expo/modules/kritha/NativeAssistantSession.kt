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
    }

    private val appContext   = context.applicationContext
    private val mainHandler  = Handler(Looper.getMainLooper())
    private val scope        = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val pipeline     = IntelligencePipeline(appContext)

    private var recognizer: SpeechRecognizer? = null
    private var done                          = false

    private var pipelineJob: Job? = null
    private var isPipelineDone = false

    fun start() {
        mainHandler.post {
            initRecognizer()
        }
    }

    fun shutdown() {
        mainHandler.post {
            autoTts = false
            expo.modules.kritha.intelligence.L2LocalLLM.cancelInference()
            expo.modules.kritha.intelligence.L3CloudLLM.cancelInference()
            pipelineJob?.cancel()
            pipelineJob = null
            scope.cancel()
            pipeline.close()
            cleanupRecognizer()
            MicrophoneManager.releaseFromStt()
            TtsManager.stop()
        }
    }

    fun cancelPipeline() {
        mainHandler.post {
            autoTts = false
            expo.modules.kritha.intelligence.L2LocalLLM.cancelInference()
            expo.modules.kritha.intelligence.L3CloudLLM.cancelInference()
            pipelineJob?.cancel()
            pipelineJob = null
            cleanupRecognizer()
            MicrophoneManager.releaseFromStt()
            TtsManager.stop()
        }
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

    @Volatile var autoTts: Boolean = false

    fun processPrompt(transcript: String, shouldAutoTts: Boolean) {
        if (transcript.isBlank()) return
        autoTts = shouldAutoTts
        cleanupRecognizer()
        callback.onProcessing(transcript)
        runPipeline(transcript)
    }

    private fun runPipeline(transcript: String) {
        isPipelineDone = false

        pipelineJob = scope.launch {
            val result = pipeline.process(AssistantCore.activeChatSessionId, transcript) { chunk ->
                withContext(Dispatchers.Main) {
                    callback.onStreaming(transcript, chunk)
                    if (autoTts) {
                        TtsManager.handleStreamingChunk(
                            appContext, chunk, AssistantCore.activeChatSessionId,
                            AssistantCore.activeAssistantRunId, AssistantCore.activeRequestId,
                            "${AssistantCore.activeAssistantRunId}_msg"
                        )
                    }
                }
            }
            withContext(Dispatchers.Main) {
                isPipelineDone = true
                when (result) {
                    is IntelligencePipeline.Result.Hit -> {
                        callback.onFinished(transcript, result.response)
                        if (autoTts) {
                            TtsManager.flushStreaming(appContext)
                        }
                        finishSession()
                    }
                    is IntelligencePipeline.Result.Miss -> {
                        val msg = "I'm sorry, I couldn't process that request."
                        callback.onFinished(transcript, msg)
                        if (autoTts) {
                            TtsManager.speak(
                                appContext, msg, AssistantCore.activeChatSessionId,
                                AssistantCore.activeAssistantRunId, AssistantCore.activeRequestId,
                                "${AssistantCore.activeAssistantRunId}_msg"
                            )
                        }
                        finishSession()
                    }
                }
            }
        }
    }



    override fun onReadyForSpeech(params: Bundle?)  { callback.onListening() }
    override fun onBeginningOfSpeech()              = Unit
    override fun onRmsChanged(rmsdB: Float) {
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

        autoTts = true
        cleanupRecognizer()
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
        if (autoTts) {
            TtsManager.speak(
                appContext, message, AssistantCore.activeChatSessionId,
                AssistantCore.activeAssistantRunId, AssistantCore.activeRequestId,
                "${AssistantCore.activeAssistantRunId}_msg"
            )
        }
        finishSession()
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
                MicrophoneManager.claimForStt()
                recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                    setRecognitionListener(this@NativeAssistantSession)
                    startListening(buildIntent())
                }
                Log.d(TAG, "STT started with exclusive mic claim")
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
        MicrophoneManager.releaseFromStt()
    }

    private fun finish(transcript: String?, response: String) {
        if (done) return
        callback.onFinished(transcript, response)
        if (response.isNotBlank() && autoTts) {
            TtsManager.speak(
                appContext, response, AssistantCore.activeChatSessionId,
                AssistantCore.activeAssistantRunId, AssistantCore.activeRequestId,
                "${AssistantCore.activeAssistantRunId}_msg"
            )
        }
        finishSession()
    }

    private fun finishSession() {
        if (done) return
        done = true
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
