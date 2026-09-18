package expo.modules.kritha.runtime

object RuntimeCatalog {
    fun allIds(): List<RuntimeId> = RuntimeId.values().toList()

    fun getModuleName(id: RuntimeId): String = when (id) {
        RuntimeId.LITERT -> "feature-litert"
        RuntimeId.LITERT_LM -> "feature-litertlm"
        RuntimeId.ONNX -> "feature-onnx"
    }

    /** Stable JS-facing identifier for a runtime. */
    fun getJsId(id: RuntimeId): String = when (id) {
        RuntimeId.LITERT -> "litert"
        RuntimeId.LITERT_LM -> "litert-lm"
        RuntimeId.ONNX -> "onnx"
    }

    fun fromJsId(jsId: String): RuntimeId? {
        return when (jsId.trim().lowercase().replace("_", "-")) {
            "litert" -> RuntimeId.LITERT
            "litert-lm", "litertlm" -> RuntimeId.LITERT_LM
            "onnx", "onnxruntime", "onnx-runtime" -> RuntimeId.ONNX
            else -> null
        }
    }

    fun getDisplayName(id: RuntimeId): String = when (id) {
        RuntimeId.LITERT -> "LiteRT"
        RuntimeId.LITERT_LM -> "LiteRT-LM"
        RuntimeId.ONNX -> "ONNX Runtime"
    }

    fun getDescription(id: RuntimeId): String = when (id) {
        RuntimeId.LITERT -> "On-device LiteRT execution for speech and vision tasks."
        RuntimeId.LITERT_LM -> "On-device local LLM execution via LiteRT-LM."
        RuntimeId.ONNX -> "On-device inference, speech, and local LLM execution via ONNX Runtime."
    }

    fun getCapabilities(id: RuntimeId): List<String> = when (id) {
        RuntimeId.LITERT -> listOf("inference", "tts", "asr")
        RuntimeId.LITERT_LM -> listOf("llm")
        RuntimeId.ONNX -> listOf("inference", "tts", "asr", "llm")
    }
}
