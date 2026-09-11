package expo.modules.kritha

import android.content.Context
import android.os.SystemClock
import expo.modules.kritha.intelligence.IntelligencePipeline
import expo.modules.kritha.intelligence.L2LocalLLM
import expo.modules.kritha.intelligence.L3CloudLLM
import expo.modules.kritha.wakeword.WakeWordEventHub
import expo.modules.kritha.wakeword.WakeWordForegroundService
import expo.modules.kritha.wakeword.WakeWordListeningActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.util.UUID

object AssistantCore {
    private val scope = CoroutineScope(Dispatchers.Default)
    private val mutex = Mutex()
    private const val RMS_EMIT_INTERVAL_MS = 100L

    @Volatile
    var activeChatSessionId: String = ""

    @Volatile
    var activeAssistantRunId: String = ""

    @Volatile
    var activeRequestId: String = ""

    @Volatile
    var currentState: String = "IDLE"

    @Volatile
    var currentTranscript: String = ""

    @Volatile
    var currentResponse: String = ""

    @Volatile
    var customInstructions: String = ""

    @Volatile
    var userName: String = ""

    private var activeJob: Job? = null

    /** Guards double-persistence of the active assistant turn's message. */
    @Volatile
    private var assistantMessagePersisted: Boolean = false

    fun init(context: Context) {
        val prefs = context.getSharedPreferences("kritha_settings", android.content.Context.MODE_PRIVATE)
        customInstructions = prefs.getString("custom_instructions", "") ?: ""
        userName = prefs.getString("user_name", "") ?: ""
    }

    fun getCurrentStateMap(): Map<String, Any?> {
        return mapOf(
            "state" to currentState,
            "chatSessionId" to activeChatSessionId,
            "assistantRunId" to activeAssistantRunId,
            "requestId" to activeRequestId,
            "transcript" to currentTranscript,
            "response" to currentResponse,
            "ttsState" to mapOf("isSpeaking" to false, "isPaused" to false, "messageId" to "")
        )
    }

    fun startSession(context: Context, chatSessionId: String? = null) {
        init(context)
        if (!chatSessionId.isNullOrBlank()) {
            activeChatSessionId = chatSessionId
        }
        WakeWordForegroundService.triggerAssistantSession(context)
    }

    fun clearActiveState() {
        if (activeAssistantRunId.isNotBlank() && currentState != "IDLE") {
            cancel(activeAssistantRunId, activeRequestId)
        }
        activeChatSessionId = ""
        activeAssistantRunId = ""
        activeRequestId = ""
        currentTranscript = ""
        currentResponse = ""
        currentState = "IDLE"
    }

