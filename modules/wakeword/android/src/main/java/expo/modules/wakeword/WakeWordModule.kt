package expo.modules.wakeword

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.hardware.camera2.CameraManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.provider.AlarmClock
import android.provider.Settings
import android.provider.ContactsContract
import android.provider.CalendarContract
import android.net.Uri
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.util.Log
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.util.Locale

class WakeWordModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("WakeWord")

        Events("onWakeWordDetected", "onAssistantEvent")

        OnStartObserving {
            WakeWordEventHub.listener = { keyword, confidence ->
                Handler(Looper.getMainLooper()).post {
                    sendEvent(
                        "onWakeWordDetected",
                        mapOf("keyword" to keyword, "confidence" to confidence)
                    )
                }
            }
            WakeWordEventHub.assistantListener = { state, transcript, response, error ->
                Handler(Looper.getMainLooper()).post {
                    sendEvent(
                        "onAssistantEvent",
                        mapOf(
                            "state" to state,
                            "transcript" to transcript,
                            "response" to response,
                            "error" to error
                        )
                    )
                }
            }
        }

        OnStopObserving {
            WakeWordEventHub.listener = null
            WakeWordEventHub.assistantListener = null
        }

        Function("start") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.start(context)
        }

        Function("stop") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.stop(context)
        }

        Function("isRunning") {
            WakeWordForegroundService.isRunning
        }

        Function("stopAssistantSession") {
            WakeWordForegroundService.stopAssistantSession()
        }

        Function("triggerAssistantSession") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.triggerAssistantSession(context)
        }

        Function("respondToAssistant") { response: String ->
            val session = WakeWordListeningActivity.activeSession ?: WakeWordForegroundService.activeSession
            session?.speakAndFinish(response)
        }

        Function("toggleFlashlight") { enable: Boolean ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            try {
                val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val cameraId = cameraManager.cameraIdList.firstOrNull()
                if (cameraId != null) {
                    cameraManager.setTorchMode(cameraId, enable)
                }
            } catch (e: Exception) {
                Log.e("WakeWordModule", "Error toggling flashlight", e)
            }
        }

        Function("getVolume") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 0.0
        }

        Function("setVolume") { level: Double ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetVolume = (level * maxVolume).toInt().coerceIn(0, maxVolume)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, AudioManager.FLAG_SHOW_UI)
        }

        Function("getBatteryStatus") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val batteryStatus = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) (level / scale.toFloat() * 100).toInt() else -1
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
            mapOf("level" to batteryPct, "isCharging" to isCharging)
        }

        Function("setWifi") { enable: Boolean ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            try {
                val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiManager.isWifiEnabled = enable
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
        }

        Function("setBluetooth") { enable: Boolean ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            try {
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
                }
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
        }

        Function("setAlarm") { hour: Int, minute: Int, message: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        Function("setTimer") { durationSeconds: Int, message: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_LENGTH, durationSeconds)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        Function("openApp") { appName: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val pm = context.packageManager
            val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            var launched = false
            val searchName = appName.lowercase(Locale.US).trim()
            for (app in apps) {
                val name = pm.getApplicationLabel(app).toString().lowercase(Locale.US).trim()
                if (name == searchName || name.contains(searchName) || searchName.contains(name)) {
                    val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launchIntent)
                        launched = true
                        break
                    }
                }
            }
            launched
        }

        Function("callContact") { contactName: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            var number: String? = null
            var resolvedName: String? = null
            try {
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                )
                val cursor = context.contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val queryName = contactName.lowercase(Locale.US).trim()
                    while (it.moveToNext()) {
                        val displayName = it.getString(nameIndex) ?: ""
                        val lowerDisplay = displayName.lowercase(Locale.US).trim()
                        if (lowerDisplay == queryName || lowerDisplay.contains(queryName) || queryName.contains(lowerDisplay)) {
                            number = it.getString(numberIndex)
                            resolvedName = displayName
                            break
                        }
                    }
                }
                if (number != null) {
                    val hasCallPermission = context.checkSelfPermission(android.Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
                    val intent = if (hasCallPermission) {
                        Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    } else {
                        Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }
                    context.startActivity(intent)
                }
            } catch (e: Exception) {
                Log.e("WakeWordModule", "Error calling contact", e)
            }
            mapOf("success" to (number != null), "resolvedName" to (resolvedName ?: ""))
        }

        Function("sendSMS") { contactName: String, message: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            var number: String? = null
            var resolvedName: String? = null
            try {
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                )
                val cursor = context.contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val queryName = contactName.lowercase(Locale.US).trim()
                    while (it.moveToNext()) {
                        val displayName = it.getString(nameIndex) ?: ""
                        val lowerDisplay = displayName.lowercase(Locale.US).trim()
                        if (lowerDisplay == queryName || lowerDisplay.contains(queryName) || queryName.contains(lowerDisplay)) {
                            number = it.getString(numberIndex)
                            resolvedName = displayName
                            break
                        }
                    }
                }
                val smsUri = Uri.parse("smsto:${number ?: ""}")
                val intent = Intent(Intent.ACTION_SENDTO, smsUri).apply {
                    putExtra("sms_body", message)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                Log.e("WakeWordModule", "Error sending SMS", e)
            }
            mapOf("success" to true, "resolvedName" to (resolvedName ?: ""))
        }

        Function("isNotificationListenerEnabled") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val enabledListeners = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            enabledListeners != null && enabledListeners.contains(context.packageName)
        }

        Function("requestNotificationListenerPermission") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        Function("readNotifications") {
            val notifications = mutableListOf<Map<String, Any>>()
            val instance = KrithaNotificationListener.instance
            if (instance != null) {
                try {
                    val active = instance.activeNotifications
                    for (sbn in active) {
                        val extras = sbn.notification.extras
                        val title = extras.getString("android.title") ?: ""
                        val text = extras.getCharSequence("android.text")?.toString() ?: ""
                        val appName = sbn.packageName
                        notifications.add(mapOf(
                            "packageName" to appName,
                            "title" to title,
                            "text" to text
                        ))
                    }
                } catch (e: Exception) {
                    Log.e("WakeWordModule", "Error reading notifications", e)
                }
            }
            notifications
        }

        Function("getCalendarEvents") {
            val events = mutableListOf<Map<String, Any>>()
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            try {
                val uri = CalendarContract.Events.CONTENT_URI
                val projection = arrayOf(
                    CalendarContract.Events.TITLE,
                    CalendarContract.Events.DTSTART,
                    CalendarContract.Events.DESCRIPTION
                )
                val selection = "${CalendarContract.Events.DTSTART} >= ?"
                val selectionArgs = arrayOf(System.currentTimeMillis().toString())
                val sortOrder = "${CalendarContract.Events.DTSTART} ASC"

                val cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
                cursor?.use {
                    val titleIndex = it.getColumnIndex(CalendarContract.Events.TITLE)
                    val startIndex = it.getColumnIndex(CalendarContract.Events.DTSTART)
                    val descIndex = it.getColumnIndex(CalendarContract.Events.DESCRIPTION)
                    var count = 0
                    while (it.moveToNext() && count < 5) {
                        val title = it.getString(titleIndex) ?: ""
                        val start = it.getLong(startIndex)
                        val desc = it.getString(descIndex) ?: ""
                        events.add(mapOf(
                            "title" to title,
                            "startTime" to start,
                            "description" to desc
                        ))
                        count++
                    }
                }
            } catch (e: Exception) {
                Log.e("WakeWordModule", "Error reading calendar events", e)
            }
            events
        }

        Function("dispatchMediaKey") { keyCode: Int ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val eventTime = SystemClock.uptimeMillis()
            val downEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0)
            val upEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0)
            audioManager.dispatchMediaKeyEvent(downEvent)
            audioManager.dispatchMediaKeyEvent(upEvent)
        }
    }
}

internal object WakeWordNative {
    init {
        try {
            System.loadLibrary("wakeword_bridge")
            Log.i("WakeWord", "Loaded wake-word inference library")
        } catch (error: Throwable) {
            Log.e("WakeWord", "Unable to load wake-word inference library", error)
        }
    }

    external fun runInference(samples: ShortArray): FloatArray?
}

internal object WakeWordEventHub {
    @Volatile
    var listener: ((keyword: String, confidence: Float) -> Unit)? = null

    @Volatile
    var assistantListener: ((
        state: String,
        transcript: String?,
        response: String?,
        error: String?
    ) -> Unit)? = null

    fun emit(keyword: String, confidence: Float) {
        listener?.invoke(keyword, confidence)
    }

    fun emitAssistant(
        state: String,
        transcript: String? = null,
        response: String? = null,
        error: String? = null
    ) {
        assistantListener?.invoke(state, transcript, response, error)
    }
}
