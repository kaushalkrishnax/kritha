package com.kritha.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.kritha.app.wakeword.WakeWordBridge
import com.kritha.app.wakeword.WakeWordEvents

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_WAKE_WORD_CONFIDENCE = "kritha.wake_word.confidence"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeWordBridge(this).register(flutterEngine)
        intent?.takeIf { it.hasExtra(EXTRA_WAKE_WORD_CONFIDENCE) }?.let {
            WakeWordEvents.emitDetected(it.getFloatExtra(EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            it.removeExtra(EXTRA_WAKE_WORD_CONFIDENCE)
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.hasExtra(EXTRA_WAKE_WORD_CONFIDENCE)) {
            WakeWordEvents.emitDetected(intent.getFloatExtra(EXTRA_WAKE_WORD_CONFIDENCE, 0f))
            intent.removeExtra(EXTRA_WAKE_WORD_CONFIDENCE)
        }
    }
}
