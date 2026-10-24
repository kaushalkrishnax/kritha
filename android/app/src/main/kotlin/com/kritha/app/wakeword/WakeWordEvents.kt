package com.kritha.app.wakeword

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object WakeWordEvents {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var sink: EventChannel.EventSink? = null
    @Volatile private var pendingConfidence: Double? = null

    fun listen(eventSink: EventChannel.EventSink?) {
        sink = eventSink
        val pending = pendingConfidence
        if (pending != null && eventSink != null) {
            pendingConfidence = null
            eventSink.success(mapOf("type" to "detected", "confidence" to pending))
        }
    }

    fun emitDetected(confidence: Float) {
        val event = mapOf("type" to "detected", "confidence" to confidence.toDouble())
        mainHandler.post {
            val current = sink
            if (current == null) pendingConfidence = confidence.toDouble()
            else current.success(event)
        }
    }
}
