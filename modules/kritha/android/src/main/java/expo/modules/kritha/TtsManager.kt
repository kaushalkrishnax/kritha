package expo.modules.kritha

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import expo.modules.kritha.wakeword.WakeWordEventHub
import java.util.Collections
import java.util.Locale

object TtsManager {
    @Volatile
    private var ttsInstance: TextToSpeech? = null

    @Volatile
    var isReady: Boolean = false
        private set

    @Volatile
    var activeChatSessionId: String = ""
    @Volatile
    var activeAssistantRunId: String = ""
    @Volatile
    var activeRequestId: String = ""
    @Volatile
    var activeMessageId: String? = null

    @Volatile
    var isSpeaking: Boolean = false
        private set
    @Volatile
    var isPaused: Boolean = false
        private set
    @Volatile
    var isCancelled: Boolean = false
        private set
    @Volatile
    private var isResuming: Boolean = false

    @Volatile
    private var lastContext: Context? = null

    private val pendingClauses = Collections.synchronizedList(ArrayList<String>())
    @Volatile
    private var currentClauseIndex: Int = 0
    @Volatile
    private var queuedClauseIndex: Int = -1

    private val streamingBuffer = StringBuilder()

    fun prewarm(context: Context) {
        if (ttsInstance != null) return
        val appContext = context.applicationContext
        lastContext = appContext
        ttsInstance = TextToSpeech(appContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsInstance?.language = Locale.US
                isReady = true
                ttsInstance?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        if (!isCancelled) {
                            isSpeaking = true
                            isPaused = false

                            val parts = utteranceId?.split(":") ?: emptyList()
                            val cbRunId = parts.getOrNull(0)?.takeIf { it != "tts" } ?: activeAssistantRunId
                            val cbMsgId = parts.getOrNull(1)?.takeIf { it != "null" } ?: activeMessageId

                            if (isResuming) {
                                isResuming = false
                                WakeWordEventHub.emitTtsResume(
                                    activeChatSessionId,
                                    cbRunId,
                                    activeRequestId,
                                    cbMsgId
                                )
                            } else if (currentClauseIndex == 0) {
                                WakeWordEventHub.emitTtsStart(
                                    activeChatSessionId,
                                    cbRunId,
                                    activeRequestId,
                                    cbMsgId
                                )
                            }

                            maybeStartBargeIn()
                        }
                    }

                    override fun onDone(utteranceId: String?) {
                        if (isCancelled || isPaused) return

                        val parts = utteranceId?.split(":") ?: emptyList()
                        val cbRunId = parts.getOrNull(0)?.takeIf { it != "tts" } ?: activeAssistantRunId
                        val cbMsgId = parts.getOrNull(1)?.takeIf { it != "null" } ?: activeMessageId

                        val nextIndex = currentClauseIndex + 1
                        synchronized(pendingClauses) {
                            currentClauseIndex = nextIndex
                            if (nextIndex < pendingClauses.size) {
                                if (queuedClauseIndex < nextIndex) {
                                    queuedClauseIndex = nextIndex
                                    val nextClause = pendingClauses[nextIndex]
                                    val uttId = "${cbRunId.ifBlank { "tts" }}:$cbMsgId:$nextIndex"
                                    val params = Bundle().apply {
                                        putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
                                    }
                                    ttsInstance?.speak(nextClause, TextToSpeech.QUEUE_ADD, params, uttId)
                                }
                            } else {
                                isSpeaking = false
                                isPaused = false
                                isResuming = false
                                BargeInMonitor.stop()
                                WakeWordEventHub.emitTtsComplete(
                                    activeChatSessionId,
                                    cbRunId,
                                    activeRequestId,
                                    cbMsgId
                                )
                            }
                        }
                    }

                    override fun onError(utteranceId: String?) {
                        val parts = utteranceId?.split(":") ?: emptyList()
                        val cbRunId = parts.getOrNull(0)?.takeIf { it != "tts" } ?: activeAssistantRunId
                        val cbMsgId = parts.getOrNull(1)?.takeIf { it != "null" } ?: activeMessageId

                        isSpeaking = false
                        isPaused = false
                        isResuming = false
                        BargeInMonitor.stop()
                        WakeWordEventHub.emitTtsError(
                            activeChatSessionId,
                            cbRunId,
                            activeRequestId,
                            "TTS engine error",
                            cbMsgId
                        )
                    }
                })
            }
        }
    }

    /**
     * Arms barge-in detection while speech is playing
     */
    private fun maybeStartBargeIn() {
        if (!BargeInMonitor.isEnabled || BargeInMonitor.isRunning) return
        val ctx = lastContext ?: return
        BargeInMonitor.start { AssistantCore.handleBargeIn(ctx) }
    }

    fun getInstance(context: Context): TextToSpeech? {
        if (ttsInstance == null) {
            prewarm(context)
        }
        return ttsInstance
    }

    private fun splitIntoClauses(text: String): List<String> {
        if (text.isBlank()) return emptyList()
        val clauses = mutableListOf<String>()
        val rawParts = text.split(Regex("(?<=[.!?\n;:]);*\\s+"))
        for (part in rawParts) {
            val trimmed = part.trim()
            if (trimmed.isNotBlank()) {
                if (trimmed.length > 120) {
                    var remaining = trimmed
                    while (remaining.length > 120) {
                        val splitIdx = remaining.indexOf(' ', 80)
                        if (splitIdx > 0) {
                            clauses.add(remaining.substring(0, splitIdx).trim())
                            remaining = remaining.substring(splitIdx).trim()
                        } else {
                            break
                        }
                    }
                    if (remaining.isNotBlank()) {
                        clauses.add(remaining)
                    }
                } else {
                    clauses.add(trimmed)
                }
            }
        }
        return if (clauses.isEmpty()) listOf(text.trim()) else clauses
    }

    fun speak(
        context: Context,
        text: String,
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null
    ) {
        if (text.isBlank()) return

        lastContext = context.applicationContext
        isCancelled = false
        isPaused = false
        isResuming = false
        activeChatSessionId = chatSessionId
        activeAssistantRunId = assistantRunId
        activeRequestId = requestId
        activeMessageId = messageId

        streamingBuffer.clear()

        val parsedClauses = splitIntoClauses(text)
        synchronized(pendingClauses) {
            pendingClauses.clear()
            pendingClauses.addAll(parsedClauses)
            currentClauseIndex = 0
            queuedClauseIndex = 0
        }

        val tts = getInstance(context) ?: return
        tts.stop()

        if (parsedClauses.isNotEmpty()) {
            val firstClause = parsedClauses[0]
            val uttId = "${assistantRunId.ifBlank { "tts" }}:$messageId:0"
            val params = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
            }
            tts.speak(firstClause, TextToSpeech.QUEUE_FLUSH, params, uttId)
        }
    }

    fun pause() {
        BargeInMonitor.stop()
        if (isSpeaking) {
            isSpeaking = false
            isPaused = true
            ttsInstance?.stop()
            WakeWordEventHub.emitTtsPause(
                activeChatSessionId,
                activeAssistantRunId,
                activeRequestId,
                activeMessageId
            )
        }
    }

    fun resume(context: Context? = null) {
        val ctx = context ?: lastContext
        synchronized(pendingClauses) {
            if (isPaused && currentClauseIndex < pendingClauses.size && ctx != null) {
                isPaused = false
                isCancelled = false
                isResuming = true
                queuedClauseIndex = currentClauseIndex
                val tts = getInstance(ctx) ?: return
                val clauseToSpeak = pendingClauses[currentClauseIndex]
                val uttId = "${activeAssistantRunId.ifBlank { "tts" }}:$activeMessageId:$currentClauseIndex"
                val params = Bundle().apply {
                    putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
                }
                tts.speak(clauseToSpeak, TextToSpeech.QUEUE_FLUSH, params, uttId)
            }
        }
    }

    fun stop(chatSessionId: String = "", assistantRunId: String = "") {
        BargeInMonitor.stop()
        val targetRunId = assistantRunId.ifBlank { activeAssistantRunId }
        var emitted = false
        if (activeAssistantRunId == targetRunId) {
            isCancelled = true
            isSpeaking = false
            isPaused = false
            isResuming = false
            synchronized(pendingClauses) {
                pendingClauses.clear()
                currentClauseIndex = 0
                queuedClauseIndex = -1
            }
            streamingBuffer.clear()
            ttsInstance?.stop()
            emitted = true
            WakeWordEventHub.emitTtsStop(
                chatSessionId.ifBlank { activeChatSessionId },
                targetRunId,
                activeRequestId,
                activeMessageId
            )
        } else if (assistantRunId.isNotBlank()) {
            WakeWordEventHub.emitTtsStop(
                chatSessionId,
                assistantRunId,
                "",
                null
            )
        }
    }

    fun prepareRun(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String,
        messageId: String?
    ) {
        BargeInMonitor.stop()
        activeChatSessionId = chatSessionId
        activeAssistantRunId = assistantRunId
        activeRequestId = requestId
        activeMessageId = messageId
        isCancelled = false
        synchronized(pendingClauses) {
            pendingClauses.clear()
            currentClauseIndex = 0
            queuedClauseIndex = -1
        }
        streamingBuffer.clear()
        ttsInstance?.stop()
        isSpeaking = false
        isPaused = false
        isResuming = false
    }

    fun handleStreamingChunk(
        context: Context,
        chunk: String,
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null
    ) {
        if (isCancelled && activeAssistantRunId == assistantRunId) {
            return
        }

        if (activeAssistantRunId != assistantRunId) {
            return
        }

        lastContext = context.applicationContext
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
                synchronized(pendingClauses) {
                    pendingClauses.add(clause)
                    if (!isSpeaking && !isPaused && queuedClauseIndex < pendingClauses.size - 1) {
                        val nextIndexToQueue = queuedClauseIndex + 1
                        queuedClauseIndex = nextIndexToQueue
                        val uttId = "${activeAssistantRunId.ifBlank { "tts" }}:$activeMessageId:$nextIndexToQueue"
                        val params = Bundle().apply {
                            putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
                        }
                        tts.speak(clause, TextToSpeech.QUEUE_ADD, params, uttId)
                    }
                }
            }
        }
    }

    fun flushStreaming(context: Context) {
        val remaining = streamingBuffer.toString().trim()
        streamingBuffer.clear()
        if (remaining.isNotBlank()) {
            val newClauses = splitIntoClauses(remaining)
            synchronized(pendingClauses) {
                pendingClauses.addAll(newClauses)
                if (!isSpeaking && !isPaused && !isCancelled && queuedClauseIndex < pendingClauses.size - 1) {
                    val tts = getInstance(context) ?: return
                    val nextIndexToQueue = queuedClauseIndex + 1
                    queuedClauseIndex = nextIndexToQueue
                    val clause = pendingClauses[nextIndexToQueue]
                    val uttId = "${activeAssistantRunId.ifBlank { "tts" }}:$activeMessageId:$nextIndexToQueue"
                    val params = Bundle().apply {
                        putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
                    }
                    tts.speak(clause, TextToSpeech.QUEUE_ADD, params, uttId)
                }
            }
        }
    }
}
