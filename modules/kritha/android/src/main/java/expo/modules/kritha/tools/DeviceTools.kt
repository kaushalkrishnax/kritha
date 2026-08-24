package expo.modules.kritha.tools

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.provider.Settings

object DeviceTools {
    private const val TAG = "DeviceTools"

    fun toggleFlashlight(context: Context, enable: Boolean): Boolean {
        return NativeTools(context).setTorch(enable)
    }

    fun getVolume(context: Context): Int {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
        return am?.getStreamVolume(android.media.AudioManager.STREAM_MUSIC) ?: 0
    }

    fun setVolume(context: Context, level: Int): Boolean {
        return NativeTools(context).setVolumeLevel(level)
    }

    fun getBatteryStatus(context: Context): Map<String, Any> {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = context.registerReceiver(null, filter)
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 0
        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        return mapOf("level" to batteryPct, "isCharging" to isCharging)
    }

    fun setWifi(context: Context, enable: Boolean): Boolean {
        return NativeTools(context).openSettings("wifi")
    }

    fun setBluetooth(context: Context, enable: Boolean): Boolean {
        return NativeTools(context).openSettings("bluetooth")
    }

    fun setAlarm(context: Context, hour: Int, minute: Int, message: String): Boolean {
        return NativeTools(context).setAlarm(hour, minute, message)
    }

    fun setTimer(context: Context, durationSeconds: Int, message: String): Boolean {
        return NativeTools(context).setTimer(durationSeconds, message)
    }

    fun openApp(context: Context, appName: String): Boolean {
        return NativeTools(context).launchApp(appName)
    }

    fun callContact(context: Context, contactName: String): Map<String, Any> {
        val success = NativeTools(context).openDialer(contactName)
        return mapOf("success" to success, "resolvedName" to contactName)
    }

    fun sendSMS(context: Context, contactName: String, message: String): Map<String, Any> {
        val success = NativeTools(context).openSms(contactName, message)
        return mapOf("success" to success, "resolvedName" to contactName)
    }

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

    fun readNotifications(context: Context): List<Map<String, String>> {
        return emptyList()
    }

    fun getCalendarEvents(context: Context): List<Map<String, Any>> {
        return emptyList()
    }
}
