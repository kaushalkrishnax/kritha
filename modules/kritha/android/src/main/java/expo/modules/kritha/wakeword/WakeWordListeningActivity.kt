package expo.modules.kritha.wakeword

import android.app.KeyguardManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactActivityDelegate
import expo.modules.kritha.NativeAssistantSession

class WakeWordListeningActivity : ReactActivity() {

    companion object {
        @Volatile
        private var instance: WakeWordListeningActivity? = null

        fun stopSessionIfActive() {
            instance?.finishAndRemoveTask()
        }

        internal val activeSession: NativeAssistantSession?
            get() = instance?.assistantSession
    }

    internal var assistantSession: NativeAssistantSession? = null

    override fun getMainComponentName(): String = "AssistantOverlay"

    override fun createReactActivityDelegate(): ReactActivityDelegate {
        return DefaultReactActivityDelegate(
            this,
            mainComponentName,
            fabricEnabled
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this

        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
        )

        showAboveLockScreen()
        startAssistantSession()
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        startAssistantSession()
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }

        assistantSession?.shutdown()
        assistantSession = null

        WakeWordForegroundService.onAssistantSessionFinished()

        super.onDestroy()
    }

    private fun startAssistantSession() {
        assistantSession?.shutdown()

        assistantSession = NativeAssistantSession(
            this,
            object : NativeAssistantSession.Callback {
                override fun onListening() {
                    WakeWordEventHub.emitAssistant("listening")
                }

                override fun onRmsChanged(rmsdB: Float) {
                    WakeWordEventHub.emitAssistant("rms", rms = rmsdB)
                }

                override fun onPartial(transcript: String) {
                    WakeWordEventHub.emitAssistant("partial", transcript = transcript)
                }

                override fun onProcessing(transcript: String) {
                    WakeWordEventHub.emitAssistant("processing", transcript = transcript)
                }

                override fun onStreaming(transcript: String, chunk: String) {
                    WakeWordEventHub.emitAssistant("streaming", transcript = transcript, chunk = chunk)
                }

                override fun onFinished(transcript: String?, response: String) {
                    WakeWordEventHub.emitAssistant("finished", transcript = transcript, response = response)
                }

                override fun onError(message: String) {
                    WakeWordEventHub.emitAssistant("error", error = message)
                }

                override fun onSessionFinished() {
                    assistantSession = null
                }

                override fun onTtsStart() {
                    WakeWordEventHub.emitAssistant("tts_start")
                }

                override fun onTtsPause() {
                    WakeWordEventHub.emitAssistant("tts_pause")
                }

                override fun onTtsDone() {
                    WakeWordEventHub.emitAssistant("tts_done")
                }
            }
        ).also {
            it.start()
        }
    }

    @Suppress("DEPRECATION")
    private fun showAboveLockScreen() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)

            getSystemService(
                KeyguardManager::class.java
            )?.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION

        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
    }
}