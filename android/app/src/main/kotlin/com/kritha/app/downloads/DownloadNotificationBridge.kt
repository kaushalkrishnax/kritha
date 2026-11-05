package com.kritha.app.downloads

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class DownloadNotificationBridge(
    private val messenger: BinaryMessenger,
    private val context: Context,
) {
    companion object {
        private const val CHANNEL = "kritha/downloads"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    fun register() {
        DownloadNotificationEvents.attach(channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Download notification args are required.", null)
                        return@setMethodCallHandler
                    }
                    DownloadNotifications.show(context, args)
                    result.success(null)
                }
                "cancel" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = args?.get("id") as? String
                    if (id == null) {
                        result.error("INVALID_ARGS", "A download notification id is required.", null)
                        return@setMethodCallHandler
                    }
                    val notificationId = (args["notificationId"] as? Number)?.toInt()
                    DownloadNotifications.cancel(context, id, notificationId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
