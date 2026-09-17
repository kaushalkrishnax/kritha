package expo.modules.kritha.litertlm

import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.RuntimeProvider

class LiteRTLLMRuntimeProvider : RuntimeProvider {
    override val id: RuntimeId = RuntimeId.LITERT_LM
    
    override fun isAvailable(): Boolean = true

    private var llmEngine: LiteRTLLM? = null

    override fun initialize(context: android.content.Context) {
        if (llmEngine == null) {
            llmEngine = LiteRTLLM(context)
        }
    }

    override fun llm(): Any? = llmEngine
}
