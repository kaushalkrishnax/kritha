package expo.modules.kritha.wakeword

import java.util.Collections

object WakeWordEventHub {
    var listener: ((keyword: String, confidence: Float) -> Unit)? = null
    var assistantEventListener: ((type: String, payload: Map<String, Any?>) -> Unit)? = null

    private val endedSessionIds = Collections.synchronizedSet(HashSet<String>())

    fun emitWakeWord(keyword: String, confidence: Float) {
        listener?.invoke(keyword, confidence)
    }

    private fun buildPayload(
        chatSessionId: String? = null,
        assistantRunId: String? = null,
        requestId: String? = null,
        origin: String? = null
    ): MutableMap<String, Any?> {
        val payload = mutableMapOf<String, Any?>()
        if (!chatSessionId.isNullOrBlank()) payload["chatSessionId"] = chatSessionId
        if (!assistantRunId.isNullOrBlank()) payload["assistantRunId"] = assistantRunId
        if (!requestId.isNullOrBlank()) payload["requestId"] = requestId
        if (!origin.isNullOrBlank()) payload["origin"] = origin
        return payload
    }

    fun emitSessionStart(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String? = null,
        origin: String? = null
    ) {
        if (assistantRunId.isNotBlank()) {
            endedSessionIds.remove(assistantRunId)
        }
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        assistantEventListener?.invoke("SESSION_START", payload)
    }

    fun emitSessionEnd(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String? = null,
        origin: String? = null
    ) {
        if (assistantRunId.isBlank()) return
        if (endedSessionIds.add(assistantRunId)) {
            val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
            assistantEventListener?.invoke("SESSION_END", payload)
        }
    }

    fun emitStateChanged(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String?,
        state: String,
        transcript: String? = null,
        origin: String? = null
    ) {
        val canonicalState = when (state.uppercase()) {
            "LISTENING" -> "LISTENING"
            "THINKING", "PROCESSING" -> "THINKING"
            "GENERATING", "RESPONDING", "STREAMING" -> "GENERATING"
            "SPEAKING" -> "SPEAKING"
            "CANCELLING" -> "CANCELLING"
            "ERROR" -> "ERROR"
            "IDLE" -> "IDLE"
            else -> "IDLE"
        }
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        payload["state"] = if (state.uppercase() == "IDLE") "IDLE" else canonicalState
        if (transcript != null) payload["transcript"] = transcript
        assistantEventListener?.invoke("STATE_CHANGED", payload)
    }

    fun emitChatCreated(chatSessionId: String, title: String, createdAt: Long) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        payload["title"] = title
        payload["createdAt"] = createdAt
        assistantEventListener?.invoke("CHAT_CREATED", payload)
    }

    fun emitChatRenamed(chatSessionId: String, title: String) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        payload["title"] = title
        assistantEventListener?.invoke("CHAT_RENAMED", payload)
    }

    fun emitChatPinned(chatSessionId: String, pinned: Boolean) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        payload["pinned"] = pinned
        assistantEventListener?.invoke("CHAT_PINNED", payload)
    }

    fun emitChatArchived(chatSessionId: String, archived: Boolean) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        payload["archived"] = archived
        assistantEventListener?.invoke("CHAT_ARCHIVED", payload)
    }

    fun emitChatDeleted(chatSessionId: String) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        assistantEventListener?.invoke("CHAT_DELETED", payload)
    }

    fun emitActiveChatCleared() {
        assistantEventListener?.invoke("ACTIVE_CHAT_CLEARED", mapOf<String, Any>())
    }

    fun emitMessagePersisted(
        chatSessionId: String,
        messageId: String,
        role: String,
        text: String,
        createdAt: Long
    ) {
        val payload = mutableMapOf<String, Any?>()
        payload["chatSessionId"] = chatSessionId
        payload["messageId"] = messageId
        payload["role"] = role
        payload["text"] = text
        payload["createdAt"] = createdAt
        assistantEventListener?.invoke("MESSAGE_PERSISTED", payload)
    }

    fun emitTextDelta(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String,
        chunk: String,
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        payload["chunk"] = chunk
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TEXT_DELTA", payload)
    }

    fun emitTextComplete(
        chatSessionId: String,
        assistantRunId: String,
        requestId: String,
        response: String,
        messageId: String? = null,
        transcript: String = "",
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        payload["response"] = response
        if (messageId != null) payload["messageId"] = messageId
        payload["transcript"] = transcript
        assistantEventListener?.invoke("TEXT_COMPLETE", payload)
    }

    fun emitTtsStart(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_START", payload)
    }

    fun emitTtsPause(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_PAUSE", payload)
    }

    fun emitTtsResume(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_RESUME", payload)
    }

    fun emitTtsStop(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_STOP", payload)
    }

    fun emitTtsComplete(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_COMPLETE", payload)
    }

    fun emitTtsError(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        message: String,
        messageId: String? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        payload["message"] = message
        if (messageId != null) payload["messageId"] = messageId
        assistantEventListener?.invoke("TTS_ERROR", payload)
    }

    fun emitMicrophoneChanged(
        chatSessionId: String = "",
        assistantRunId: String = "",
        owner: String,
        isClaimed: Boolean,
        volumeRms: Float? = null,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, origin = origin)
        payload["owner"] = owner
        payload["isClaimed"] = isClaimed
        if (volumeRms != null) payload["volumeRms"] = volumeRms
        assistantEventListener?.invoke("MICROPHONE_CHANGED", payload)
    }

    fun emitError(
        chatSessionId: String = "",
        assistantRunId: String = "",
        requestId: String = "",
        message: String,
        origin: String? = null
    ) {
        val payload = buildPayload(chatSessionId, assistantRunId, requestId, origin)
        payload["message"] = message
        assistantEventListener?.invoke("ERROR", payload)
        emitStateChanged(
            chatSessionId = chatSessionId,
            assistantRunId = assistantRunId,
            requestId = requestId,
            state = "ERROR",
            origin = origin
        )
    }
}
