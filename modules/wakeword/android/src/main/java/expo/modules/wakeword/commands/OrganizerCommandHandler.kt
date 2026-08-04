package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
import java.util.Locale
import java.util.regex.Pattern

internal object OrganizerCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "alarm" in lower || "wake me up" in lower || "timer" in lower || "countdown" in lower
    }

    fun handle(lower: String, context: Context): String {
        return if ("alarm" in lower || "wake me up" in lower) {
            handleAlarm(lower, context)
        } else {
            handleTimer(lower, context)
        }
    }

    private fun handleAlarm(lower: String, context: Context): String {
        var hour = 7
        var minute = 0
        val matcher = Pattern.compile("(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?").matcher(lower)
        if (matcher.find()) {
            hour = matcher.group(1)?.toIntOrNull() ?: 7
            minute = matcher.group(2)?.toIntOrNull() ?: 0
            val ampm = matcher.group(3)
            if (ampm == "pm" && hour < 12) {
                hour += 12
            } else if (ampm == "am" && hour == 12) {
                hour = 0
            }
        }
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, "Kritha Alarm")
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            "Alarm set for ${String.format(Locale.US, "%02d:%02d", hour, minute)}."
        } catch (e: Exception) {
            "Failed to set alarm."
        }
    }

    private fun handleTimer(lower: String, context: Context): String {
        var durationSeconds = 60
        val matcher = Pattern.compile("(\\d+)\\s*(hour|minute|second|hr|min|sec|s|m|h)s?").matcher(lower)
        if (matcher.find()) {
            val value = matcher.group(1)?.toIntOrNull() ?: 60
            val unit = matcher.group(2) ?: "minute"
            durationSeconds = when {
                unit.startsWith("hour") || unit.startsWith("hr") || unit == "h" -> value * 3600
                unit.startsWith("minute") || unit.startsWith("min") || unit == "m" -> value * 60
                else -> value
            }
        }
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_LENGTH, durationSeconds)
                putExtra(AlarmClock.EXTRA_MESSAGE, "Kritha Timer")
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            val mins = durationSeconds / 60
            val secs = durationSeconds % 60
            val timeStr = buildString {
                if (mins > 0) append("$mins minute${if (mins > 1) "s" else ""}")
                if (secs > 0) {
                    if (isNotEmpty()) append(" and ")
                    append("$secs second${if (secs > 1) "s" else ""}")
                }
            }
            "Timer set for ${if (timeStr.isEmpty()) "0 seconds" else timeStr}."
        } catch (e: Exception) {
            "Failed to set timer."
        }
    }
}
