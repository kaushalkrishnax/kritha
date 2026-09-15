package expo.modules.kritha

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import android.util.Log
import audio.soniqo.speech.ModelManager
import audio.soniqo.speech.ModelPrecision
import audio.soniqo.speech.PipelineMode
import audio.soniqo.speech.SpeechConfig
import audio.soniqo.speech.SpeechEvent
import audio.soniqo.speech.SpeechPipeline
import audio.soniqo.speech.SttBackend
import audio.soniqo.speech.SttModel
import audio.soniqo.speech.TtsModel
import expo.modules.kritha.platform.LocalLlmExecutor
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.cancellation.CancellationException
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Native Soniqo execution owner.
 */
internal class SoniqoVoiceManager(
    private val context: Context,
    @Suppress("unused") private val llmExecutor: LocalLlmExecutor,
    private val eventEmitter: (String, Map<String, Any?>) -> Unit
) {
    private var pipeline: SpeechPipeline? = null
    private var audioRecord: AudioRecord? = null
    private var speechPlayer: StreamingPcmPlayer? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isRecording = AtomicBoolean(false)
    private var micJob: Job? = null
    private var eventJob: Job? = null

    private val isEmulator = Build.FINGERPRINT.contains("generic")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("sdk")
            || Build.HARDWARE.contains("ranchu")

    companion object {
        private const val TAG = "SoniqoVoiceManager"
        private const val STOP_TRANSCRIPT_TIMEOUT_MS = 10_000L
        private const val AUDIO_LEVEL_EMIT_INTERVAL_MS = 80L
    }

    private var activeSttRequestId: String? = null
    private val sttFinalSegments = mutableListOf<String>()
    private var sttLastPartial: String = ""
    private var sttFinalizing = false
    private var sttFinalDeferred: CompletableDeferred<Unit>? = null
    private var lastLevelEmitMs: Long = 0L

    /**
     * Real microphone level for waveform visualization
     */
    private fun micLevel(samples: FloatArray, count: Int): Float {
        if (count <= 0) return 0f
        var sum = 0.0
        for (i in 0 until count) {
            val s = samples[i].toDouble()
            sum += s * s
        }
        val rms = sqrt(sum / count)
        if (rms <= 0.0) return 0f
        val db = 20.0 * log10(rms)
        return ((db + 50.0) / 50.0).toFloat().coerceIn(0f, 1f)
    }

    private fun emitAudioLevel(samples: FloatArray, count: Int) {
        val requestId = activeSttRequestId ?: return
        val now = SystemClock.elapsedRealtime()
        if (now - lastLevelEmitMs < AUDIO_LEVEL_EMIT_INTERVAL_MS) return
        lastLevelEmitMs = now
        eventEmitter("onAudioLevel", mapOf("requestId" to requestId, "level" to micLevel(samples, count)))
    }

    private var speakJob: Job? = null
    private var activeTtsRequestId: String? = null
    private val ttsPaused = AtomicBoolean(false)

    private data class ResolvedSpeechModels(
        val precision: ModelPrecision,
        val sttModel: SttModel,
        val sttBackend: SttBackend,
        val ttsModel: TtsModel
    )

    private fun resolveSpeechModels(sttModelId: String?, ttsModelId: String?): ResolvedSpeechModels {
        val precision = if (sttModelId?.contains("fp16") == true) ModelPrecision.FP32 else ModelPrecision.INT8
        if (sttModelId != null && sttModelId != "nemotron-multilingual-int8" && sttModelId != "nemotron-multilingual-fp16") {
            Log.w(TAG, "Unknown STT model id '$sttModelId'; using Nemotron Multilingual default. JS catalog is source of truth.")
        }
        val ttsModel = TtsModel.SUPERTONIC
        if (ttsModelId != null && ttsModelId != "supertonic-litert") {
            Log.w(TAG, "Unknown TTS model id '$ttsModelId'; using Supertonic default. JS catalog is source of truth.")
        }
        return ResolvedSpeechModels(precision, SttModel.NEMOTRON_MULTILINGUAL, SttBackend.LITERT, ttsModel)
    }

    suspend fun initialize(
        modelPath: String?,
        sttModelId: String? = null,
        ttsModelId: String? = null
    ): Unit = withContext(Dispatchers.IO) {
        try {
            val resolved = resolveSpeechModels(sttModelId, ttsModelId)

            if (!ModelManager.areModelsReady(context, resolved.precision, resolved.sttModel, resolved.sttBackend, resolved.ttsModel)) {
                Log.w(TAG, "LiteRT models not ready. Automatic background download disabled. User must download via UI.")
                return@withContext
            }

            val modelDir = ModelManager.modelDir(context, resolved.precision, resolved.sttModel, resolved.sttBackend, resolved.ttsModel)

            val config = SpeechConfig(
                modelDir = modelDir,
                useNnapi = !isEmulator,
                sttModel = resolved.sttModel,
                sttBackend = resolved.sttBackend,
                ttsModel = resolved.ttsModel,
                pipelineMode = PipelineMode.TRANSCRIBE_ONLY,
                language = "en",
                enableEnhancer = false,
                precision = resolved.precision,
                emitPartialTranscriptions = true,
                partialTranscriptionInterval = 0.5f,
                languageHints = emptyList(),
                beamSize = 1,
                endOfSpeechSilenceSec = 0.8f,
                enableSmartTurn = false,
                turnCompletionThreshold = 0.8f,
                turnCompletionMaxSilenceSec = 2.0f
            )

            pipeline?.stop()
            pipeline?.close()
            val p = SpeechPipeline.Companion.invoke(config)
            pipeline = p

            val sampleRate = p.ttsSampleRate
            speechPlayer?.close()
            speechPlayer = StreamingPcmPlayer(sampleRate)

            ensureEventCollection(p)
            Log.i(TAG, "Soniqo LiteRT SpeechPipeline initialized successfully in $modelDir")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize Soniqo LiteRT SpeechPipeline", e)
            eventEmitter("onError", mapOf("message" to (e.message ?: "Failed to initialize voice pipeline")))
        }
    }

    /**
     * Start real microphone capture for one dictation operation.
     */
    @SuppressLint("MissingPermission")
    suspend fun startListening(requestId: String): Unit = withContext(Dispatchers.IO) {
        if (isRecording.get()) {
            throw IllegalStateException("STT capture already active")
        }
        val p = pipeline ?: throw IllegalStateException(
            "Speech pipeline is not initialized. Download the voice models first."
        )

        sttFinalSegments.clear()
        sttLastPartial = ""
        sttFinalizing = false
        sttFinalDeferred = null

        ensureEventCollection(p)
        try {
            p.start()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to start pipeline", e)
            throw IllegalStateException("Failed to start speech pipeline: ${e.message}")
        }

        val sampleRate = 16000
        val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuffer <= 0) {
            throw IllegalStateException("Microphone unavailable on this device")
        }
        val bufferSize = minBuffer * 2
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("Microphone unavailable on this device")
        }
        audioRecord = record

        try {
            record.startRecording()
        } catch (e: Throwable) {
            record.release()
            audioRecord = null
            throw IllegalStateException("Microphone unavailable on this device: ${e.message}")
        }
        isRecording.set(true)
        activeSttRequestId = requestId
        lastLevelEmitMs = 0L

        micJob?.cancel()
        micJob = scope.launch {
            val buffer = ShortArray(bufferSize / 2)
            val floatBuffer = FloatArray(bufferSize / 2)
            while (isActive && isRecording.get()) {
                val read = try {
                    audioRecord?.read(buffer, 0, buffer.size) ?: 0
                } catch (_: Throwable) { 0 }
                if (read > 0) {
                    for (i in 0 until read) {
                        floatBuffer[i] = buffer[i] / 32768.0f
                    }
                    try {
                        pipeline?.pushAudio(floatBuffer.copyOf(read))
                    } catch (e: Throwable) {
                        Log.e(TAG, "pushAudio failed", e)
                    }
                    emitAudioLevel(floatBuffer, read)
                }
            }
        }

        eventEmitter("onSttStarted", mapOf("requestId" to requestId))
    }

    /**
     * Stop capture and wait for the real final transcription of [requestId].
     */
    suspend fun stopListening(requestId: String): String = withContext(Dispatchers.IO) {
        val active = activeSttRequestId
        if (active != null && active != requestId) {
            throw IllegalStateException("No active STT operation for request $requestId")
        }
        stopMicrophoneOnly()

        sttFinalizing = true
        val deferred = CompletableDeferred<Unit>()
        sttFinalDeferred = deferred

        if (sttFinalSegments.isNotEmpty()) {
            deferred.complete(Unit)
        }
        try {
            withTimeout(STOP_TRANSCRIPT_TIMEOUT_MS) { deferred.await() }
        } catch (_: TimeoutCancellationException) {
            Log.w(TAG, "Timed out waiting for final transcription for $requestId")
        } finally {
            sttFinalizing = false
            sttFinalDeferred = null
        }

        val text = sttFinalSegments.joinToString(" ").trim()
        val result = if (text.isNotEmpty()) text else sttLastPartial.trim()
        eventEmitter("onSttStopped", mapOf("requestId" to requestId, "text" to result))
        if (activeSttRequestId == requestId) {
            activeSttRequestId = null
        }
        try {
            pipeline?.resumeListening()
        } catch (_: Throwable) {}
        result
    }

    /** Abandon the active capture without producing a transcript. */
    suspend fun cancelListening(requestId: String): Unit = withContext(Dispatchers.IO) {
        stopMicrophoneOnly()
        sttFinalizing = false
        sttFinalDeferred?.cancel()
        sttFinalDeferred = null
        sttFinalSegments.clear()
        sttLastPartial = ""
        if (activeSttRequestId == null || activeSttRequestId == requestId) {
            activeSttRequestId = null
        }
        eventEmitter("onSttCancelled", mapOf("requestId" to requestId))
        try {
            pipeline?.resumeListening()
        } catch (_: Throwable) {}
    }

    private fun stopMicrophoneOnly() {
        if (isRecording.getAndSet(false)) {
            micJob?.cancel()
            micJob = null
        }
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }

    @SuppressLint("MissingPermission")
    fun start(llmModelPath: String?, llmDevice: String) {
        if (isRecording.getAndSet(true)) return

        val p = pipeline ?: run {
            Log.e(TAG, "Cannot start: SpeechPipeline is null. Did initialize fail?")
            isRecording.set(false)
            return
        }

        try {
            p.start()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to start pipeline", e)
        }

        ensureEventCollection(p)

        val sampleRate = 16000
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT) * 2
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        try {
            audioRecord?.startRecording()
        } catch (e: Throwable) {
            Log.e(TAG, "Microphone start failed", e)
            isRecording.set(false)
            return
        }

        micJob = scope.launch {
            val buffer = ShortArray(bufferSize / 2)
            val floatBuffer = FloatArray(bufferSize / 2)
            while (isActive && isRecording.get()) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    for (i in 0 until read) {
                        floatBuffer[i] = buffer[i] / 32768.0f
                    }
                    pipeline?.pushAudio(floatBuffer.copyOf(read))
                }
            }
        }
    }

    private fun ensureEventCollection(p: SpeechPipeline) {
        if (eventJob?.isActive == true) return
        eventJob?.cancel()
        eventJob = scope.launch {
            p.events.collect { event ->
                when (event) {
                    is SpeechEvent.SpeechStarted -> {
                        eventEmitter("onSpeechStarted", emptyMap())
                    }
                    is SpeechEvent.SpeechEnded -> {
                        eventEmitter("onSpeechEnded", emptyMap())
                    }
                    is SpeechEvent.PartialTranscription -> {
                        val rid = activeSttRequestId
                        sttLastPartial = event.text
                        if (rid != null) {
                            eventEmitter("onTranscript", mapOf(
                                "requestId" to rid,
                                "text" to event.text,
                                "isFinal" to false
                            ))
                        } else {
                            eventEmitter("onTranscript", mapOf("text" to event.text, "isFinal" to false))
                        }
                    }
                    is SpeechEvent.TranscriptionCompleted -> {
                        val text = event.text.trim()
                        val rid = activeSttRequestId
                        if (text.isNotEmpty()) {
                            sttFinalSegments.add(text)
                        }
                        if (rid != null) {
                            eventEmitter("onTranscript", mapOf(
                                "requestId" to rid,
                                "text" to text,
                                "isFinal" to true
                            ))
                        } else {
                            eventEmitter("onTranscript", mapOf("text" to text, "isFinal" to true))
                        }
                        if (sttFinalizing && rid != null && text.isNotEmpty()) {
                            sttFinalDeferred?.complete(Unit)
                        }

                        try {
                            p.resumeListening()
                        } catch (_: Throwable) {}
                    }
                    is SpeechEvent.Error -> {
                        Log.e(TAG, "SpeechEvent.Error: ${event.message}")
                        val rid = activeSttRequestId
                        if (rid != null) {
                            eventEmitter("onSttError", mapOf("requestId" to rid, "message" to event.message))
                        }
                        eventEmitter("onError", mapOf("message" to event.message))
                    }
                    else -> {}
                }
            }
        }
    }

    fun speak(requestId: String, text: String, voice: String = "F1", onDone: (() -> Unit)? = null) {
        if (text.isBlank()) {
            eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "Nothing to speak"))
            onDone?.invoke()
            return
        }
        val previous = activeTtsRequestId
        if (previous != null && previous != requestId) {
            // Cancel/replace: stop playback without completing the old owner.
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
                if (pipeline == null) {
                    val resolved = resolveSpeechModels(null, null)
                    if (!ModelManager.areModelsReady(context, resolved.precision, resolved.sttModel, resolved.sttBackend, resolved.ttsModel)) {
                        Log.w(TAG, "Cannot speak: voice models not downloaded by user.")
                        if (activeTtsRequestId == requestId) {
                            eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "Voice models not downloaded"))
                        }
                        return@launch
                    }
                    initialize(null)
                }
                val p = pipeline ?: run {
                    Log.e(TAG, "Cannot speak: SpeechPipeline is not initialized")
                    if (activeTtsRequestId == requestId) {
                        eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to "Speech pipeline unavailable"))
                    }
                    return@launch
                }

                if (activeTtsRequestId != requestId) return@launch
                eventEmitter("onTtsStarted", mapOf("requestId" to requestId))
                eventEmitter("onResponseCreated", mapOf("requestId" to requestId, "text" to ""))

                val player = speechPlayer ?: StreamingPcmPlayer(p.ttsSampleRate).also { speechPlayer = it }
                var playerStarted = false
                val pieces = SpeechChunks.split(text)
                for (piece in pieces) {
                    if (!isActive || activeTtsRequestId != requestId) break

                    while (activeTtsRequestId == requestId && ttsPaused.get()) {
                        delay(20)
                    }
                    if (!isActive || activeTtsRequestId != requestId) break
                    if (piece.isBlank()) continue
                    p.synthesizeStreaming(piece, "en", voice) { result, _ ->
                        val pcm = result.pcm16
                        if (pcm.isNotEmpty() && activeTtsRequestId == requestId) {
                            if (!playerStarted) {
                                player.start(pcm)
                                playerStarted = true
                            } else {
                                player.write(pcm)
                            }
                        }
                    }
                }
                if (activeTtsRequestId != requestId) return@launch
                if (playerStarted) {
                    while (ttsPaused.get() && activeTtsRequestId == requestId) {
                        delay(20)
                    }
                    player.awaitDrained()
                    player.stopPlayback()
                }
                if (activeTtsRequestId != requestId) return@launch
                activeTtsRequestId = null
                eventEmitter("onTtsCompleted", mapOf("requestId" to requestId))
                eventEmitter("onResponseDone", mapOf("requestId" to requestId))
            } catch (e: Exception) {
                if (e is CancellationException) {
                    return@launch
                }
                Log.e(TAG, "Standalone speak error", e)
                if (activeTtsRequestId == requestId) {
                    activeTtsRequestId = null
                    eventEmitter("onTtsError", mapOf("requestId" to requestId, "message" to (e.message ?: "TTS error")))
                    eventEmitter("onError", mapOf("requestId" to requestId, "message" to (e.message ?: "TTS error")))
                }
            } finally {
                onDone?.invoke()
            }
        }
    }

    /** Hold playback at the current AudioTrack head position. */
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

    /** Continue from the position held by [pauseSpeaking]. */
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

    fun stop() {
        stopMicrophoneOnly()
        sttFinalizing = false
        sttFinalDeferred?.cancel()
        sttFinalDeferred = null
        activeSttRequestId = null

        val activeTts = activeTtsRequestId
        activeTtsRequestId = null
        ttsPaused.set(false)
        speakJob?.cancel()
        speakJob = null

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null

        try {
            speechPlayer?.close()
        } catch (_: Exception) {}
        speechPlayer = null

        try {
            pipeline?.stop()
        } catch (_: Exception) {}
        if (activeTts != null) {
            eventEmitter("onTtsStopped", mapOf("requestId" to activeTts))
        }
    }
}
