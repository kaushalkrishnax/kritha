package expo.modules.kritha.intelligence

import java.text.DateFormat
import java.util.Date
import java.util.Locale

internal class L1DeterministicMatcher {

    fun match(input: String): String? {
        val q = input.lowercase(Locale.US).trim()
        return when {
            q in setOf("stop", "cancel", "never mind", "nevermind") ->
                "Okay."
            q.startsWith("hello") || q.startsWith("hi") ->
                "Hi, I'm Kritha. How can I help?"
            "help" in q || "what can you do" in q ->
                "I can answer questions, have a conversation, set alarms, control your device, and much more — all locally on your device."
            q == "time" || "what time" in q ->
                "It's ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date())}."
            q == "date" || q == "day" || "what day" in q || "what is the date" in q ->
                "Today is ${DateFormat.getDateInstance(DateFormat.FULL).format(Date())}."
            else -> null
        }
    }
}
