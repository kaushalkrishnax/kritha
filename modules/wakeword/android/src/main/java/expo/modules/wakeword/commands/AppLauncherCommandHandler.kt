package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Locale

internal object AppLauncherCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "open" in lower || "launch" in lower
    }

    fun handle(command: String, lower: String, context: Context): String {
        val appName = command.replace(Regex("^(open|launch)\\s+", RegexOption.IGNORE_CASE), "").trim()
        return if (appName.isNotEmpty()) {
            var launched = false
            try {
                val pm = context.packageManager
                val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                }
                val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
                val searchName = appName.lowercase(Locale.US).trim()
                for (info in resolveInfos) {
                    val name = info.loadLabel(pm).toString().lowercase(Locale.US).trim()
                    if (name == searchName || name.contains(searchName) || searchName.contains(name)) {
                        val launchIntent = pm.getLaunchIntentForPackage(info.activityInfo.packageName)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(launchIntent)
                            launched = true
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("AppLauncherCommand", "Error opening app", e)
            }
            if (launched) {
                "Opening $appName."
            } else {
                "Sorry, I couldn't find an app named $appName."
            }
        } else {
            "Which app would you like to open?"
        }
    }
}
