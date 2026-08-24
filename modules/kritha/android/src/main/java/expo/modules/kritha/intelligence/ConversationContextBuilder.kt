package expo.modules.kritha.intelligence

enum class Role(val value: String) {
    SYSTEM("system"),
    USER("user"),
    ASSISTANT("assistant")
}

data class ConversationMessage(
    val role: Role,
    val content: String
)

object ConversationContextBuilder {

    fun buildContext(
        systemPrompt: String,
        customInstructions: String,
        history: List<Map<String, Any>>,
        currentMessage: String,
        isCloud: Boolean
    ): List<ConversationMessage> {
        val messages = mutableListOf<ConversationMessage>()

        // SYSTEM PROMPT
        messages.add(ConversationMessage(Role.SYSTEM, systemPrompt))

        // CUSTOM INSTRUCTIONS
        if (customInstructions.isNotBlank()) {
            messages.add(ConversationMessage(Role.SYSTEM, customInstructions))
        }

        // BOUNDED HISTORY
        val limit = if (isCloud) 40 else 20
        val boundedHistory = history.takeLast(limit)

        boundedHistory.forEach { msg ->
            val role = if (msg["role"] == "user") Role.USER else Role.ASSISTANT
            val text = msg["text"] as? String ?: ""
            if (text.isNotBlank()) {
                messages.add(ConversationMessage(role, text))
            }
        }

        // CURRENT USER MESSAGE
        messages.add(ConversationMessage(Role.USER, currentMessage))

        return messages
    }
}
