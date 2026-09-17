package expo.modules.kritha.runtime.llm

interface LlmProvider {
    suspend fun generate(

        request: Map<String, Any?>, 
        onDelta: (String) -> Unit = {},
        onChannel: (String, String) -> Unit = { _, _ -> },
    ): String

    fun closeModel(modelPath: String, device: String)
    fun close()
}
