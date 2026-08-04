package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import android.provider.Settings
import android.util.Log
import expo.modules.wakeword.KrithaNotificationListener

internal object InfoCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "notification" in lower || "notify" in lower ||
               "calendar" in lower || "schedule" in lower || "event" in lower || "meeting" in lower ||
               "weather" in lower || "temperature" in lower || "forecast" in lower
    }

    fun handle(lower: String, context: Context): String {
        return when {
            "notification" in lower || "notify" in lower -> handleNotifications(context)
            "calendar" in lower || "schedule" in lower || "event" in lower || "meeting" in lower -> handleCalendar(context)
            else -> handleWeather()
        }
    }

    private fun handleNotifications(context: Context): String {
        val enabledListeners = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        val isEnabled = enabledListeners != null && enabledListeners.contains(context.packageName)
        return if (!isEnabled) {
            try {
                val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                "Please enable notification access permission for Kritha in settings."
            } catch (e: Exception) {
                "Notification access permission is required."
            }
        } else {
            val instance = KrithaNotificationListener.instance
            if (instance != null) {
                try {
                    val active = instance.activeNotifications
                    if (active.isEmpty()) {
                        "You have no active notifications."
                    } else {
                        val count = Math.min(3, active.size)
                        val builder = StringBuilder("You have ${active.size} notifications. ")
                        builder.append("Here are the first $count. ")
                        for (i in 0 until count) {
                            val sbn = active[i]
                            val extras = sbn.notification.extras
                            val title = extras.getString("android.title") ?: ""
                            val text = extras.getCharSequence("android.text")?.toString() ?: ""
                            builder.append("$title says $text. ")
                        }
                        builder.toString()
                    }
                } catch (e: Exception) {
                    Log.e("InfoCommandHandler", "Error reading notifications", e)
                    "Failed to read notifications."
                }
            } else {
                "Notification service is not active."
            }
        }
    }

    private fun handleCalendar(context: Context): String {
        return try {
            val uri = CalendarContract.Events.CONTENT_URI
            val projection = arrayOf(
                CalendarContract.Events.TITLE,
                CalendarContract.Events.DTSTART
            )
            val selection = "${CalendarContract.Events.DTSTART} >= ?"
            val selectionArgs = arrayOf(System.currentTimeMillis().toString())
            val sortOrder = "${CalendarContract.Events.DTSTART} ASC"

            val cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            val events = mutableListOf<String>()
            cursor?.use {
                val titleIdx = it.getColumnIndex(CalendarContract.Events.TITLE)
                val startIdx = it.getColumnIndex(CalendarContract.Events.DTSTART)
                var count = 0
                while (it.moveToNext() && count < 5) {
                    val title = it.getString(titleIdx) ?: ""
                    val start = it.getLong(startIdx)
                    val date = java.util.Date(start)
                    val timeStr = java.text.DateFormat.getTimeInstance(java.text.DateFormat.SHORT).format(date)
                    events.add("$title at $timeStr")
                    count++
                }
            }
            if (events.isEmpty()) {
                "Your calendar is clear."
            } else {
                "You have ${events.size} upcoming events: ${events.joinToString(". ")}"
            }
        } catch (e: Exception) {
            Log.e("InfoCommandHandler", "Error reading calendar events", e)
            "Failed to read calendar events."
        }
    }

    private fun handleWeather(): String {
        return "The weather is currently twenty four degrees and clear."
    }
}
