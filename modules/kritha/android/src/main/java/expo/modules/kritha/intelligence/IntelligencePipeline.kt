package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log
import expo.modules.kritha.tools.NativeTools

internal class IntelligencePipeline(private val context: Context) {

    private val l1 = L1DeterministicMatcher()
    private val l2 = L2LocalLLM(context)
    private val nativeTools = NativeTools(context)

    sealed interface Result {
        data class Hit(val response: String, val layer: Layer) : Result
        data object Miss : Result
    }

    enum class Layer {
        L1_DETERMINISTIC,
        L2_LOCAL_LLM,
        L3_CLOUD_LLM
    }

    suspend fun process(
        input: String,
        onChunk: suspend (String) -> Unit = {}
    ): Result {

        Log.i(TAG, "Processing: \"$input\"")

        l1.match(input)?.let { l1Result ->

            when (l1Result) {

                is L1DeterministicMatcher.Result.Response -> {
                    val response = l1Result.text

                    Log.i(TAG, "[L1] Response: \"$response\"")

                    streamResponse(response, onChunk)

                    return Result.Hit(
                        response,
                        Layer.L1_DETERMINISTIC
                    )
                }

                is L1DeterministicMatcher.Result.Command -> {
                    Log.i(
                        TAG,
                        "[L1] Command: ${l1Result.name} args=${l1Result.args}"
                    )

                    val response = executeCommand(l1Result)

                    if (response != null) {
                        streamResponse(response, onChunk)

                        return Result.Hit(
                            response,
                            Layer.L1_DETERMINISTIC
                        )
                    }

                    Log.w(
                        TAG,
                        "[L1] Command failed: ${l1Result.name}"
                    )

                    return Result.Miss
                }
            }
        }

        val targetModelId =
            expo.modules.kritha.ModelManager.getSelectedModel(context)

        if (expo.modules.kritha.ModelCatalog.isCloudModel(targetModelId)) {

            val llmResponse =
                expo.modules.kritha.intelligence.L3CloudLLM(context)
                    .infer(input, onChunk = onChunk)

            if (!llmResponse.isNullOrBlank()) {
                Log.i(
                    TAG,
                    "[L3] Hit — ${llmResponse.length} chars"
                )

                return Result.Hit(
                    llmResponse,
                    Layer.L3_CLOUD_LLM
                )
            }

        } else {

            val llmResponse =
                l2.infer(input, onChunk = onChunk)

            if (!llmResponse.isNullOrBlank()) {
                Log.i(
                    TAG,
                    "[L2] Hit — ${llmResponse.length} chars"
                )

                return Result.Hit(
                    llmResponse,
                    Layer.L2_LOCAL_LLM
                )
            }
        }

        Log.i(
            TAG,
            "[Miss] No layer handled the input — signalling JS for cloud"
        )

        return Result.Miss
    }

    private suspend fun streamResponse(
        response: String,
        onChunk: suspend (String) -> Unit
    ) {
        val words = response.split(" ")

        for ((index, word) in words.withIndex()) {
            val chunk =
                word + if (index < words.size - 1) " " else ""

            onChunk(chunk)
            kotlinx.coroutines.delay(30)
        }
    }

    private fun executeCommand(
        command: L1DeterministicMatcher.Result.Command
    ): String? {

        return when (command.name) {

            "torch" -> {
                val enable =
                    command.args["enable"] as? Boolean
                        ?: return null

                if (nativeTools.setTorch(enable)) {
                    if (enable) {
                        "Flashlight turned on."
                    } else {
                        "Flashlight turned off."
                    }
                } else {
                    "I couldn't control the flashlight."
                }
            }

            "mute" -> {
                val mute =
                    command.args["mute"] as? Boolean
                        ?: return null

                if (nativeTools.setMute(mute)) {
                    if (mute) {
                        "Volume muted."
                    } else {
                        "Volume unmuted."
                    }
                } else {
                    "I couldn't change the volume."
                }
            }

            "settings" -> {
                val type =
                    command.args["type"] as? String
                        ?: return null

                if (nativeTools.openSettings(type)) {
                    when (type) {
                        "wifi" -> "Opening Wi-Fi settings."
                        "bluetooth" -> "Opening Bluetooth settings."
                        "display" -> "Opening display settings."
                        "sound" -> "Opening sound settings."
                        "battery" -> "Opening battery settings."
                        "location" -> "Opening location settings."
                        else -> "Opening settings."
                    }
                } else {
                    "I couldn't open those settings."
                }
            }

            "dialer" -> {
                if (nativeTools.openDialer()) {
                    "Opening the dialer."
                } else {
                    "I couldn't open the dialer."
                }
            }

            else -> {
                Log.w(
                    TAG,
                    "Unknown L1 command: ${command.name}"
                )
                null
            }
        }
    }

    fun close() {
        LiteRTEngineManager.close()
    }

    companion object {
        private const val TAG = "IntelligencePipeline"
    }
}
