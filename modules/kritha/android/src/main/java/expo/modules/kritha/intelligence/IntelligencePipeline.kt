package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log

/**
 * Hierarchical intelligence pipeline for background assistant sessions
 * (triggered by wake word when app is in foreground but user didn't tap the chat).
 *
 * Layers:
 *  L1 — Deterministic matcher: instant, no model needed (time, date, simple commands).
 *  L2 — Local LLM: on-device inference if a model is downloaded.
 *  Miss — Signal to the JS layer that cloud fallback is needed.
 *
 * Note: L3 (cloud) is intentionally NOT handled here. Cloud routing belongs in
 * the JS layer (CloudService) so the JS thread manages its own network calls and
 * API keys without exposing them to the native process.
 */
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

        // L1 — fast deterministic match
        l1.match(input)?.let { response ->
            Log.i(TAG, "[L1] Hit: \"$response\"")
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
            // L2 — on-device LLM
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