    fun submitText(
        context: Context,
        text: String,
        chatSessionId: String? = null,
        modelId: String? = null,
        assistantRunId: String? = null,
        origin: String = "MANUAL_TYPING",
        history: List<Map<String, Any>> = emptyList()
    ) {
        if (text.isBlank()) return
        init(context)

        scope.launch {
            mutex.withLock {
                // Cancel any ongoing job before starting a new turn
                activeJob?.cancel()
                persistPartialAssistantResponse()

                val targetChatSessionId =
                    if (!chatSessionId.isNullOrBlank()) chatSessionId else UUID.randomUUID().toString()
                val userMsgTime = System.currentTimeMillis()
                val userMessageId = "msg_${UUID.randomUUID()}"

                WakeWordEventHub.emitMessagePersisted(
                    targetChatSessionId,
                    userMessageId,
                    "user",
                    text,
                    userMsgTime
                )

                val runId = assistantRunId.ifNullOrBlank { "run_${UUID.randomUUID()}" }
                val reqId = "req_${UUID.randomUUID()}"
                val assistantMessageId = "${runId}_msg"
                assistantMessagePersisted = false

                activeChatSessionId = targetChatSessionId
                activeAssistantRunId = runId
                activeRequestId = reqId
                currentTranscript = text
                currentResponse = ""

                

                val shouldAutoTts = (origin == "WAKE_WORD" || origin == "MANUAL_DICTATION")

                currentState = "THINKING"
                WakeWordEventHub.emitSessionStart(targetChatSessionId, runId, reqId, origin = origin)
                WakeWordEventHub.emitStateChanged(
                    targetChatSessionId,
                    runId,
                    reqId,
                    "THINKING",
                    transcript = text,
                    origin = origin
                )

                val job = launch {
                    try {
                        val pipeline = IntelligencePipeline(context)
                        val fullResponse = StringBuilder()
                        val pipelineResult = pipeline.process(targetChatSessionId, text, history) { token ->
                            fullResponse.append(token)
                            currentResponse = fullResponse.toString()
                            currentState = "GENERATING"
                            WakeWordEventHub.emitStateChanged(
                                targetChatSessionId,
                                runId,
                                reqId,
                                "GENERATING",
                                origin = origin
                            )
                            WakeWordEventHub.emitTextDelta(
                                targetChatSessionId,
                                runId,
                                reqId,
                                token,
                                messageId = assistantMessageId,
                                origin = origin
                            )

                            
                        }

                        val finalResponse = when (pipelineResult) {
                            is IntelligencePipeline.Result.Hit -> pipelineResult.response
                            is IntelligencePipeline.Result.Miss -> {
                                val selectedModel = modelId ?: ModelManager.getSelectedModel(context)
                                val isCloud = ModelCatalog.isCloudModel(selectedModel)
                                val msg = if (!isCloud && !ModelManager.isModelDownloaded(context, selectedModel)) {
                                    "Model '$selectedModel' is not downloaded yet. Please select another model or download it."
                                } else {
                                    "I couldn't process your request."
                                }
                                if (fullResponse.isEmpty()) {
                                    fullResponse.append(msg)
                                    WakeWordEventHub.emitTextDelta(
                                        targetChatSessionId,
                                        runId,
                                        reqId,
                                        msg,
                                        messageId = assistantMessageId,
                                        origin = origin
                                    )
                                    
                                }
                                fullResponse.toString()
                            }
                        }
                        currentResponse = finalResponse

                        val assistantMsgTime = System.currentTimeMillis()
                        WakeWordEventHub.emitMessagePersisted(
                            targetChatSessionId,
                            assistantMessageId,
                            "assistant",
                            finalResponse,
                            assistantMsgTime
                        )
                        assistantMessagePersisted = true

                        withContext(Dispatchers.Main) {
                            
                            WakeWordEventHub.emitTextComplete(
                                targetChatSessionId,
                                runId,
                                reqId,
                                finalResponse,
                                messageId = assistantMessageId,
                                transcript = text,
                                origin = origin
                            )
                            if (shouldAutoTts && finalResponse.isNotBlank()) {
                                currentState = "SPEAKING"
                                WakeWordEventHub.emitStateChanged(
                                    targetChatSessionId,
                                    runId,
                                    reqId,
                                    "SPEAKING",
                                    origin = origin
                                )
                            } else {
                                currentState = "IDLE"
                                WakeWordEventHub.emitStateChanged(
                                    targetChatSessionId,
                                    runId,
                                    reqId,
                                    "IDLE",
                                    origin = origin
                                )
                                WakeWordEventHub.emitSessionEnd(targetChatSessionId, runId, reqId, origin = origin)
                            }
                        }
                    } catch (e: Exception) {
                        if (e is kotlinx.coroutines.CancellationException) {
                            currentState = "CANCELLING"
                            WakeWordEventHub.emitStateChanged(
                                targetChatSessionId,
                                runId,
                                reqId,
                                "CANCELLING",
                                origin = origin
                            )
                        } else {
                            currentState = "ERROR"
                            withContext(Dispatchers.Main) {
                                WakeWordEventHub.emitError(
                                    targetChatSessionId,
                                    runId,
                                    reqId,
                                    e.message ?: "Generation failed",
                                    origin = origin
                                )
                                WakeWordEventHub.emitSessionEnd(targetChatSessionId, runId, reqId, origin = origin)
                            }
                        }
                    }
                }
                activeJob = job
                job.join()
            }
        }
    }

        
    fun cancelTurn() {
        val targetRunId = activeAssistantRunId
        val targetChatSessionId = activeChatSessionId

        activeJob?.cancel()
        activeJob = null
        L2LocalLLM.cancelInference()
        L3CloudLLM.cancelInference()
    }

    
    fun startVoiceSession(
        context: Context,
        chatSessionId: String? = null,
        origin: String = "WAKE_WORD",
        history: List<Map<String, Any>> = emptyList()
    ) {
        init(context)
        cancelTurn()
        // The actual STT is handled in JS via react-native-sherpa-onnx
        // We just prepare the session state here.
        val targetChatSessionId = when {
            !chatSessionId.isNullOrBlank() -> chatSessionId
            activeChatSessionId.isNotBlank() -> activeChatSessionId
            else -> System.currentTimeMillis().toString()
        }
        val runId = "run_${UUID.randomUUID()}"
        val reqId = "req_${UUID.randomUUID()}"
        activeChatSessionId = targetChatSessionId
        activeAssistantRunId = runId
        activeRequestId = reqId
        WakeWordEventHub.emitSessionStart(targetChatSessionId, runId, reqId, origin = origin)
        WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "LISTENING", origin = origin)
    }
