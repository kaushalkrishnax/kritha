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
 * TTS runs end-to-end on LiteRT (chunked synthesis + AudioTrack playback). STT
 * is not implemented by the LiteRT stack yet, so every recognition entry point
 * is a stub that emits lifecycle events without capturing audio.
 */
internal class LiteRTVoiceManager(
    private val bridge: LiteRTModuleBridge,
    private val eventEmitter: (String, Map<String, Any?>) -> Unit,
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var speechPlayer: StreamingPcmPlayer? = null

    private var speakJob: Job? = null
    private var activeTtsRequestId: String? = null
    private val ttsPaused = AtomicBoolean(false)

    companion object {
        private const val TAG = "LiteRTVoiceManager"

        private fun friendlyTtsMessage(raw: String): String {
            // LiteRT surfaces "Failed to invoke the compiled model" generically;
            // on-device the underlying cause is "Failed to allocate tensors" (OOM).
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
        Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager.speak called: requestId=$requestId, textLength=${text.length}, voice=$voice")
        if (text.isBlank()) {
            Log.w(TAG, "[TTS_DEBUG] LiteRTVoiceManager.speak: text is blank, emitting onTtsError")
            eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "Nothing to speak"))
            onDone?.invoke()
            return
        }

        val selection = bridge.resolveActiveTts()
        Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager.speak: activeTts=$selection")
        if (selection == null) {
            Log.e(TAG, "[TTS_DEBUG] LiteRTVoiceManager.speak: TTS model directory is null (model not downloaded)!")
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
            Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager.speak: cancelling previous TTS requestId=$previous")
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
                Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: emitting onTtsStarted for requestId=$requestId")
                eventEmitter("onTtsStarted", mapOf("requestId" to requestId))
                eventEmitter("onResponseCreated", mapOf("requestId" to requestId, "text" to ""))

                val pieces = SpeechChunks.split(text)
                Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: text split into ${pieces.size} chunks: $pieces")
                var player: StreamingPcmPlayer? = null

                for ((idx, piece) in pieces.withIndex()) {
                    if (!isActive || activeTtsRequestId != requestId) {
                        Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: speakJob cancelled before chunk $idx")
                        break
                    }
                    while (activeTtsRequestId == requestId && ttsPaused.get()) {
                        delay(20)
                    }
                    if (!isActive || activeTtsRequestId != requestId) break
                    if (piece.isBlank()) continue

                    Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: synthesizing chunk $idx: '$piece'...")
                    val audio = synthesize(piece, selection, voice)
                    Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: chunk $idx synthesized, raw samples=${audio.pcm.size}, rate=${audio.sampleRate}")
                    val pcm16 = if (audio.pcm.isEmpty()) ByteArray(0) else bridge.encodePcm16(audio.pcm)
                    if (pcm16.isEmpty()) {
                        Log.w(TAG, "[TTS_DEBUG] LiteRTVoiceManager: chunk $idx produced empty pcm16")
                        continue
                    }
                    if (activeTtsRequestId != requestId) break

                    if (player == null) {
                        Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: starting StreamingPcmPlayer with ${pcm16.size} bytes")
                        player = StreamingPcmPlayer(audio.sampleRate).also { speechPlayer = it }
                        player.start(pcm16)
                    } else {
                        Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: writing ${pcm16.size} bytes to StreamingPcmPlayer")
                        player.write(pcm16)
                    }
                }

                if (activeTtsRequestId != requestId) {
                    Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: activeTtsRequestId changed from $requestId to $activeTtsRequestId, abandoning playback")
                    return@launch
                }
                val activePlayer = player
                if (activePlayer == null) {
                    Log.e(TAG, "[TTS_DEBUG] LiteRTVoiceManager: no audio was generated for $requestId")
                    activeTtsRequestId = null
                    eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "No audio generated"))
                    return@launch
                }
                while (ttsPaused.get() && activeTtsRequestId == requestId) {
                    delay(20)
                }
                if (activeTtsRequestId != requestId) return@launch
                Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: awaiting drained player audio...")
                activePlayer.awaitDrained()
                activePlayer.stopPlayback()

                if (activeTtsRequestId != requestId) return@launch
                activeTtsRequestId = null
                Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: playback completed for $requestId")
                eventEmitter("onTtsCompleted", mapOf("requestId" to requestId))
                eventEmitter("onResponseDone", mapOf("requestId" to requestId))
            } catch (e: Exception) {
                if (e is CancellationException) {
                    Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: speakJob cancelled via coroutine exception")
                    return@launch
                }
                Log.e(TAG, "[TTS_DEBUG] TTS speak error for $requestId", e)
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
                    Log.d(TAG, "[TTS_DEBUG] LiteRTVoiceManager: no active TTS, releasing TTS engine")
                    bridge.releaseActiveTts()
                }
                onDone?.invoke()
            }
        }
    }

    private fun synthesize(
        piece: String,
        selection: LiteRTModuleBridge.ActiveTts,
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