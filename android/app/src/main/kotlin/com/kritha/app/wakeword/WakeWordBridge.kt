package com.kritha.app.wakeword

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.kritha.app.MainActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class WakeWordBridge(private val activity: MainActivity) {
    companion object {
        private const val TAG = "KrithaWakeWordBridge"
        private const val METHOD_CHANNEL = "com.kritha/wake_word"
        private const val EVENT_CHANNEL = "com.kritha/wake_word/events"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRunning" -> result.success(WakeWordForegroundService.isRunning)
                    "isAvailable" -> result.success(WakeWordNative.available)
                    "start" -> start(result)
                    "stop" -> {
                        WakeWordForegroundService.stop(activity)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    WakeWordEvents.listen(events)
                }

                override fun onCancel(arguments: Any?) {
                    WakeWordEvents.listen(null)
                }
            })
    }

    private fun start(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("MIC_PERMISSION_REQUIRED", "Microphone permission is required for wake-word listening.", null)
            return
        }
        if (!WakeWordNative.available) {
            result.error("WAKEWORD_MODEL_UNAVAILABLE", "Wake-word inference is not available in this build.", null)
            return
        }
        try {
            WakeWordForegroundService.start(activity)
            result.success(true)
        } catch (error: Throwable) {
            Log.e(TAG, "Could not start wake-word service", error)
            result.error("WAKEWORD_START_FAILED", error.message, null)
        }
    }
}
