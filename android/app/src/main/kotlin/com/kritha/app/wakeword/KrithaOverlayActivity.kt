package com.kritha.app.wakeword

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.view.WindowManager
import com.kritha.app.MainActivity
import com.kritha.app.downloads.DownloadNotificationBridge
import com.kritha.app.voice.KrithaVoiceInteractionSessionService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine

/**
 * Translucent assistant overlay activity launched when the wake word fires
 * while the main app is in the background or closed.
 */
class KrithaOverlayActivity : FlutterActivity() {
    companion object {
        @Volatile
        private var instance: KrithaOverlayActivity? = null

        val isInstanceActive: Boolean
            get() = instance != null

        fun stopIfActive() {
            instance?.finishAndRemoveTask()
        }
    }

    override fun getInitialRoute(): String = "/overlay"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeWordBridge(this, isOverlay = true).register(flutterEngine)
        DownloadNotificationBridge(flutterEngine.dartExecutor.binaryMessenger, this).register()
        intent?.takeIf { it.hasExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE) }?.let {
            WakeWordEvents.emitToOverlay(it.getFloatExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            it.removeExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this

        window.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.hasExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE)) {
            WakeWordEvents.emitToOverlay(intent.getFloatExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            intent.removeExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE)
        } else if (
            intent.action == Intent.ACTION_ASSIST ||
            intent.action == Intent.ACTION_VOICE_COMMAND ||
            intent.getStringExtra(KrithaVoiceInteractionSessionService.EXTRA_LAUNCH_SOURCE) ==
                KrithaVoiceInteractionSessionService.LAUNCH_SOURCE_VOICE_INTERACTION
        ) {
            WakeWordEvents.emitToOverlay(1.0f)
        }
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        WakeWordForegroundService.onOverlayFinished()
        super.onDestroy()
    }
}