fun startListening(
        context: Context,
        chatSessionId: String? = null,
        origin: String = "MANUAL_DICTATION",
        history: List<Map<String, Any>> = emptyList()
    ) {
        startVoiceSession(context, chatSessionId, origin = origin, history = history)
    }


    // ── Live Talk (AgentFlow) ──

    
    fun startLiveTalk(
        context: Context,
        chatSessionId: String? = null,
        history: List<Map<String, Any>> = emptyList()
    ) {
        init(context)
        cancelTurn()
        val targetChatSessionId = when {
            !chatSessionId.isNullOrBlank() -> chatSessionId
            activeChatSessionId.isNotBlank() -> activeChatSessionId
            else -> System.currentTimeMillis().toString()
        }
        val runId = "run_${UUID.randomUUID()}"
        val reqId = "req_${UUID.randomUUID()}"
        activeChatSessionId = targetChatSessionId
        activeAssistantRunId = runId
        activeRequestId = reqId
        WakeWordEventHub.emitSessionStart(targetChatSessionId, runId, reqId, origin = "LIVE_TALK")
        WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "LISTENING", origin = "LIVE_TALK")
    }

    // ── TTS controls ──

    





    fun cancel(assistantRunId: String = "", requestId: String = "") {
        val targetRunId = assistantRunId.ifBlank { activeAssistantRunId }
        val targetChatSessionId = activeChatSessionId
        val targetReqId = requestId.ifBlank { activeRequestId }

        if (targetRunId.isNotEmpty()) {
            currentState = "CANCELLING"
            WakeWordEventHub.emitStateChanged(targetChatSessionId, targetRunId, targetReqId, "CANCELLING")
        }

        scope.launch {
            try {
                activeJob?.cancel()
                L2LocalLLM.cancelInference()
                L3CloudLLM.cancelInference()
                
                persistPartialAssistantResponse()
                                                
                MicrophoneManager.releaseFromStt(targetRunId)
                WakeWordForegroundService.stopAssistantSession()
            } catch (e: Exception) {
                // Log exception
            } finally {
                withContext(Dispatchers.Main) {
                    currentState = "IDLE"
                    if (targetRunId.isNotEmpty()) {
                        WakeWordEventHub.emitStateChanged(targetChatSessionId, targetRunId, targetReqId, "IDLE")
                        WakeWordEventHub.emitSessionEnd(targetChatSessionId, targetRunId, targetReqId)
                    }
                }
            }
        }
    }

    private fun persistPartialAssistantResponse() {
        if (assistantMessagePersisted) return
        val partial = currentResponse
        if (partial.isBlank()) return
        if (activeAssistantRunId.isBlank()) return
        assistantMessagePersisted = true
        WakeWordEventHub.emitMessagePersisted(
            activeChatSessionId,
            "${activeAssistantRunId}_msg",
            "assistant",
            partial,
            System.currentTimeMillis()
        )
    }

    fun dismiss(assistantRunId: String = "") {
        cancel(assistantRunId = assistantRunId)
        WakeWordListeningActivity.stopSessionIfActive()
    }

    private inline fun String?.ifNullOrBlank(defaultValue: () -> String): String {
        return if (this.isNullOrBlank()) defaultValue() else this
    }
}
