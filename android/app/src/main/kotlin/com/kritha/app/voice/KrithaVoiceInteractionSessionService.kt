package com.kritha.app.voice

import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import com.kritha.app.wakeword.KrithaOverlayActivity

class KrithaVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return object : VoiceInteractionSession(this) {
            override fun onShow(args: Bundle?, showFlags: Int) {
                super.onShow(args, showFlags)
                setUiEnabled(false)

                val intent = Intent(
                    this@KrithaVoiceInteractionSessionService,
                    KrithaOverlayActivity::class.java,
                ).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_NO_ANIMATION,
                    )
                    putExtra(EXTRA_LAUNCH_SOURCE, LAUNCH_SOURCE_VOICE_INTERACTION)
                }
                startAssistantActivity(intent)
            }
        }
    }

    companion object {
        const val EXTRA_LAUNCH_SOURCE = "EXTRA_LAUNCH_SOURCE"
        const val LAUNCH_SOURCE_VOICE_INTERACTION = "voice_interaction"
    }
}
