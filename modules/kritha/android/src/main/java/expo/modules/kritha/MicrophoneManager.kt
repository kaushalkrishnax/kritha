package expo.modules.kritha

import android.util.Log
import expo.modules.kritha.wakeword.WakeWordEventHub
import expo.modules.kritha.wakeword.WakeWordForegroundService
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

object MicrophoneManager {
    private const val TAG = "MicrophoneManager"
    private val lock = ReentrantLock()

    enum class Owner {
        NONE,
        WAKE_WORD,
        STT
    }

    @Volatile
    var currentOwner: Owner = Owner.NONE
        private set

    fun claimForStt(chatSessionId: String = "", assistantRunId: String = ""): Boolean = lock.withLock {
        Log.d(TAG, "Requesting mic claim for STT (Current owner: $currentOwner)")
        if (currentOwner == Owner.STT) return true

        // Asynchronous pause of wake-word recorder
        WakeWordForegroundService.pauseForStt()

        currentOwner = Owner.STT
        WakeWordEventHub.emitMicrophoneChanged(
            chatSessionId = chatSessionId,
            assistantRunId = assistantRunId,
            owner = "STT",
            isClaimed = true
        )
        Log.d(TAG, "Mic successfully claimed for STT")
        return true
    }

    fun releaseFromStt(chatSessionId: String = "", assistantRunId: String = "") = lock.withLock {
        Log.d(TAG, "Releasing mic from STT (Current owner: $currentOwner)")
        if (currentOwner == Owner.STT) {
            currentOwner = Owner.NONE
            WakeWordEventHub.emitMicrophoneChanged(
                chatSessionId = chatSessionId,
                assistantRunId = assistantRunId,
                owner = "NONE",
                isClaimed = false
            )
            WakeWordForegroundService.resumeFromStt()
        }
    }

    fun setWakeWordOwner(chatSessionId: String = "", assistantRunId: String = "") = lock.withLock {
        if (currentOwner != Owner.STT) {
            currentOwner = Owner.WAKE_WORD
            WakeWordEventHub.emitMicrophoneChanged(
                chatSessionId = chatSessionId,
                assistantRunId = assistantRunId,
                owner = "WAKE_WORD",
                isClaimed = true
            )
        }
    }

    fun releaseWakeWordOwner(chatSessionId: String = "", assistantRunId: String = "") = lock.withLock {
        if (currentOwner == Owner.WAKE_WORD) {
            currentOwner = Owner.NONE
            WakeWordEventHub.emitMicrophoneChanged(
                chatSessionId = chatSessionId,
                assistantRunId = assistantRunId,
                owner = "NONE",
                isClaimed = false
            )
        }
    }
}
