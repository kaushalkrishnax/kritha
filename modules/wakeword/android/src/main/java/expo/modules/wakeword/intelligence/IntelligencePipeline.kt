package expo.modules.wakeword.intelligence

import android.content.Context
import android.util.Log

internal class IntelligencePipeline(context: Context) {
    private val l1 = L1DeterministicMatcher(context)
    private val l2 = L2FunctionGemma(context)
    private val l3 = L3LocalModel(context)

    suspend fun process(command: String): PipelineResult {
        Log.i(TAG, "Processing command: \"$command\"")

        return evaluateL1(command)
            ?: evaluateL2(command)
            ?: evaluateL3(command)
            ?: escalateToCloud()
    }

    private fun evaluateL1(command: String): PipelineResult.Hit? {
        return l1.match(command)?.let { result ->
            Log.i(TAG, "[L1] Deterministic match found: \"$result\"")
            PipelineResult.Hit(result, IntelligenceLayer.L1_DETERMINISTIC)
        }.also {
            if (it == null) Log.d(TAG, "[L1] No deterministic match. Escalating...")
        }
    }

    private suspend fun evaluateL2(command: String): PipelineResult.Hit? {
        val result = l2.process(command)
        
        // TODO: In the future, check if result explicitly indicates "NO_MATCH" or similar
        // before treating it as a hit. For now, any non-null execution is a hit.
        return result?.let {
            Log.i(TAG, "[L2] FunctionGemma handled intent: \"$it\"")
            PipelineResult.Hit(it, IntelligenceLayer.L2_FUNCTION_GEMMA)
        }.also {
            if (it == null) Log.d(TAG, "[L2] FunctionGemma bypassed/unavailable. Escalating...")
        }
    }

    private suspend fun evaluateL3(command: String): PipelineResult.Hit? {
        val result = l3.process(command)

        return result?.let {
            Log.i(TAG, "[L3] Local Qwen model generated response.")
            PipelineResult.Hit(it, IntelligenceLayer.L3_QWEN_LOCAL)
        }.also {
            if (it == null) Log.d(TAG, "[L3] Local Qwen bypassed/unavailable. Escalating...")
        }
    }

    private fun escalateToCloud(): PipelineResult.Miss {
        Log.w(TAG, "[Cloud] All local intelligence layers exhausted. Escalating to remote server.")
        return PipelineResult.Miss("Escalated to Cloud LLM")
    }

    fun close() {
        Log.d(TAG, "Shutting down pipeline and releasing resources.")
        LiteRTEngineManager.close()
    }

    companion object {
        private const val TAG = "IntelligencePipeline"
    }
}
