package expo.modules.wakeword.commands

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.provider.Settings
import android.util.Log
import expo.modules.wakeword.KrithaNotificationListener
import java.util.Locale
import java.util.regex.Pattern

internal object DeviceCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "flashlight" in lower || "torch" in lower ||
               "wifi" in lower || "wi-fi" in lower ||
               "bluetooth" in lower ||
               "volume" in lower || "mute" in lower || "unmute" in lower ||
               "battery" in lower || "charge level" in lower || "power level" in lower
    }

    fun handle(lower: String, context: Context): String {
        return when {
            "flashlight" in lower || "torch" in lower -> handleFlashlight(lower, context)
            "wifi" in lower || "wi-fi" in lower -> handleWifi(lower, context)
            "bluetooth" in lower -> handleBluetooth(lower, context)
            "volume" in lower || "mute" in lower || "unmute" in lower -> handleVolume(lower, context)
            else -> handleBattery(context)
        }
    }

    private fun handleFlashlight(lower: String, context: Context): String {
        val enable = !lower.contains("off") && !lower.contains("disable") && !lower.contains("turn off")
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList.firstOrNull()
            if (cameraId != null) {
                cameraManager.setTorchMode(cameraId, enable)
                "Flashlight turned ${if (enable) "on" else "off"}."
            } else {
                "Sorry, flashlight is not available."
            }
        } catch (e: Exception) {
            Log.e("DeviceCommandHandler", "Error toggling flashlight", e)
            "Failed to toggle flashlight."
        }
    }

    private fun handleWifi(lower: String, context: Context): String {
        val enable = !lower.contains("off") && !lower.contains("disable") && !lower.contains("turn off")
        return try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiManager.isWifiEnabled = enable
            "Wi-Fi turned ${if (enable) "on" else "off"}."
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                "Opening Wi-Fi settings."
            } catch (e2: Exception) {
                "Failed to change Wi-Fi status."
            }
        }
    }

    private fun handleBluetooth(lower: String, context: Context): String {
        val enable = !lower.contains("off") && !lower.contains("disable") && !lower.contains("turn off")
        return try {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            if (bluetoothAdapter != null) {
                if (enable) {
                    @Suppress("DEPRECATION")
                    bluetoothAdapter.enable()
                } else {
                    @Suppress("DEPRECATION")
                    bluetoothAdapter.disable()
                }
                "Bluetooth turned ${if (enable) "on" else "off"}."
            } else {
                "Bluetooth is not available."
            }
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                "Opening Bluetooth settings."
            } catch (e2: Exception) {
                "Failed to change Bluetooth status."
            }
        }
    }

    private fun handleVolume(lower: String, context: Context): String {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

        return when {
            "mute" in lower && "unmute" !in lower -> {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, AudioManager.FLAG_SHOW_UI)
                "Volume muted."
            }
            "unmute" in lower -> {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume / 2, AudioManager.FLAG_SHOW_UI)
                "Volume unmuted."
            }
            "up" in lower || "raise" in lower || "increase" in lower -> {
                val next = (currentVolume + (maxVolume * 0.15).toInt()).coerceIn(0, maxVolume)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, next, AudioManager.FLAG_SHOW_UI)
                "Volume increased."
            }
            "down" in lower || "lower" in lower || "decrease" in lower -> {
                val next = (currentVolume - (maxVolume * 0.15).toInt()).coerceIn(0, maxVolume)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, next, AudioManager.FLAG_SHOW_UI)
                "Volume decreased."
            }
            else -> {
                val pctMatcher = Pattern.compile("(\\d+)\\s*%").matcher(lower)
                if (pctMatcher.find()) {
                    val pct = pctMatcher.group(1)?.toIntOrNull() ?: 50
                    val next = (maxVolume * (pct / 100f)).toInt().coerceIn(0, maxVolume)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, next, AudioManager.FLAG_SHOW_UI)
                    "Volume set to $pct percent."
                } else {
                    val numMatcher = Pattern.compile("(?:to|at)\\s*(\\d+)").matcher(lower)
                    if (numMatcher.find()) {
                        val num = numMatcher.group(1)?.toIntOrNull() ?: 5
                        val next = if (num > 10) (maxVolume * (num / 100f)).toInt() else num
                        val target = next.coerceIn(0, maxVolume)
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, AudioManager.FLAG_SHOW_UI)
                        "Volume set."
                    } else {
                        "Volume is currently at ${((currentVolume.toFloat() / maxVolume) * 100).toInt()} percent."
                    }
                }
            }
        }
    }

    private fun handleBattery(context: Context): String {
        val batteryStatus = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level / scale.toFloat() * 100).toInt() else -1
        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        return if (batteryPct >= 0) {
            "Your battery is at $batteryPct percent ${if (isCharging) "and is currently charging" else "and is not charging"}."
        } else {
            "Unable to read battery status."
        }
    }
}
