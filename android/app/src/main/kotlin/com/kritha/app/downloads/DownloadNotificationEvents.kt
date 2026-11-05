package com.kritha.app.downloads

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

object DownloadNotificationEvents {
    private var channel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())

    fun attach(value: MethodChannel) {
        channel = value
    }

    fun dispatch(id: String, action: String) {
        handler.post {
            channel?.invokeMethod("action", mapOf("id" to id, "action" to action))
        }
    }
}
