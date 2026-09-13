package expo.modules.kritha.tools

import android.content.Context
import android.util.Log

/**
 * Executes deterministic device commands requested by the intelligence layer
 * (L1 matches). Returns the user-facing response text, or null when the
 * command is unknown or failed — the pipeline treats null as a Miss.
 *
 * Future device capabilities plug in here without touching intelligence.
 */
internal class AssistantToolExecutor(private val context: Context) {

    // REMOVED: L1DeterministicMatcher import - module not found
    // Using a simple data class as placeholder for the command
    data class Command(val name: String, val args: Map<String, Any?>)

    fun execute(command: Command): String? {
        val tools = NativeTools(context)

        return when (command.name) {
            "torch" -> {
                val enable = command.args["enable"] as? Boolean
                    ?: return null
                if (tools.setTorch(enable)) {
                    if (enable) "Flashlight turned on." else "Flashlight turned off."
                } else {
                    "I couldn't control the flashlight."
                }
            }

            "mute" -> {
                val mute = command.args["mute"] as? Boolean
                    ?: return null
                if (tools.setMute(mute)) {
                    if (mute) "Volume muted." else "Volume unmuted."
                } else {
                    "I couldn't change the volume."
                }
            }

            "settings" -> {
                val type = command.args["type"] as? String
                    ?: return null
                if (tools.openSettings(type)) {
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
                if (tools.openDialer()) {
                    "Opening the dialer."
                } else {
                    "I couldn't open the dialer."
                }
            }

            else -> {
                Log.w(TAG, "Unknown L1 command: ${command.name}")
                null
            }
        }
    }

    companion object {
        private const val TAG = "AssistantToolExecutor"
    }
}
