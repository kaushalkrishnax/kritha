package expo.modules.wakeword.intelligence

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.flow.collect
import java.io.File

internal class L3LocalModel(private val context: Context) {
    suspend fun process(command: String): String? {
        val modelFile = File(context.filesDir, "models/qwen35_mm_q8_ekv2048.litertlm")

        if (!modelFile.exists()) {
            Log.w("L3LocalModel", "Model file not found at ${modelFile.absolutePath}")
            return null
        }

        return try {
            val engine = LiteRTEngineManager.getEngine(modelFile.absolutePath)
            
            var response = ""
            val convConfig = ConversationConfig(
                samplerConfig = SamplerConfig(temperature = 0.7)
            )

            engine.createConversation(convConfig).use { conversation ->
                conversation.sendMessageAsync(command).collect { chunk ->
                    response += chunk
                }
            }
            Log.d("L3LocalModel", "Qwen Raw Response: $response")
            
            LiteRTEngineManager.scheduleCleanup()
            response
        } catch (e: Exception) {
            Log.e("L3LocalModel", "Error executing LiteRT Qwen model", e)
            null
        }
    }
}
