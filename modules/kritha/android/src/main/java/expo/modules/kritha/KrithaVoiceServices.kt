package expo.modules.kritha

import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.speech.RecognitionService
import android.speech.SpeechRecognizer
import android.util.Log
import expo.modules.kritha.wakeword.WakeWordListeningActivity

class KrithaVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
        Log.d("KrithaAssistant", "VoiceInteractionService ready")
    }

    override fun onShutdown() {
        Log.d("KrithaAssistant", "VoiceInteractionService shutdown")
        super.onShutdown()
    }
}

class KrithaVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return object : VoiceInteractionSession(this) {

            override fun onShow(args: Bundle?, showFlags: Int) {
                super.onShow(args, showFlags)

                Log.d(
                    "KrithaAssistant",
                    "VoiceInteractionSession onShow flags=$showFlags"
                )
                setUiEnabled(false)

                if (WakeWordListeningActivity.isInstanceActive) {
                    WakeWordListeningActivity.onWakeWordDetected(origin = "MANUAL_DICTATION")
                    return
                }

                val intent = Intent(
                    context,
                    WakeWordListeningActivity::class.java
                ).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_NO_ANIMATION
                    )
                    putExtra("EXTRA_LAUNCH_SOURCE", "voice_interaction")
                }

                startAssistantActivity(intent)
            }
        }
    }
}

class KrithaRecognitionService : RecognitionService() {

    @Volatile
    private var engine: AsrEngine? = null

    @Volatile
    private var activeCallback: Callback? = null

    override fun onStartListening(intent: Intent?, listener: Callback?) {
        Log.d(TAG, "onStartListening: Moonshine STT request")
        // Replace any previous request; Android only allows one active session.
        cancelActive()
        if (listener == null) return
        activeCallback = listener
        engine = MoonshineAsrEngine(applicationContext, recognitionListener)
        engine?.start()
    }

    override fun onStopListening(listener: Callback?) {
        Log.d(TAG, "onStopListening: finalizing Moonshine transcript")
        // Stops capture; the engine promotes the latest partial to a final transcript
        // synchronously when speech was heard.
        engine?.stopListening()
        // If nothing was transcribed (the callback is still unconsumed), tell the
        // caller there was no speech to match.
        if (activeCallback != null) {
            deliver { it.error(SpeechRecognizer.ERROR_NO_MATCH) }
            cancelActive()
        }
    }

    override fun onCancel(listener: Callback?) {
        Log.d(TAG, "onCancel: discarding Moonshine transcript")
        cancelActive()
    }

    private fun cancelActive() {
        activeCallback = null
        engine?.shutdown()
        engine = null
    }

    /** Bridges the Moonshine engine callbacks to the Android [RecognitionService.Callback]. */
    private val recognitionListener = object : AsrEngine.Listener {
        override fun onListening() {
            deliver { it.readyForSpeech(Bundle()) }
        }

        override fun onRmsChanged(rmsdB: Float) {
            deliver { it.rmsChanged(rmsdB) }
        }

        override fun onPartial(transcript: String) {
            if (transcript.isBlank()) return
            deliver { it.partialResults(transcriptBundle(transcript)) }
        }

        override fun onFinal(transcript: String) {
            deliver { cb ->
                if (transcript.isNotBlank()) {
                    cb.results(transcriptBundle(transcript))
                } else {
                    cb.error(SpeechRecognizer.ERROR_NO_MATCH)
                }
            }
            cancelActive()
        }

        override fun onError(message: String) {
            Log.e(TAG, "Moonshine STT error: $message")
            deliver { it.error(errorCode(message)) }
            cancelActive()
        }
    }

    private inline fun deliver(block: (Callback) -> Unit) {
        val cb = activeCallback ?: return
        runCatching { block(cb) }
            .onFailure { Log.e(TAG, "Failed to deliver STT callback", it) }
    }

    private fun transcriptBundle(transcript: String): Bundle = Bundle().apply {
        putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, arrayListOf(transcript))
        putFloatArray(SpeechRecognizer.CONFIDENCE_SCORES, floatArrayOf(1f))
    }

    private fun errorCode(message: String): Int = when {
        message.contains("permission", ignoreCase = true) ->
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS
        message.contains("network", ignoreCase = true) ||
            message.contains("download", ignoreCase = true) ||
            message.contains("model", ignoreCase = true) ->
            SpeechRecognizer.ERROR_NETWORK
        else -> SpeechRecognizer.ERROR_CLIENT
    }

    companion object {
        private const val TAG = "KrithaRecognitionService"
    }
}