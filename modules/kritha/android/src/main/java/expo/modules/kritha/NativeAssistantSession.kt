package expo.modules.kritha

import expo.modules.kritha.wakeword.*

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import expo.modules.kritha.intelligence.IntelligencePipeline
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class NativeAssistantSession(
    private val context: Context,
    private val callback: Callback
) {

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

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val pipeline = IntelligencePipeline(appContext)

    private var engine: AsrEngine? = null
    private var done = false

    private var pipelineJob: Job? = null
    private var isPipelineDone = false

    @Volatile
    var history: List<Map<String, Any>> = emptyList()

    fun start() {
        mainHandler.post {
            if (done) return@post
            engine = MoonshineAsrEngine(context, engineListener())
            engine?.start()
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
            cleanupEngine()
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
            cleanupEngine()
            TtsManager.stop()
        }
    }

    fun stopListening() {
        mainHandler.post {
            try {
                engine?.stopListening()
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ASR engine", e)
            }
        }
    }

    @Volatile
    var autoTts: Boolean = false

    fun processPrompt(transcript: String, shouldAutoTts: Boolean) {
        if (transcript.isBlank()) return
        autoTts = shouldAutoTts
        cleanupEngine()
        callback.onProcessing(transcript)
        runPipeline(transcript)
    }

    private fun runPipeline(transcript: String) {
        isPipelineDone = false

        pipelineJob = scope.launch {
            val result = pipeline.process(
                AssistantCore.activeChatSessionId,
                transcript,
                history = history
            ) { chunk ->
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

    private fun engineListener() = object : AsrEngine.Listener {
        override fun onListening() {
            callback.onListening()
        }

        override fun onRmsChanged(rmsdB: Float) {
            callback.onRmsChanged(rmsdB)
        }

        override fun onPartial(transcript: String) {
            callback.onPartial(transcript)
        }

        override fun onFinal(transcript: String) {
            autoTts = true
            cleanupEngine()
            callback.onProcessing(transcript)
            runPipeline(transcript)
        }

        override fun onError(message: String) {
            handleAsrError(message)
        }
    }

    private fun handleAsrError(message: String) {
        Log.e(TAG, "STT error: $message")
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

    private fun cleanupEngine() {
        engine?.shutdown()
        engine = null
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

    companion object {
        private const val TAG = "NativeAssistantSession"
    }
}
