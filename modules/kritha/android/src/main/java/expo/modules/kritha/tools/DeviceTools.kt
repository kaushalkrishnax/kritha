package expo.modules.kritha.tools

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Notification-listener access checks used by the bridge surface. The only
 * device queries that are actually exercised today live here.
 */
object DeviceTools {

    fun isNotificationListenerEnabled(context: Context): Boolean {
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return flat?.contains(context.packageName) == true
    }

    fun requestNotificationListenerPermission(context: Context) {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            if (context !is Activity) {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        context.startActivity(intent)
    }
}
