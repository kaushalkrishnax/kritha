package com.kritha.app.wakeword

import android.util.Log

internal object WakeWordNative {
    private const val TAG = "KrithaWakeWordNative"

    val available: Boolean by lazy {
        runCatching {
            System.loadLibrary("wakeword_bridge")
            true
        }.onFailure { Log.e(TAG, "Could not load wake-word inference library", it) }
            .getOrDefault(false)
    }

    @JvmStatic
    external fun runInference(samples: ShortArray): FloatArray?
}
