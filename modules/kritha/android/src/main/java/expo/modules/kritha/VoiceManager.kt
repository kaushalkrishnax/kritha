package expo.modules.kritha

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.os.SystemClock
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process
import android.util.Log
import androidx.core.content.ContextCompat
import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.RuntimeManager
import expo.modules.kritha.runtime.asr.AsrProvider
import expo.modules.kritha.runtime.vad.VadProvider
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
 * AudioTrack playback). STT captures PCM in [captureLoop], buffers every
 * frame (VAD only hints at early flush-on-silence), and transcribes
 * utterances through the runtime ASR provider.
 */
internal class VoiceManager(
    private val bridge: TtsModuleBridge,
    private val speechModels: SpeechModelBridge,
    private val runtimeManager: RuntimeManager,
    private val appContext: android.content.Context,
    private val eventEmitter: (String, Map<String, Any?>) -> Unit,
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var speechPlayer: StreamingPcmPlayer? = null

    private var speakJob: Job? = null
    private var activeTtsRequestId: String? = null
    private val ttsPaused = AtomicBoolean(false)

    companion object {
        private const val TAG = "VoiceManager"
        const val STT_SAMPLE_RATE = 16_000

        /** Silero analysis window; sherpa compute() requires exactly this at 16 kHz. */
        const val VAD_WINDOW_SAMPLES = 512
        const val MIC_FRAME_SAMPLES = 512
        const val FRAME_MS = 32
        const val DEFAULT_SILENCE_TIMEOUT_MS = 1000
        const val SPEECH_THRESHOLD = 0.5f
        const val SPEECH_ACTIVITY_RMS = 0.02f
        const val LEVEL_EMIT_INTERVAL_MS = 100L
        const val MAX_UTTERANCE_SAMPLES = 30 * STT_SAMPLE_RATE
        const val MIN_UTTERANCE_SAMPLES = STT_SAMPLE_RATE / 3

        private fun friendlyTtsMessage(raw: String): String {
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

    fun setSttModelId(id: String?) {
        if (id != null && id != sttModelId) {
            runCatching { asrInstance?.release() }
            asrInstance = null
        }
        sttModelId = id
    }

    @Volatile
    private var silenceTimeoutMs = DEFAULT_SILENCE_TIMEOUT_MS

    suspend fun startListening(requestId: String, silenceTimeoutMs: Int? = null): Unit = withContext(Dispatchers.IO) {
        this@VoiceManager.silenceTimeoutMs = silenceTimeoutMs ?: DEFAULT_SILENCE_TIMEOUT_MS
        if (
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.RECORD_AUDIO,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            throw IllegalStateException("Microphone permission is not granted")
        }
        if (activeSttRequestId != null) {
            throw IllegalStateException("STT capture already active")
        }

        val onnx = runtimeManager.provider(RuntimeId.ONNX)
            ?: error("ONNX runtime is not installed. Install it from Extensions & Runtimes in the sidebar.")
        if (asrInstance == null) {
            val sttId = sttModelId
            if (sttId.isNullOrBlank()) error("No STT model selected")
            val asr = onnx.asr() ?: error("ONNX runtime does not provide ASR")
            asr.load(speechModels.sttModelDirectory(sttId).absolutePath)
            asrInstance = asr
        }
        if (vadInstance == null) {
            try {
                val vad = onnx.vad() ?: error("ONNX runtime does not provide VAD")
                vad.load(speechModels.vadModelFile().absolutePath)
                vadInstance = vad
            } catch (e: Exception) {
                Log.w(TAG, "VAD failed to load; continuing without it", e)
                vadInstance = null
            }
        }
        vadInstance?.reset()

        activeSttRequestId = requestId
        sttTranscript.clear()
        sttUtterance.clear()
        sttCaptureError = null
        sawSpeech = false
        eventEmitter("onSttStarted", mapOf("requestId" to requestId))
        sttJob = scope.launch { captureLoop(requestId) }
    }

    suspend fun stopListening(requestId: String): String = withContext(Dispatchers.IO) {
        val active = activeSttRequestId
        if (active == null || active != requestId) {
            return@withContext ""
        }
        activeSttRequestId = null
        sttJob?.cancel()
        sttJob?.join()
        sttJob = null
        flushUtterance(requestId)
        val text = sttTranscript.toString().trim()
        val captureError = sttCaptureError
        sttCaptureError = null
        if (captureError != null && text.isEmpty()) {
            throw IllegalStateException(captureError)
        }
        eventEmitter("onSttStopped", mapOf("requestId" to requestId, "text" to text))
        return@withContext text
    }

    suspend fun cancelListening(requestId: String): Unit = withContext(Dispatchers.IO) {
        val active = activeSttRequestId
        if (active == null || active != requestId) return@withContext
        activeSttRequestId = null
        sttJob?.cancel()
        sttJob?.join()
        sttJob = null
        sttUtterance.clear()
        sttCaptureError = null
        eventEmitter("onSttCancelled", mapOf("requestId" to requestId))
    }

    private fun flushUtterance(requestId: String) {
        val pcm = sttUtterance.toShortArray()
        sttUtterance.clear()
        // No detected activity: buffer is room tone, skip transcription.
        if (!sawSpeech) return
        sawSpeech = false
        if (pcm.size < MIN_UTTERANCE_SAMPLES) return
        val asr = asrInstance ?: return
        try {
            val text = asr.transcribe(pcm, STT_SAMPLE_RATE)
            if (text.isNotBlank()) {
                if (sttTranscript.isNotEmpty()) sttTranscript.append(' ')
                sttTranscript.append(text.trim())
                eventEmitter(
                    "onTranscript",
                    mapOf("requestId" to requestId, "text" to text.trim(), "isFinal" to false),
                )
            }
        } catch (e: Exception) {
            eventEmitter(
                "onSttError",
                mapOf("requestId" to requestId, "message" to (e.message ?: "STT failed")),
            )
        }
    }

    private fun captureLoop(requestId: String) {
        var record: AudioRecord? = null
        var inSpeech = false
        var silenceMs = 0
        var lastLevelEmitAt = 0L
        val vadWindow = ShortArray(VAD_WINDOW_SAMPLES)
        var vadWindowFill = 0
        try {
            val minBuffer = AudioRecord.getMinBufferSize(
                STT_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBuffer <= 0) {
                error("Unsupported audio configuration for STT capture")
            }
            record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                STT_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, MIC_FRAME_SAMPLES * 4),
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                error("Microphone could not be initialized. Is it in use by another app?")
            }
            record.startRecording()
            val frame = ShortArray(MIC_FRAME_SAMPLES)
            while (activeSttRequestId == requestId) {
                val read = record.read(frame, 0, MIC_FRAME_SAMPLES)
                if (read < 0) {
                    error("Microphone read failed (code $read)")
                }
                if (read == 0) continue

                var sum = 0.0
                for (i in 0 until read) {
                    val v = frame[i] / 32768.0
                    sum += v * v
                }
                val rms = Math.sqrt(sum / read)

                val now = SystemClock.elapsedRealtime()
                if (now - lastLevelEmitAt >= LEVEL_EMIT_INTERVAL_MS) {
                    lastLevelEmitAt = now
                    val level = rms.toFloat()
                    eventEmitter(
                        "onAudioLevel",
                        mapOf("requestId" to requestId, "level" to (level * 1.8f).coerceIn(0f, 1f)),
                    )
                }

                // VAD only triggers early flush; frames are buffered regardless.
                var consumed = 0
                while (consumed < read) {
                    val take = minOf(VAD_WINDOW_SAMPLES - vadWindowFill, read - consumed)
                    System.arraycopy(frame, consumed, vadWindow, vadWindowFill, take)
                    vadWindowFill += take
                    consumed += take
                    if (vadWindowFill < VAD_WINDOW_SAMPLES) break
                    vadWindowFill = 0
                    val probability = try {
                        vadInstance?.speechProbability(vadWindow.copyOf())
                    } catch (e: Exception) {
                        Log.w(TAG, "VAD probability failed", e)
                        null
                    }
                    if (probability != null && probability >= SPEECH_THRESHOLD) {
                        inSpeech = true
                        silenceMs = 0
                    } else if (inSpeech) {
                        silenceMs += FRAME_MS
                    }
                }
                // RMS fallback marks activity when VAD is unavailable/unreliable.
                if (!sawSpeech && rms >= SPEECH_ACTIVITY_RMS) {
                    sawSpeech = true
                }

                sttUtterance.addAll(frame.take(read))

                if (sttUtterance.size >= MAX_UTTERANCE_SAMPLES ||
                    (inSpeech && silenceMs >= silenceTimeoutMs)
                ) {
                    flushUtterance(requestId)
                    inSpeech = false
                    silenceMs = 0
                }
            }
        } catch (e: Exception) {
            if (e !is CancellationException) {
                sttCaptureError = e.message ?: "STT capture failed"
                Log.e(TAG, "STT capture failed", e)
                eventEmitter(
                    "onSttError",
                    mapOf(
                        "requestId" to requestId,
                        "message" to sttCaptureError,
                        "fatal" to true,
                    ),
                )
            }
        } finally {
            runCatching { record?.stop() }
            runCatching { record?.release() }
        }
    }

    private var sttJob: Job? = null
    private var activeSttRequestId: String? = null
    private var sttModelId: String? = null
    private var sttCaptureError: String? = null
    private var sawSpeech = false
    private val sttTranscript = StringBuilder()
    private val sttUtterance = mutableListOf<Short>()
    private var vadInstance: VadProvider? = null
    private var asrInstance: AsrProvider? = null

    fun start(llmModelPath: String?, llmDevice: String) {
        Log.i(TAG, "Continuous STT is stubbed; LiteRT speech-to-text is not implemented yet.")
    }

    fun stop() {
        val activeTts = activeTtsRequestId
        activeTtsRequestId = null
        ttsPaused.set(false)
        speakJob?.cancel()
        speakJob = null
        activeSttRequestId = null
        sttJob?.cancel()
        sttJob = null

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