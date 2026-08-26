package expo.modules.kritha.intelligence

import java.text.DateFormat
import java.util.Date
import java.util.Locale

internal class L1DeterministicMatcher {

    sealed class Result {
        data class Response(val text: String) : Result()

        data class Command(val name: String, val args: Map<String, Any?> = emptyMap()) : Result()
    }

    fun match(input: String): Result? {
        val q = input.lowercase(Locale.US).trim()

        return when {
            q in setOf("stop", "cancel", "never mind", "nevermind") -> Result.Response("Okay.")
            q.startsWith("hello") || q.startsWith("hi") ->
                Result.Response("Hi, I'm Kritha. How can I help?")

            "help" in q || "what can you do" in q ->
                Result.Response(
                    "I can answer questions, have a conversation, set alarms, control your device, and much more, all locally on your device."
                )

            q == "time" || "what time" in q ->
                Result.Response(
                    "It's ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date())}."
                )

            q == "date" || q == "day" || "what day" in q || "what is the date" in q ->
                Result.Response(
                    "Today is ${DateFormat.getDateInstance(DateFormat.FULL).format(Date())}."
                )

            q in
                    setOf(
                        "turn on flashlight",
                        "turn on torch",
                        "enable flashlight",
                        "enable torch"
                    ) -> Result.Command("torch", mapOf("enable" to true))

            q in
                    setOf(
                        "turn off flashlight",
                        "turn off torch",
                        "disable flashlight",
                        "disable torch"
                    ) -> Result.Command("torch", mapOf("enable" to false))

            q == "mute" || q == "mute volume" -> Result.Command("mute", mapOf("mute" to true))
            q == "unmute" || q == "unmute volume" -> Result.Command("mute", mapOf("mute" to false))
            q == "open wifi settings" || q == "open wifi" ->
                Result.Command("settings", mapOf("type" to "wifi"))

            q == "open bluetooth settings" || q == "open bluetooth" ->
                Result.Command("settings", mapOf("type" to "bluetooth"))

            q == "open display settings" || q == "open brightness settings" ->
                Result.Command("settings", mapOf("type" to "display"))

            q == "open sound settings" || q == "open volume settings" ->
                Result.Command("settings", mapOf("type" to "sound"))

            q == "open battery settings" -> Result.Command("settings", mapOf("type" to "battery"))
            q == "open location settings" -> Result.Command("settings", mapOf("type" to "location"))
            q == "open dialer" || q == "open phone" -> Result.Command("dialer")
            else -> null
        }
    }
}
