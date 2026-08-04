package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.SystemClock
import android.view.KeyEvent

internal object MediaCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "music" in lower || "song" in lower || "playback" in lower || "track" in lower ||
               lower in setOf("play", "pause", "resume", "next", "skip", "previous", "prev")
    }

    fun handle(lower: String, context: Context): String {
        val isPlayRequest = ("play" in lower || "resume" in lower) && 
                            ("music" in lower || "song" in lower || "track" in lower || lower == "play" || lower == "resume")

        if (isPlayRequest) {
            try {
                val intent = Intent.parseUri("intent://song/1_BBsr7o#Intent;scheme=sausico;end", Intent.URI_INTENT_SCHEME).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                return "Playing music."
            } catch (e: Exception) {
                // Fallback to normal media key dispatch if the activity can't be resolved/started
            }
        }

        val keyCode = when {
            "pause" in lower || "stop" in lower -> KeyEvent.KEYCODE_MEDIA_PAUSE
            "play" in lower || "resume" in lower -> KeyEvent.KEYCODE_MEDIA_PLAY
            "next" in lower || "skip" in lower -> KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" in lower || "prev" in lower -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
        }
        val actionLabel = when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PAUSE -> "pausing music"
            KeyEvent.KEYCODE_MEDIA_PLAY -> "playing music"
            KeyEvent.KEYCODE_MEDIA_NEXT -> "skipping track"
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "going back one track"
            else -> "toggling playback"
        }
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val eventTime = SystemClock.uptimeMillis()
            val downEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0)
            val upEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0)
            audioManager.dispatchMediaKeyEvent(downEvent)
            audioManager.dispatchMediaKeyEvent(upEvent)
            "Okay, $actionLabel."
        } catch (e: Exception) {
            "Failed to control music."
        }
    }
}
