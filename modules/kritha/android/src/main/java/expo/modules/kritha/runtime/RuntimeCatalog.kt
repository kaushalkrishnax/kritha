package expo.modules.kritha.runtime

object RuntimeCatalog {
    fun getModuleName(id: RuntimeId): String = when (id) {
        RuntimeId.LITERT -> "feature-litert"
        RuntimeId.LITERT_LM -> "feature-litertlm"
        RuntimeId.ONNX -> "feature-onnx"
    }
}

