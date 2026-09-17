package expo.modules.kritha.platform.wakeword

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

/**
 * Assistant overlay activity (React root "AssistantOverlay"). Hosts the JS
 * assistant UI when the assistant is invoked from the wake word or the system
 * voice interaction.
 */
class WakeWordListeningActivity : ReactActivity() {

    companion object {
        private const val EXTRA_LAUNCH_SOURCE = "EXTRA_LAUNCH_SOURCE"
        private const val VOICE_INTERACTION_LAUNCH_SOURCE = "voice_interaction"

        @Volatile
        private var instance: WakeWordListeningActivity? = null

        val isInstanceActive: Boolean
            get() = instance != null

        fun onWakeWordDetected() {
            // Placeholder - AssistantOrchestrator not available
        }

        fun stopSessionIfActive() {
            instance?.finishAndRemoveTask()
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

        window.decorView.post {
            window.decorView.requestFocus()
            window.decorView.requestLayout()
        }
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onBackPressed() {
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        WakeWordForegroundService.onAssistantSessionFinished()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun showAboveLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
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
