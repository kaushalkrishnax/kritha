package expo.modules.kritha.litertlm

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.LiteRTLLMRuntimeProviderRegistration
import expo.modules.kritha.runtime.llm.LlmProvider

class LiteRTLLMRuntimeProvider : LiteRTLLMRuntimeProviderRegistration {
    override val id: RuntimeId = RuntimeId.LITERT_LM
    
    override fun isAvailable(): Boolean = true

    private var llmEngine: LiteRTLLM? = null

    override fun initialize(context: android.content.Context) {
        if (llmEngine == null) {
            llmEngine = LiteRTLLM(context)
        }
    }

    override fun llm(): LlmProvider? = llmEngine
}
