package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log

internal class IntelligencePipeline(private val context: Context) {

    private val l1 = L1DeterministicMatcher()
    private val l2 = L2LocalLLM(context)

    sealed interface Result {
        data class Hit(val response: String, val layer: Layer) : Result
        data object Miss : Result
    }

    enum class Layer { L1_DETERMINISTIC, L2_LOCAL_LLM }

    suspend fun process(
        input: String,
        onChunk: suspend (String) -> Unit = {}
    ): Result {
        Log.i(TAG, "Processing: \"$input\"")

        l1.match(input)?.let { response ->
            Log.i(TAG, "[L1] Hit: \"$response\"")
            // Simulate streaming for deterministic matcher
            val words = response.split(" ")
            for ((index, word) in words.withIndex()) {
                val chunk = word + if (index < words.size - 1) " " else ""
                onChunk(chunk)
                kotlinx.coroutines.delay(30)
            }
            return Result.Hit(response, Layer.L1_DETERMINISTIC)
        }

        val targetModelId = expo.modules.kritha.ModelManager.getSelectedModel(context)
        if (expo.modules.kritha.ModelCatalog.isCloudModel(targetModelId)) {
            val llmResponse = expo.modules.kritha.intelligence.L3CloudLLM(context).infer(input, onChunk = onChunk)
            if (llmResponse != null && llmResponse.isNotBlank()) {
                Log.i(TAG, "[L3] Hit — ${llmResponse.length} chars")
                return Result.Hit(llmResponse, Layer.L2_LOCAL_LLM) // Reuse layer enum or add L3_CLOUD
            }
        } else {
            val llmResponse = l2.infer(input, onChunk = onChunk)
            if (llmResponse != null && llmResponse.isNotBlank()) {
                Log.i(TAG, "[L2] Hit — ${llmResponse.length} chars")
                return Result.Hit(llmResponse, Layer.L2_LOCAL_LLM)
            }
        }

        Log.i(TAG, "[Miss] No layer handled the input — signalling JS for cloud")
        return Result.Miss
    }

    fun close() {
        LiteRTEngineManager.close()
    }

    companion object {
        private const val TAG = "IntelligencePipeline"
    }
}
