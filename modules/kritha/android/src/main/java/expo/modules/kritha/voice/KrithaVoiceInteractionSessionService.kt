package expo.modules.kritha.platform.voice

import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import expo.modules.kritha.platform.wakeword.WakeWordListeningActivity

/**
 * Session service for the system voice interaction. Shows the assistant
 * overlay; if it is already open, just re-arms the voice session in it.
 */
class KrithaVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return object : VoiceInteractionSession(this) {

            override fun onShow(args: Bundle?, showFlags: Int) {
                super.onShow(args, showFlags)
                setUiEnabled(false)

                val intent = Intent(
                    this@KrithaVoiceInteractionSessionService,
                    WakeWordListeningActivity::class.java
                ).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_NO_ANIMATION
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
