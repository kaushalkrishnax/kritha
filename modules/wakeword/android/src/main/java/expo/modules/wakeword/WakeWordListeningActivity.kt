package expo.modules.wakeword

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class WakeWordListeningActivity : Activity() {
    companion object {
        @Volatile
        private var instance: WakeWordListeningActivity? = null

        fun stopSessionIfActive() {
            instance?.let { activity ->
                activity.finishAndRemoveTask()
            }
        }

        internal val activeSession: NativeAssistantSession?
            get() = instance?.assistantSession
    }

    internal var assistantSession: NativeAssistantSession? = null
    private var pulseAnimator: AnimatorSet? = null

    private lateinit var titleView: TextView
    private lateinit var subtitleView: TextView
    private lateinit var orb: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        showAboveLockScreen()
        setContentView(createContentView())
        
        startOrbPulse()
        startAssistantSession()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        startAssistantSession()
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        stopOrbPulse()
        assistantSession?.shutdown()
        assistantSession = null
        WakeWordForegroundService.onAssistantSessionFinished()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun showAboveLockScreen() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            getSystemService(KeyguardManager::class.java).requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
    }

    private fun createContentView(): View {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(48), dp(32), dp(48))
            setBackgroundColor(Color.rgb(8, 15, 30))
        }

        orb = TextView(this).apply {
            text = "✦"
            textSize = 58f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(Color.rgb(32, 138, 239), Color.rgb(121, 80, 242))
                gradientType = GradientDrawable.LINEAR_GRADIENT
            }
        }
        container.addView(orb, LinearLayout.LayoutParams(dp(132), dp(132)).apply {
            bottomMargin = dp(36)
        })

        titleView = TextView(this).apply {
            text = "Listening…"
            textSize = 34f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
        }
        container.addView(titleView)

        subtitleView = TextView(this).apply {
            text = "What can I help with?"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(181, 195, 218))
            setPadding(0, dp(12), 0, dp(44))
        }
        container.addView(subtitleView)

        container.addView(Button(this).apply {
            text = "Dismiss"
            setOnClickListener { finishAndRemoveTask() }
        }, LinearLayout.LayoutParams(dp(180), dp(52)))

        return container
    }

    private fun startAssistantSession() {
        assistantSession?.shutdown()
        assistantSession = NativeAssistantSession(
            this,
            object : NativeAssistantSession.Callback {
                override fun onAssistantListening() {
                    titleView.text = "Listening…"
                    subtitleView.text = "How can I help you?"
                    WakeWordEventHub.emitAssistant("listening")
                }

                override fun onAssistantProcessing(transcript: String) {
                    titleView.text = "Processing…"
                    subtitleView.text = transcript
                    WakeWordEventHub.emitAssistant("processing", transcript = transcript)
                }

                override fun onAssistantFinished(transcript: String?, response: String) {
                    titleView.text = response
                    subtitleView.text = transcript ?: ""
                    WakeWordEventHub.emitAssistant(
                        "finished",
                        transcript = transcript,
                        response = response
                    )
                }

                override fun onAssistantError(message: String) {
                    titleView.text = "Error"
                    subtitleView.text = message
                    WakeWordEventHub.emitAssistant("error", error = message)
                }

                override fun onAssistantResponseSpoken() {
                    assistantSession?.shutdown()
                    assistantSession = null
                    finishAndRemoveTask()
                }
            }
        ).also { it.start() }
    }

    private fun startOrbPulse() {
        val scaleX = ObjectAnimator.ofFloat(orb, "scaleX", 1f, 1.15f, 1f)
        val scaleY = ObjectAnimator.ofFloat(orb, "scaleY", 1f, 1.15f, 1f)
        scaleX.repeatCount = ObjectAnimator.INFINITE
        scaleY.repeatCount = ObjectAnimator.INFINITE

        pulseAnimator = AnimatorSet().apply {
            playTogether(scaleX, scaleY)
            duration = 2000
            start()
        }
    }

    private fun stopOrbPulse() {
        pulseAnimator?.cancel()
        pulseAnimator = null
    }
}
