package expo.modules.kritha

import android.util.Log
import expo.modules.kritha.runtime.tts.SpeechAudio
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.cancellation.CancellationException

/**
 * TTS runs end-to-end through the runtime provider (chunked synthesis +
 * AudioTrack playback). STT is not implemented by the runtime stack yet, so
 * every recognition entry point is a stub that emits lifecycle events without
 * capturing audio.
 */
internal class VoiceManager(
    private val bridge: TtsModuleBridge,
    private val eventEmitter: (String, Map<String, Any?>) -> Unit,
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var speechPlayer: StreamingPcmPlayer? = null

    private var speakJob: Job? = null
    private var activeTtsRequestId: String? = null
    private val ttsPaused = AtomicBoolean(false)

    companion object {
        private const val TAG = "VoiceManager"

        private fun friendlyTtsMessage(raw: String): String {
            // The runtime surfaces "Failed to invoke the compiled model"
            // generically; on-device the underlying cause is often "Failed to
            // allocate tensors" (OOM).
            return if (
                raw.contains("invoke the compiled model") ||
                raw.contains("allocate tensors") ||
                raw.contains("out of memory", ignoreCase = true)
            ) {
                "Not enough memory to synthesize speech. Free up memory and try again."
            } else {
                raw
            }
        }
    }

    suspend fun startListening(requestId: String): Unit = withContext(Dispatchers.IO) {
        eventEmitter("onSttStarted", mapOf("requestId" to requestId))
    }

    suspend fun stopListening(requestId: String): String = withContext(Dispatchers.IO) {
        eventEmitter("onSttStopped", mapOf("requestId" to requestId, "text" to ""))
        ""
    }

    suspend fun cancelListening(requestId: String): Unit = withContext(Dispatchers.IO) {
        eventEmitter("onSttCancelled", mapOf("requestId" to requestId))
    }

    fun start(llmModelPath: String?, llmDevice: String) {
        Log.i(TAG, "Continuous STT is stubbed; LiteRT speech-to-text is not implemented yet.")
    }

    fun stop() {
        val activeTts = activeTtsRequestId
        activeTtsRequestId = null
        ttsPaused.set(false)
        speakJob?.cancel()
        speakJob = null

        try {
            speechPlayer?.stopPlayback()
        } catch (_: Exception) {}

        if (activeTts != null) {
            eventEmitter("onTtsStopped", mapOf("requestId" to activeTts))
        }
    }

    fun speak(requestId: String, text: String, voice: String = "F1", onDone: (() -> Unit)? = null) {
        if (text.isBlank()) {
            eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "Nothing to speak"))
            onDone?.invoke()
            return
        }

        val selection = bridge.resolveActiveTts()
        if (selection == null) {
            eventEmitter(
                "onTtsError",
                mapOf("requestId" to requestId, "message" to "TTS model not downloaded"),
            )
            onDone?.invoke()
            return
        }
        val modelDirectory = selection.directory.absolutePath

        val previous = activeTtsRequestId
        if (previous != null && previous != requestId) {
            // Stop previous playback without completing the old owner.
            speakJob?.cancel()
            try {
                speechPlayer?.stopPlayback()
            } catch (_: Exception) {}
            eventEmitter("onTtsStopped", mapOf("requestId" to previous, "replaced" to true))
        } else {
            speakJob?.cancel()
        }
        activeTtsRequestId = requestId
        ttsPaused.set(false)

        speakJob = scope.launch {
            try {
                eventEmitter("onTtsStarted", mapOf("requestId" to requestId))
                eventEmitter("onResponseCreated", mapOf("requestId" to requestId, "text" to ""))

                val pieces = SpeechChunks.split(text)
                var player: StreamingPcmPlayer? = null

                for ((idx, piece) in pieces.withIndex()) {
                    if (!isActive || activeTtsRequestId != requestId) {
                        break
                    }
                    while (activeTtsRequestId == requestId && ttsPaused.get()) {
                        delay(20)
                    }
                    if (!isActive || activeTtsRequestId != requestId) break
                    if (piece.isBlank()) continue

                    val audio = synthesize(piece, selection, voice)
                    val pcm16 = if (audio.pcm.isEmpty()) ByteArray(0) else bridge.encodePcm16(audio.pcm)
                    if (pcm16.isEmpty()) {
                        continue
                    }
                    if (activeTtsRequestId != requestId) break

                    if (player == null) {
                        player = StreamingPcmPlayer(audio.sampleRate).also { speechPlayer = it }
                        player.start(pcm16)
                    } else {
                        player.write(pcm16)
                    }
                }

                if (activeTtsRequestId != requestId) {
                    return@launch
                }
                val activePlayer = player
                if (activePlayer == null) {
                    activeTtsRequestId = null
                    eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "No audio generated"))
                    return@launch
                }
                while (ttsPaused.get() && activeTtsRequestId == requestId) {
                    delay(20)
                }
                if (activeTtsRequestId != requestId) return@launch
                activePlayer.awaitDrained()
                activePlayer.stopPlayback()

                if (activeTtsRequestId != requestId) return@launch
                activeTtsRequestId = null
                eventEmitter("onTtsCompleted", mapOf("requestId" to requestId))
                eventEmitter("onResponseDone", mapOf("requestId" to requestId))
            } catch (e: Exception) {
                if (e is CancellationException) {
                    return@launch
                }
                if (activeTtsRequestId == requestId) {
                    activeTtsRequestId = null
                    val message = friendlyTtsMessage(e.message ?: "TTS error")
                    eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to message))
                    eventEmitter("onError", mapOf("requestId" to requestId, "message" to message))
                }
            } finally {
                // TTS engines only need to stay resident while speech is being
                // produced; free the active model once this request is no longer
                // current so memory returns to baseline between utterances.
                if (activeTtsRequestId == null || activeTtsRequestId != requestId) {
                    bridge.releaseActiveTts()
                }
                onDone?.invoke()
            }
        }
    }

    private fun synthesize(
        piece: String,
        selection: TtsModuleBridge.ActiveTts,
        voice: String,
    ): SpeechAudio {
        return bridge.synthesizeTtsPcm(
            modelId = selection.modelId,
            modelDirectory = selection.directory.absolutePath,
            text = piece,
            voice = voice,
        )
    }

    fun pauseSpeaking(requestId: String? = null) {
        val active = activeTtsRequestId
        if (active == null) return
        if (requestId != null && requestId != active) return
        if (ttsPaused.getAndSet(true)) return
        try {
            speechPlayer?.pausePlayback()
        } catch (_: Exception) {}
        eventEmitter("onTtsPaused", mapOf("requestId" to active))
    }

    fun resumeSpeaking(requestId: String? = null) {
        val active = activeTtsRequestId
        if (active == null) return
        if (requestId != null && requestId != active) return
        if (!ttsPaused.getAndSet(false)) return
        try {
            speechPlayer?.resumePlayback()
        } catch (_: Exception) {}
        eventEmitter("onTtsResumed", mapOf("requestId" to active))
    }

    fun stopSpeaking(requestId: String? = null) {
        val active = activeTtsRequestId
        if (active == null) {
            try {
                speechPlayer?.stopPlayback()
            } catch (_: Exception) {}
            return
        }
        if (requestId != null && requestId != active) return
        activeTtsRequestId = null
        ttsPaused.set(false)
        speakJob?.cancel()
        speakJob = null
        try {
            speechPlayer?.stopPlayback()
        } catch (_: Exception) {}
        eventEmitter("onTtsStopped", mapOf("requestId" to active))
        eventEmitter("onResponseInterrupted", mapOf("requestId" to active))
    }
}