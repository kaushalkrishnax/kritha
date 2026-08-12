package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.SystemClock
import android.view.KeyEvent

internal object MediaCommandHandler {
    fun canHandle(lower: String): Boolean {
        return "music" in lower || "song" in lower || "playback" in lower || "track" in lower ||
               lower.startsWith("play ") ||
               lower in setOf("play", "pause", "resume", "next", "skip", "previous", "prev")
    }

    fun handle(lower: String, context: Context): String {
        // 1. Handle Explicit "Play {Song Name}" Search Queries
        if (lower.startsWith("play ")) {
            val songName = lower.removePrefix("play ").trim()
            val restrictedKeywords = setOf("music", "song", "track", "playback", "something")
            
            if (songName.isNotEmpty() && !restrictedKeywords.contains(songName)) {
                try {
                    val intent = Intent(android.provider.MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).apply {
                        putExtra(android.app.SearchManager.QUERY, songName)
                        putExtra(android.provider.MediaStore.EXTRA_MEDIA_FOCUS, "vnd.android.cursor.item/*")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    
                    // Try-catch bypass for package visibility constraints on Android 11+
                    context.startActivity(intent)
                    return "Playing $songName on your default media app."
                } catch (e: Exception) {
                    // System fallback: Open standard web search on YouTube via browser
                    try {
                        val encodedQuery = android.net.Uri.encode("Play $songName")
                        val browserIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.youtube.com/results?search_query=$encodedQuery")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(browserIntent)
                        return "Searching for $songName on YouTube web."
                    } catch (e3: Exception) {
                        // Fallthrough to global hardware keys below if everything crashes
                    }
                }
            }
        }

        // 2. Handle Generic "Play Music" or "Resume" Requests via App Scheme
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
                // Explicitly fallthrough to standard system hardware media events below
            }
        }

        // 3. Fallback: Parse Control KeyEvents (Pause, Next, Prev)
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
