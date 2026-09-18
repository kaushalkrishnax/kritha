package expo.modules.kritha.runtime

import expo.modules.kritha.runtime.llm.LlmProvider
import expo.modules.kritha.runtime.tts.TtsProvider
import java.util.ServiceLoader

enum class RuntimeStatus {
    NOT_INSTALLED,
    CHECKING,
    INSTALLING,
    INSTALLED,
    INITIALIZING,
    READY,
    FAILED,
    CANCELLED,
    PERMISSION_REQUIRED
}

interface RuntimeProvider {
    val id: RuntimeId
    fun isAvailable(): Boolean

    fun initialize(context: android.content.Context)

    // Runtime capabilities, mapped generically
    fun tts(): TtsProvider? = null
    fun llm(): LlmProvider? = null
    fun asr(): Any? = null

    fun inspectModel(descriptor: Any): Map<String, Any?>? = null
}

interface LiteRTRuntimeProviderRegistration : RuntimeProvider
interface LiteRTLLMRuntimeProviderRegistration : RuntimeProvider
interface OnnxRuntimeProviderRegistration : RuntimeProvider

internal fun loadRuntimeProviders(
    runtime: RuntimeId,
    classLoader: ClassLoader
): ServiceLoader<out RuntimeProvider> = when (runtime) {
    RuntimeId.LITERT -> ServiceLoader.load(LiteRTRuntimeProviderRegistration::class.java, classLoader)
    RuntimeId.LITERT_LM -> ServiceLoader.load(LiteRTLLMRuntimeProviderRegistration::class.java, classLoader)
    RuntimeId.ONNX -> ServiceLoader.load(OnnxRuntimeProviderRegistration::class.java, classLoader)
}
