package expo.modules.kritha

import android.content.Context
import android.os.SystemClock
import expo.modules.kritha.db.DBManager
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

    @Volatile var activeChatSessionId: String = ""
    @Volatile var activeAssistantRunId: String = ""
    @Volatile var activeRequestId: String = ""
    @Volatile var currentState: String = "IDLE"
    @Volatile var currentTranscript: String = ""
    @Volatile var currentResponse: String = ""
    @Volatile var customInstructions: String = ""
    @Volatile var userName: String = ""

    val systemPrompt: String
        get() {
            val nameClause = if (userName.isNotBlank() && userName.lowercase() != "your name") " You are speaking with $userName." else ""
            return """
                You are Kritha, an intelligent personal AI assistant.$nameClause

                Be helpful, accurate, concise, and natural. Understand the user's intent and context before responding. Follow instructions carefully, remember relevant conversation context, and never fabricate facts, actions, or results.

                Give direct, practical answers. Ask for clarification only when genuinely necessary. Correct mistakes honestly instead of agreeing blindly. Adapt your tone to the situation and avoid unnecessary repetition, filler, or excessive explanations.
            """.trimIndent()
        }

    private var activeJob: Job? = null

    fun init(context: Context) {
        DBManager.init(context)
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
            "ttsState" to mapOf(
                "isSpeaking" to TtsManager.isSpeaking,
                "isPaused" to TtsManager.isPaused,
                "messageId" to TtsManager.activeMessageId
            )
        )
    }

    fun startSession(context: Context, chatSessionId: String? = null) {
        init(context)
        if (!chatSessionId.isNullOrBlank()) {
            activeChatSessionId = chatSessionId
        }
        WakeWordForegroundService.triggerAssistantSession(context)
    }

    fun beginNewChat() {
        if (activeAssistantRunId.isNotBlank() && currentState != "IDLE") {
            cancel(activeAssistantRunId, activeRequestId)
        }
        activeChatSessionId = ""
        activeAssistantRunId = ""
        activeRequestId = ""
        currentTranscript = ""
        currentResponse = ""
        currentState = "IDLE"
        WakeWordEventHub.emitActiveChatCleared()
    }

    fun openChat(sessionId: String) {
        if (activeAssistantRunId.isNotBlank() && currentState != "IDLE") {
            cancel(activeAssistantRunId, activeRequestId)
        }
        activeChatSessionId = sessionId
        activeAssistantRunId = ""
        activeRequestId = ""
        currentTranscript = ""
        currentResponse = ""
        currentState = "IDLE"

        val messages = DBManager.getMessages(sessionId)
        for (msg in messages) {
            WakeWordEventHub.emitMessagePersisted(
                sessionId,
                msg["id"] as String,
                msg["role"] as String,
                msg["text"] as String,
                msg["created_at"] as Long
            )
        }
    }

    fun pinChat(sessionId: String, pinned: Boolean) {
        DBManager.setSessionPinned(sessionId, pinned)
        WakeWordEventHub.emitChatPinned(sessionId, pinned)
    }

    fun archiveChat(sessionId: String, archived: Boolean) {
        DBManager.setSessionArchived(sessionId, archived)
        WakeWordEventHub.emitChatArchived(sessionId, archived)
        if (archived && activeChatSessionId == sessionId) {
            beginNewChat()
        }
    }

    fun deleteChat(sessionId: String) {
        DBManager.deleteSession(sessionId)
        WakeWordEventHub.emitChatDeleted(sessionId)
        beginNewChat()
    }

    fun submitText(
        context: Context,
        text: String,
        chatSessionId: String? = null,
        modelId: String? = null,
        assistantRunId: String? = null,
        origin: String = "MANUAL_TYPING"
    ) {
        if (text.isBlank()) return
        init(context)

        scope.launch {
            mutex.withLock {
                // Cancel any ongoing job before starting a new turn
                activeJob?.cancel()

                val turnInfo = DBManager.prepareTurn(chatSessionId, text)
                val targetChatSessionId = turnInfo["sessionId"] as String
                val isNewSession = turnInfo["sessionCreated"] as Boolean
                val sessionTitle = turnInfo["sessionTitle"] as String
                val sessionCreatedAt = turnInfo["sessionCreatedAt"] as Long
                val userMessageId = turnInfo["userMessageId"] as String
                val userMessageCreatedAt = turnInfo["userMessageCreatedAt"] as Long

                if (isNewSession) {
                    WakeWordEventHub.emitChatCreated(targetChatSessionId, sessionTitle, sessionCreatedAt)
                }
                if (userMessageId.isNotBlank()) {
                    WakeWordEventHub.emitMessagePersisted(
                        targetChatSessionId,
                        userMessageId,
                        "user",
                        text,
                        userMessageCreatedAt
                    )
                }

                val runId = assistantRunId.ifNullOrBlank { "run_${UUID.randomUUID()}" }
                val reqId = "req_${UUID.randomUUID()}"
                val assistantMessageId = "${runId}_msg"

                activeChatSessionId = targetChatSessionId
                activeAssistantRunId = runId
                activeRequestId = reqId
                currentTranscript = text
                currentResponse = ""

                TtsManager.prepareRun(targetChatSessionId, runId, reqId, assistantMessageId)

                val shouldAutoTts = (origin == "WAKE_WORD" || origin == "MANUAL_DICTATION")

                currentState = "THINKING"
                WakeWordEventHub.emitSessionStart(targetChatSessionId, runId, reqId, origin = origin)
                WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "THINKING", transcript = text, origin = origin)

                val job = launch {
                    try {
                        val pipeline = IntelligencePipeline(context)
                        val fullResponse = StringBuilder()
                        val pipelineResult = pipeline.process(targetChatSessionId, text) { token ->
                            fullResponse.append(token)
                            currentResponse = fullResponse.toString()
                            currentState = "GENERATING"
                            WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "GENERATING", origin = origin)
                            WakeWordEventHub.emitTextDelta(targetChatSessionId, runId, reqId, token, messageId = assistantMessageId, origin = origin)

                            if (shouldAutoTts) {
                                TtsManager.handleStreamingChunk(context, token, targetChatSessionId, runId, reqId)
                            }
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
                                    WakeWordEventHub.emitTextDelta(targetChatSessionId, runId, reqId, msg, messageId = assistantMessageId, origin = origin)
                                    if (shouldAutoTts) {
                                        TtsManager.handleStreamingChunk(context, msg, targetChatSessionId, runId, reqId)
                                    }
                                }
                                fullResponse.toString()
                            }
                        }
                        currentResponse = finalResponse

                        // Authoritative Native DB Persistence at turn completion
                        val finalMsgInfo = DBManager.saveAssistantResponse(targetChatSessionId, finalResponse, assistantMessageId)
                        if (finalMsgInfo.isNotEmpty()) {
                            WakeWordEventHub.emitMessagePersisted(
                                targetChatSessionId,
                                finalMsgInfo["id"] as String,
                                "assistant",
                                finalResponse,
                                finalMsgInfo["created_at"] as Long
                            )
                        }

                        withContext(Dispatchers.Main) {
                            if (shouldAutoTts) {
                                TtsManager.flushStreaming(context)
                            }
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
                                WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "SPEAKING", origin = origin)
                            } else {
                                currentState = "IDLE"
                                WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "IDLE", origin = origin)
                                WakeWordEventHub.emitSessionEnd(targetChatSessionId, runId, reqId, origin = origin)
                            }
                        }
                    } catch (e: Exception) {
                        if (e is kotlinx.coroutines.CancellationException) {
                            currentState = "CANCELLING"
                            WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "CANCELLING", origin = origin)
                        } else {
                            currentState = "ERROR"
                            withContext(Dispatchers.Main) {
                                WakeWordEventHub.emitError(targetChatSessionId, runId, reqId, e.message ?: "Generation failed", origin = origin)
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

    suspend fun submitTextAndAwait(
        context: Context,
        text: String,
        modelId: String? = null
    ): String = withContext(Dispatchers.IO) {
        if (text.isBlank()) return@withContext ""
        init(context)

        var finalResponse = ""
        val targetChatSessionId = if (activeChatSessionId.isNotBlank()) activeChatSessionId else System.currentTimeMillis().toString()

        try {
            val fullResponse = StringBuilder()
            val l2 = L2LocalLLM(context)
            
            val messages = expo.modules.kritha.intelligence.ConversationContextBuilder.buildContext(
                systemPrompt = systemPrompt,
                customInstructions = customInstructions,
                history = emptyList(),
                currentMessage = text,
                isCloud = false
            )

            val result = l2.infer(messages, modelId = modelId) { token ->
                fullResponse.append(token)
            }
            finalResponse = if (!result.isNullOrBlank()) result else fullResponse.toString()
            DBManager.saveConversationTurn(targetChatSessionId, text, finalResponse)
        } catch (e: Exception) {
            finalResponse = ""
        }
        finalResponse
    }

    private var nativeVoiceSession: NativeAssistantSession? = null

    fun startVoiceSession(context: Context, chatSessionId: String? = null, origin: String = "WAKE_WORD") {
        init(context)

        val targetChatSessionId = when {
            !chatSessionId.isNullOrBlank() -> chatSessionId
            activeChatSessionId.isNotBlank() -> activeChatSessionId
            else -> System.currentTimeMillis().toString()
        }
        val runId = "run_${UUID.randomUUID()}"
        val reqId = "req_${UUID.randomUUID()}"
        val assistantMessageId = "${runId}_msg"

        activeChatSessionId = targetChatSessionId
        activeAssistantRunId = runId
        activeRequestId = reqId

        TtsManager.prepareRun(targetChatSessionId, runId, reqId, assistantMessageId)

        WakeWordEventHub.emitSessionStart(targetChatSessionId, runId, reqId, origin = origin)
        WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "IDLE", origin = origin)

        nativeVoiceSession?.shutdown()

        var lastRmsEmitAt = 0L
        nativeVoiceSession = NativeAssistantSession(
            context,
            object : NativeAssistantSession.Callback {
                override fun onListening() {
                    currentState = "LISTENING"
                    WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "LISTENING", origin = origin)
                }

                override fun onRmsChanged(rmsdB: Float) {
                    val now = SystemClock.elapsedRealtime()
                    if (now - lastRmsEmitAt < RMS_EMIT_INTERVAL_MS) return
                    lastRmsEmitAt = now
                    WakeWordEventHub.emitMicrophoneChanged(targetChatSessionId, runId, owner = "STT", isClaimed = true, volumeRms = rmsdB, origin = origin)
                }

                override fun onPartial(transcript: String) {
                    currentTranscript = transcript
                    WakeWordEventHub.emitStateChanged(targetChatSessionId, runId, reqId, "LISTENING", transcript = transcript, origin = origin)
                }

                override fun onProcessing(transcript: String) {
                    currentTranscript = transcript
                    currentState = "THINKING"
                    
                    val turnInfo = DBManager.prepareTurn(activeChatSessionId, transcript)
                    val actChatId = turnInfo["sessionId"] as String
                    val isNewSession = turnInfo["sessionCreated"] as Boolean
                    val sessionTitle = turnInfo["sessionTitle"] as String
                    val sessionCreatedAt = turnInfo["sessionCreatedAt"] as Long
                    val userMessageId = turnInfo["userMessageId"] as String
                    val userMessageCreatedAt = turnInfo["userMessageCreatedAt"] as Long

                    if (isNewSession) {
                        WakeWordEventHub.emitChatCreated(actChatId, sessionTitle, sessionCreatedAt)
                    }
                    if (userMessageId.isNotBlank()) {
                        WakeWordEventHub.emitMessagePersisted(
                            actChatId,
                            userMessageId,
                            "user",
                            transcript,
                            userMessageCreatedAt
                        )
                    }
                    activeChatSessionId = actChatId

                    WakeWordEventHub.emitStateChanged(activeChatSessionId, runId, reqId, "THINKING", transcript = transcript, origin = origin)
                }

                override fun onStreaming(transcript: String, chunk: String) {
                    currentState = "GENERATING"
                    WakeWordEventHub.emitStateChanged(activeChatSessionId, runId, reqId, "GENERATING", origin = origin)
                    WakeWordEventHub.emitTextDelta(activeChatSessionId, runId, reqId, chunk, messageId = assistantMessageId, origin = origin)
                }

                override fun onFinished(transcript: String?, response: String) {
                    val promptText = transcript ?: ""
                    currentTranscript = promptText
                    currentResponse = response

                    val finalMsgInfo = DBManager.saveAssistantResponse(activeChatSessionId, response, assistantMessageId)
                    if (finalMsgInfo.isNotEmpty()) {
                        WakeWordEventHub.emitMessagePersisted(
                            activeChatSessionId,
                            finalMsgInfo["id"] as String,
                            "assistant",
                            response,
                            finalMsgInfo["created_at"] as Long
                        )
                    }

                    WakeWordEventHub.emitTextComplete(activeChatSessionId, runId, reqId, response, messageId = assistantMessageId, transcript = promptText, origin = origin)

                    currentState = "IDLE"
                    WakeWordEventHub.emitStateChanged(activeChatSessionId, runId, reqId, "IDLE", origin = origin)
                }

                override fun onError(message: String) {
                    currentState = "ERROR"
                    WakeWordEventHub.emitError(targetChatSessionId, runId, reqId, message, origin = origin)
                }

                override fun onSessionFinished() {
                    nativeVoiceSession = null
                }
            }
        ).also {
            it.start()
        }
    }

    fun startListening(context: Context, chatSessionId: String? = null, origin: String = "MANUAL_DICTATION") {
        startVoiceSession(context, chatSessionId, origin = origin)
    }

    fun stopListening() {
        nativeVoiceSession?.stopListening()
    }

    fun playTts(
        context: Context,
        text: String,
        chatSessionId: String? = null,
        assistantRunId: String? = null,
        messageId: String? = null
    ) {
        init(context)
        val targetChatSessionId = chatSessionId ?: activeChatSessionId
        val targetRunId = assistantRunId ?: activeAssistantRunId
        TtsManager.speak(
            context,
            text,
            chatSessionId = targetChatSessionId,
            assistantRunId = targetRunId,
            requestId = activeRequestId,
            messageId = messageId
        )
    }

    fun pauseTts() {
        TtsManager.pause()
    }

    fun resumeTts() {
        TtsManager.resume()
    }

    fun stopTts() {
        TtsManager.stop(activeChatSessionId, activeAssistantRunId)
    }

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
                nativeVoiceSession?.cancelPipeline()
                TtsManager.stop(targetChatSessionId, targetRunId)
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

    fun dismiss(assistantRunId: String = "") {
        cancel(assistantRunId = assistantRunId)
        WakeWordListeningActivity.stopSessionIfActive()
    }

    private inline fun String?.ifNullOrBlank(defaultValue: () -> String): String {
        return if (this.isNullOrBlank()) defaultValue() else this
    }
}
