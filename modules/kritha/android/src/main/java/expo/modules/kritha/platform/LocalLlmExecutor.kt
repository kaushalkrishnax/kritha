

package expo.modules.kritha.platform

import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.Message
import java.util.concurrent.ConcurrentHashMap

data class LocalLlmMessage(
    val role: String,
    val content: String,
)

internal class LocalLlmExecutor {

    private val activeConversations = ConcurrentHashMap<String, Conversation>()

    /**
     * Runs one generation request against the engine supplied by
     * [LiteRTEngineManager]. Calls [onDelta] with each incremental text chunk
     * and returns the full accumulated response text on success.
     *
     * If the coroutine is cancelled, the native generation is cancelled via
     * [cancelProcess] and [CancellationException] propagates to the caller.
     */
    @OptIn(ExperimentalApi::class)
    suspend fun generateLocal(
        requestId: String,
        modelPath: String,
        device: LiteRTEngineManager.Device,
        messages: List<LocalLlmMessage>,
        onDelta: (String) -> Unit,
    ): String {
        require(messages.isNotEmpty()) { "Message list must not be empty" }

        val engine = LiteRTEngineManager.getEngine(modelPath, device)

        val initialMessages = messages.dropLast(1).map { it.toSdkMessage() }
        val finalTurn = messages.last().toSdkMessage()

        val conversation = engine.createConversation(
            ConversationConfig(initialMessages = initialMessages)
        )
        activeConversations[requestId] = conversation

        var fullText = ""
        try {
            conversation.sendMessageAsync(finalTurn).collect { partial ->
                val chunk = conversation.renderMessageIntoString(partial)
                if (chunk.isNotEmpty()) {
                    fullText += chunk
                    onDelta(chunk)
                }
            }
            return fullText
        } finally {
            activeConversations.remove(requestId)
            runCatching { conversation.close() }
        }
    }

    /**
     * Signals the native C++ inference to stop for the given [requestId].
     * Must be called from a background thread (JNI is blocking).
     */
    fun cancelProcess(requestId: String) {
        activeConversations[requestId]?.cancelProcess()
    }

    private fun LocalLlmMessage.toSdkMessage(): Message = when (role) {
        "system" -> Message.system(content)
        "assistant" -> Message.model(content)
        else -> Message.user(content)
    }
}
