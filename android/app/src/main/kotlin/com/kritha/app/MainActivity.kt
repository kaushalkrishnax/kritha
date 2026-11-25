package com.kritha.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.kritha.app.downloads.DownloadNotificationBridge
import com.kritha.app.wakeword.WakeWordBridge
import com.kritha.app.wakeword.WakeWordEvents

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_WAKE_WORD_CONFIDENCE = "kritha.wake_word.confidence"

        @Volatile
        var isResumed: Boolean = false
            private set
    }

    override fun onResume() {
        super.onResume()
        isResumed = true
    }

    override fun onPause() {
        isResumed = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeWordBridge(this, isOverlay = false).register(flutterEngine)
        DownloadNotificationBridge(flutterEngine.dartExecutor.binaryMessenger, this).register()
        intent?.takeIf { it.hasExtra(EXTRA_WAKE_WORD_CONFIDENCE) }?.let {
            WakeWordEvents.emitToMain(it.getFloatExtra(EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            it.removeExtra(EXTRA_WAKE_WORD_CONFIDENCE)
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.hasExtra(EXTRA_WAKE_WORD_CONFIDENCE)) {
            WakeWordEvents.emitToMain(intent.getFloatExtra(EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            intent.removeExtra(EXTRA_WAKE_WORD_CONFIDENCE)
        }
    }
}
