package expo.modules.kritha.intelligence

/**
 * Native representation of a single conversation turn.
 */
enum class Role(val value: String) {
    SYSTEM("system"),
    USER("user"),
    ASSISTANT("assistant")
}

data class ConversationMessage(
    val role: Role,
    val content: String
)