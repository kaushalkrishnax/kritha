package expo.modules.wakeword.intelligence

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.LoraConfig
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.flow.collect
import java.io.File

internal class L2FunctionGemma(private val context: Context) {
    suspend fun process(command: String): String? {
        val modelFile = File(context.filesDir, "models/model-lora16-android.litertlm")
        val loraFile = File(context.filesDir, "models/control-r4-rank16.tflite")

        if (!modelFile.exists()) {
            Log.w("L2FunctionGemma", "Model file not found at ${modelFile.absolutePath}")
            return null
        }

        return try {
            val engine = LiteRTEngineManager.getEngine(modelFile.absolutePath)
            
            val convConfig = if (loraFile.exists()) {
                ConversationConfig(
                    samplerConfig = SamplerConfig(topK = 1, topP = 1.0, temperature = 0.0),
                    loraConfig = LoraConfig(loraPath = loraFile.absolutePath)
                )
            } else {
                ConversationConfig(
                    samplerConfig = SamplerConfig(topK = 1, topP = 1.0, temperature = 0.0)
                )
            }

            var response = ""
            engine.createConversation(convConfig).use { conversation ->
                val prompt = "<start_of_turn>user\n$command<end_of_turn>\n<start_of_turn>model\n"
                conversation.sendMessageAsync(prompt).collect { chunk ->
                    response += chunk
                }
            }
            Log.d("L2FunctionGemma", "FunctionGemma Raw Response: $response")
            
            LiteRTEngineManager.scheduleCleanup()
            response
        } catch (e: Exception) {
            Log.e("L2FunctionGemma", "Error executing LiteRT FunctionGemma model", e)
            null
        }
    }
}
