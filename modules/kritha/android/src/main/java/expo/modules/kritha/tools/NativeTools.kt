package expo.modules.kritha.tools

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.provider.Settings
import android.util.Log

/**
 * Android capability implementations used by the assistant's deterministic
 * commands. Only capabilities that are actually reachable today live here;
 * future tools should be added behind [AssistantToolExecutor].
 */
class NativeTools(private val context: Context) {

    private val cameraManager by lazy {
        context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
    }

    private val audioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    }

    fun setTorch(enable: Boolean): Boolean {
        return try {
            val cameraId = cameraManager?.cameraIdList?.firstOrNull { id ->
                cameraManager?.getCameraCharacteristics(id)
                    ?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            if (cameraId != null) {
                cameraManager?.setTorchMode(cameraId, enable)
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

    private fun String?.isNull_orEmpty(): Boolean = this == null || this.trim().isEmpty()

    companion object {
        private const val TAG = "NativeTools"
    }
}
