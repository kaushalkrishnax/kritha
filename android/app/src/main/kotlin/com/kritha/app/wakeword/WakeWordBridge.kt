package com.kritha.app.wakeword

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.kritha.app.MainActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class WakeWordBridge(private val activity: FlutterActivity) {
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
                    "pauseListening" -> {
                        WakeWordForegroundService.pauseForMic()
                        result.success(true)
                    }
                    "resumeListening" -> {
                        WakeWordForegroundService.resumeAfterMic()
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                            Settings.canDrawOverlays(activity)
                        result.success(granted)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(activity)
                        ) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:${activity.packageName}"),
                            )
                            activity.startActivity(intent)
                        }
                        result.success(true)
                    }
                    "dismissOverlay" -> {
                        KrithaOverlayActivity.stopIfActive()
                        result.success(true)
                    }
                    "openMainApp" -> {
                        val intent = Intent(activity, MainActivity::class.java).apply {
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
                            )
                        }
                        activity.startActivity(intent)
                        KrithaOverlayActivity.stopIfActive()
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
