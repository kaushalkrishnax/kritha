package expo.modules.kritha.tools

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.provider.Settings
import android.view.KeyEvent
import android.util.Log

class NativeTools(private val context: Context) {

    private val cameraManager by lazy {
        context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
    }

    private val audioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    }

    // Torch / Flashlight

    private var isTorchOn = false

    fun setTorch(enable: Boolean): Boolean {
        return try {
            val cameraId = cameraManager?.cameraIdList?.firstOrNull { id ->
                cameraManager?.getCameraCharacteristics(id)
                    ?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            if (cameraId != null) {
                cameraManager?.setTorchMode(cameraId, enable)
                isTorchOn = enable
                Log.i(TAG, "Torch mode set to: $enable")
                true
            } else {
                Log.w(TAG, "No camera with flash unit found")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set torch mode", e)
            false
        }
    }

    fun toggleTorch(): Boolean = setTorch(!isTorchOn)

    // Audio & Volume Control

    fun setVolumeLevel(percent: Int, streamType: Int = AudioManager.STREAM_MUSIC): Boolean {
        return try {
            val am = audioManager ?: return false
            val maxVolume = am.getStreamMaxVolume(streamType)
            val targetVolume = ((percent.coerceIn(0, 100) / 100.0) * maxVolume).toInt()
            am.setStreamVolume(streamType, targetVolume, AudioManager.FLAG_SHOW_UI)
            Log.i(TAG, "Volume set to $percent% (level $targetVolume/$maxVolume)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set volume level", e)
            false
        }
    }

    fun setMute(mute: Boolean, streamType: Int = AudioManager.STREAM_MUSIC): Boolean {
        return try {
            val am = audioManager ?: return false
            if (mute) {
                am.adjustStreamVolume(streamType, AudioManager.ADJUST_MUTE, AudioManager.FLAG_SHOW_UI)
            } else {
                am.adjustStreamVolume(streamType, AudioManager.ADJUST_UNMUTE, AudioManager.FLAG_SHOW_UI)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set mute status", e)
            false
        }
    }

    fun dispatchMediaKey(keyCode: Int): Boolean {
        return try {
            val am = audioManager ?: return false
            val eventTime = SystemClock.uptimeMillis()
            val downEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0)
            val upEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0)
            am.dispatchMediaKeyEvent(downEvent)
            am.dispatchMediaKeyEvent(upEvent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dispatch media key: $keyCode", e)
            false
        }
    }

    // Alarm & Timer

    fun setAlarm(hour: Int, minute: Int, message: String = "Alarm"): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.i(TAG, "Opened alarm creation for $hour:$minute - $message")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set alarm", e)
            false
        }
    }

    fun setTimer(lengthSeconds: Int, message: String = "Timer"): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_LENGTH, lengthSeconds)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.i(TAG, "Opened timer creation for $lengthSeconds seconds - $message")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set timer", e)
            false
        }
    }

    // Calendar

    fun createCalendarEvent(
        title: String,
        description: String? = null,
        location: String? = null,
        beginTimeMs: Long? = null,
        endTimeMs: Long? = null
    ): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                description?.let { putExtra(CalendarContract.Events.DESCRIPTION, it) }
                location?.let { putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
                beginTimeMs?.let { putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, it) }
                endTimeMs?.let { putExtra(CalendarContract.EXTRA_EVENT_END_TIME, it) }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.i(TAG, "Opened calendar event creation for title: $title")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open calendar event creation", e)
            false
        }
    }

    // Phone & SMS

    fun openDialer(phoneNumber: String? = null): Boolean {
        return try {
            val uri = if (phoneNumber.isNull_orEmpty()) Uri.parse("tel:") else Uri.parse("tel:$phoneNumber")
            val intent = Intent(Intent.ACTION_DIAL, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open dialer", e)
            false
        }
    }

    fun openSms(phoneNumber: String? = null, message: String? = null): Boolean {
        return try {
            val uri = if (phoneNumber.isNull_orEmpty()) Uri.parse("smsto:") else Uri.parse("smsto:$phoneNumber")
            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                message?.let { putExtra("sms_body", it) }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open SMS app", e)
            false
        }
    }

    // System Settings

    fun openSettings(settingType: String): Boolean {
        return try {
            val action = when (settingType.lowercase()) {
                "wifi" -> Settings.ACTION_WIFI_SETTINGS
                "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                "display", "brightness" -> Settings.ACTION_DISPLAY_SETTINGS
                "sound", "volume" -> Settings.ACTION_SOUND_SETTINGS
                "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
                "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                else -> Settings.ACTION_SETTINGS
            }
            val intent = Intent(action).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open settings: $settingType", e)
            false
        }
    }

    // App Launcher

    fun launchApp(packageName: String): Boolean {
        return try {
            val pm = context.packageManager
            val intent = pm.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent != null) {
                context.startActivity(intent)
                true
            } else {
                Log.w(TAG, "App package not found: $packageName")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app: $packageName", e)
            false
        }
    }

    private fun String?.isNull_orEmpty(): Boolean = this == null || this.trim().isEmpty()

    companion object {
        private const val TAG = "NativeTools"
    }
}
