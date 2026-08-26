package expo.modules.kritha.wakeword

import android.app.KeyguardManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactActivityDelegate
import expo.modules.kritha.AssistantCore
import expo.modules.kritha.NativeAssistantSession
import java.util.UUID

class WakeWordListeningActivity : ReactActivity() {

    companion object {
        @Volatile
        private var instance: WakeWordListeningActivity? = null

        val isInstanceActive: Boolean
            get() = instance != null

        val activeSessionId: String
            get() = AssistantCore.activeChatSessionId

        fun onWakeWordDetected(origin: String = "WAKE_WORD") {
            instance?.let { activity ->
                activity.runOnUiThread {
                    AssistantCore.startVoiceSession(activity, origin = origin)
                }
            }
        }

        fun stopSessionIfActive() {
            instance?.finishAndRemoveTask()
        }

        fun processPrompt(text: String, autoTts: Boolean) {
            val activity = instance ?: return
            val origin = if (autoTts) "MANUAL_DICTATION" else "MANUAL_TYPING"
            AssistantCore.submitText(activity, text, origin = origin)
        }
    }

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

        AssistantCore.init(this)

        window.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
        )
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        )
        window.addFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        showAboveLockScreen()

        AssistantCore.startVoiceSession(this, origin = "WAKE_WORD")

        window.decorView.post {
            window.decorView.requestFocus()
            window.decorView.requestLayout()
        }
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)

        val launchSource = intent?.getStringExtra("EXTRA_LAUNCH_SOURCE")
        val origin = if (launchSource == "voice_interaction") "MANUAL_DICTATION" else "WAKE_WORD"
        AssistantCore.startVoiceSession(this, origin = origin)
    }

    override fun onBackPressed() {
        AssistantCore.dismiss()
    }

    override fun onPause() {
        super.onPause()
    }

    override fun onStop() {
        super.onStop()
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        WakeWordForegroundService.onAssistantSessionFinished()
        super.onDestroy()
    }

    fun cancelSession() {
        AssistantCore.cancel()
    }

    @Suppress("DEPRECATION")
    private fun showAboveLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)

            val km = getSystemService(KeyguardManager::class.java)
            if (km?.isKeyguardLocked == true) {
                km.requestDismissKeyguard(this, null)
            }
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