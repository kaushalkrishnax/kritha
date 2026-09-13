package expo.modules.kritha.platform.voice

import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.util.Log

/** System voice-interaction service entry ("Kritha Assistant" role). */
class KrithaVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
        Log.d(TAG, "VoiceInteractionService ready")
    }

    override fun onShutdown() {
        Log.d(TAG, "VoiceInteractionService shutdown")
        super.onShutdown()
    }

    companion object {
        private const val TAG = "KrithaAssistant"
    }
}
