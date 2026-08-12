package expo.modules.wakeword.intelligence

import android.content.Context
import expo.modules.wakeword.commands.*
import java.util.Locale

internal class L1DeterministicMatcher(private val context: Context) {
    fun match(command: String): String? {
        val lower = command.lowercase(Locale.US).trim()
        return when {
            lower in setOf("stop", "cancel", "never mind", "nevermind") -> {
                "Okay."
            }
            lower.startsWith("hello") || lower.startsWith("hi") -> {
                "Hi, I am listening."
            }
            "help" in lower || "what can you do" in lower -> {
                "I can control your alarm, timer, music, volume, wifi, bluetooth, flashlight, and read notifications or calendar events."
            }
            lower == "time" || lower == "what time is it" || lower == "what is the time" -> {
                "The current time is ${java.text.DateFormat.getTimeInstance(java.text.DateFormat.SHORT).format(java.util.Date())}."
            }
            lower == "date" || lower == "day" || lower == "what day is today" || lower == "what is the date" -> {
                "Today is ${java.text.DateFormat.getDateInstance(java.text.DateFormat.FULL).format(java.util.Date())}."
            }
            DeviceCommandHandler.canHandle(lower) -> {
                DeviceCommandHandler.handle(lower, context)
            }
            MediaCommandHandler.canHandle(lower) -> {
                MediaCommandHandler.handle(lower, context)
            }
            OrganizerCommandHandler.canHandle(lower) -> {
                OrganizerCommandHandler.handle(lower, context)
            }
            CommunicationCommandHandler.canHandle(lower, command) -> {
                CommunicationCommandHandler.handle(command, lower, context)
            }
            InfoCommandHandler.canHandle(lower) -> {
                InfoCommandHandler.handle(lower, context)
            }
            AppLauncherCommandHandler.canHandle(lower) -> {
                AppLauncherCommandHandler.handle(command, lower, context)
            }
            else -> null // L1 Miss!
        }
    }
}
