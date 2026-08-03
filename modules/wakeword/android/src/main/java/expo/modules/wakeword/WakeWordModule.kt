package expo.modules.wakeword

import android.os.Handler
import android.os.Looper
import android.util.Log
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

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
