package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import expo.modules.kritha.ModelManager
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive

internal class L2LocalLLM(private val context: Context) {

    suspend fun infer(
        messages: List<ConversationMessage>,
        modelId: String? = null,
        onChunk: suspend (String) -> Unit = {}
    ): String? {
        val targetModelId = modelId ?: ModelManager.getSelectedModel(context)
        val modelFile = ModelManager.getModelFilePath(context, targetModelId)

        if (modelFile == null) {
            Log.w(TAG, "Model '$targetModelId' is not downloaded")
            return null
        }

        val device = LiteRTEngineManager.getDevice(context)
        isCancelled = false

        val responseBuilder = StringBuilder()

        return try {
            val engine = LiteRTEngineManager.getEngine(modelFile.absolutePath, device)

            val config = ConversationConfig(
                samplerConfig = SamplerConfig(
                    temperature = 0.3,
                    topK = 40,
                    topP = 0.95
                )
            )

            engine.createConversation(config).use { conversation ->
                
                val finalPrompt = buildString {
                    messages.forEach { msg ->
                        when (msg.role) {
                            Role.SYSTEM -> append("System: ${msg.content}\n\n")
                            Role.USER -> append("User: ${msg.content}\n\n")
                            Role.ASSISTANT -> append("Kritha: ${msg.content}\n\n")
                        }
                    }
                }.trimEnd()
                
                conversation.sendMessageAsync(finalPrompt).collect { token ->
                    if (isCancelled || !currentCoroutineContext().isActive) {
                        Log.i(TAG, "Inference cancelled mid-stream")
                        throw CancellationException("Generation cancelled")
                    }
                    val text = token.toString()
                    responseBuilder.append(text)
                    onChunk(text)
                }
            }

            val response = responseBuilder.toString()
            Log.d(TAG, "Inference complete on ${device.name} — ${response.length} chars")
            LiteRTEngineManager.startIdleTimer()
            response

        } catch (e: CancellationException) {
            Log.i(TAG, "Inference cancelled by user for '$targetModelId'")
            LiteRTEngineManager.startIdleTimer()
            responseBuilder.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Inference failed for '$targetModelId' on ${device.name}", e)
            LiteRTEngineManager.startIdleTimer()
            null
        }
    }

    companion object {
        private const val TAG = "L2LocalLLM"

        @Volatile
        var isCancelled: Boolean = false

        fun cancelInference() {
            isCancelled = true
        }
    }
}

