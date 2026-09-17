package expo.modules.kritha.runtime

enum class RuntimeStatus {
    NOT_INSTALLED,
    CHECKING,
    INSTALLING,
    INSTALLED,
    INITIALIZING,
    READY,
    FAILED,
    CANCELLED
}

interface RuntimeProvider {
    val id: RuntimeId
    fun isAvailable(): Boolean

    fun initialize(context: android.content.Context)

    // Runtime capabilities, mapped generically
    fun tts(): Any? = null
    fun llm(): Any? = null
    fun asr(): Any? = null
    
    fun inspectModel(descriptor: Any): Map<String, Any?>? = null
}
