package com.kritha.app.wakeword

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object WakeWordEvents {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var mainSink: EventChannel.EventSink? = null
    @Volatile private var overlaySink: EventChannel.EventSink? = null
    @Volatile private var pendingMainConfidence: Double? = null
    @Volatile private var pendingOverlayConfidence: Double? = null

    fun listen(isOverlay: Boolean, eventSink: EventChannel.EventSink?) {
        if (isOverlay) {
            overlaySink = eventSink
            val pending = pendingOverlayConfidence
            if (pending != null && eventSink != null) {
                pendingOverlayConfidence = null
                eventSink.success(mapOf("type" to "detected", "confidence" to pending))
            }
        } else {
            mainSink = eventSink
            val pending = pendingMainConfidence
            if (pending != null && eventSink != null) {
                pendingMainConfidence = null
                eventSink.success(mapOf("type" to "detected", "confidence" to pending))
            }
        }
    }

    fun emitToMain(confidence: Float) {
        emit(isOverlay = false, confidence = confidence)
    }

    fun emitToOverlay(confidence: Float) {
        emit(isOverlay = true, confidence = confidence)
    }

    private fun emit(isOverlay: Boolean, confidence: Float) {
        val value = confidence.toDouble()
        val event = mapOf("type" to "detected", "confidence" to value)
        mainHandler.post {
            val current = if (isOverlay) overlaySink else mainSink
            if (current == null) {
                if (isOverlay) pendingOverlayConfidence = value else pendingMainConfidence = value
            } else {
                current.success(event)
            }
        }
    }
}
