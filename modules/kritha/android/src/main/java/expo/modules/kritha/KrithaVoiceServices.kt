package expo.modules.kritha

import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.speech.RecognitionService
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

    override fun onStartListening(
        intent: Intent?,
        listener: Callback?
    ) {
    }

    override fun onCancel(listener: Callback?) {
    }

    override fun onStopListening(listener: Callback?) {
    }
}