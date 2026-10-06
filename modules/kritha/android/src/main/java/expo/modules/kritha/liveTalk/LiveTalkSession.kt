package expo.modules.kritha.liveTalk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import expo.modules.kritha.SpeechModelBridge
import expo.modules.kritha.TtsModuleBridge
import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.RuntimeManager
import expo.modules.kritha.runtime.asr.AsrProvider
import expo.modules.kritha.runtime.vad.VadProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread
import kotlin.math.sqrt

/**
 * Owns the full real-time Live Talk loop for one session (spec §1–2, §7):
 * capture → AEC → VAD → turn detection → ASR → intelligence → TTS → playback,
 * with barge-in. Single-use: create a new instance per session.
 *
 * All session output flows through [emit] as semantic events; no PCM leaves
 * the native layer.
 */
class LiveTalkSession(
    private val context: Context,
    private val runtimeManager: RuntimeManager,
    private val ttsBridge: TtsModuleBridge,
    private val speechModels: SpeechModelBridge,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    data class SessionConfig(
        val intelligence: IntelligenceConfig,
        val context: List<IntelligenceMessage>,
        val ttsEnabled: Boolean,
        val ttsMode: LiveTalkTtsMode,
        val ttsVoice: String,
        val sttModelId: String,
        val vadConfig: LiveTalkConfig,
    )

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private val running = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)

    private val stateLock = Any()

    @Volatile
    private var state: LiveTalkState = LiveTalkState.IDLE

    @Volatile
    private var captureThread: Thread? = null

    @Volatile
    private var recorder: AudioRecord? = null

    @Volatile
    private var audioProcessor: AudioProcessor? = null

    @Volatile
    private var vad: VadProvider? = null

    @Volatile
    private var asr: AsrProvider? = null

    @Volatile
    private var intelligence: IntelligenceProvider? = null

    @Volatile
    private var ttsManager: LiveTalkTtsManager? = null

    @Volatile
    private var turnJob: Job? = null

    private val turnCounter = AtomicLong(0)

    @Volatile
    private var activeTurnId: String? = null

    private val conversation = mutableListOf<IntelligenceMessage>()

    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null

    private var speechEndAtMs = 0L
    private var asrDoneAtMs = 0L
    private var firstDeltaAtMs = 0L
    private var interruptAtMs = 0L

    @Volatile
    private var lastLevelEmitAtMs = 0L

    val isActive: Boolean
        get() = running.get()

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    @Synchronized
    fun start(config: SessionConfig) {
        check(!running.get()) { "LiveTalkSession already started" }
        sessionConfig = config

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw LiveTalkException(
                LiveTalkException.ERR_MIC_PERMISSION,
                "Microphone permission is not granted",
            )
        }

        val onnx = runtimeManager.provider(RuntimeId.ONNX)
            ?: throw LiveTalkException(
                LiveTalkException.ERR_RUNTIME_MISSING,
                "ONNX runtime is not installed",
            )
        val vadProvider = onnx.vad()
            ?: throw LiveTalkException(LiveTalkException.ERR_VAD, "Runtime exposes no VAD capability")
        val asrProvider = onnx.asr()
            ?: throw LiveTalkException(LiveTalkException.ERR_ASR, "Runtime exposes no ASR capability")

        try {
            vadProvider.load(speechModels.vadModelFile().absolutePath)
        } catch (e: LiveTalkException) {
            throw e
        } catch (e: Exception) {
            throw LiveTalkException(LiveTalkException.ERR_VAD, e.message ?: "VAD load failed")
        }
        try {
            asrProvider.load(speechModels.sttModelDirectory(config.sttModelId).absolutePath)
        } catch (e: LiveTalkException) {
            vadProvider.release()
            throw e
        } catch (e: Exception) {
            vadProvider.release()
            throw LiveTalkException(LiveTalkException.ERR_ASR, e.message ?: "ASR load failed")
        }
        vad = vadProvider
        asr = asrProvider

        intelligence = IntelligenceProviders.create(config.intelligence, runtimeManager)
        synchronized(conversation) {
            conversation.clear()
            conversation.addAll(config.context)
        }

        if (config.ttsEnabled && config.ttsMode != LiveTalkTtsMode.DISABLED) {
            ttsManager = LiveTalkTtsManager(ttsBridge, config.ttsVoice).apply {
                callback = ttsCallback
            }
        }

        val record = createAudioRecord(config.vadConfig)
        recorder = record

        val processor = selectProcessor(config.vadConfig.forceWebRtcApm)
        processor.start(record.audioSessionId)
        audioProcessor = processor
        val aecBackend = when (processor) {
            is WebRtcAudioProcessor -> "webrtc"
            is AndroidAudioProcessor -> if (processor.isAecActive) "android" else "none"
            else -> "none"
        }

        requestAudioFocus()

        record.startRecording()
        running.set(true)
        paused.set(false)
        setState(LiveTalkState.LISTENING)
        emit(
            mapOf(
                "type" to "session_started",
                "aec" to aecBackend,
                "ttsMode" to config.ttsMode.wire,
            ),
        )

        captureThread = thread(name = "KrithaLiveTalkCapture", isDaemon = true) {
            runCaptureLoop(record, config.vadConfig)
        }
    }

    @Synchronized
    fun stop() {
        if (!running.getAndSet(false)) return
        paused.set(false)

        val turnId = activeTurnId
        activeTurnId = null
        turnJob?.cancel()
        turnJob = null
        if (turnId != null) intelligence?.cancel(turnId)
        ttsManager?.stop()

        captureThread?.join(2_000)
        captureThread = null

        runCatching { recorder?.stop() }
        runCatching { recorder?.release() }
        recorder = null

        audioProcessor?.stop()
        audioProcessor = null

        runCatching { vad?.release() }
        vad = null
        runCatching { asr?.release() }
        asr = null

        intelligence?.close()
        intelligence = null
        ttsManager = null

        abandonAudioFocus()

        setState(LiveTalkState.IDLE)
        emit(mapOf("type" to "session_stopped"))
        scope.cancel()
    }

    /** Manual barge-in (spec §15 `interrupt()`): stop speaking, keep listening. */
    fun interrupt() {
        if (!running.get()) return
        if (state != LiveTalkState.SPEAKING && state != LiveTalkState.THINKING) return
        interruptActiveTurn()
        setState(LiveTalkState.LISTENING)
    }

    fun pause() {
        if (!running.get()) return
        if (state == LiveTalkState.SPEAKING || state == LiveTalkState.THINKING) {
            interruptActiveTurn()
        }
        paused.set(true)
        setState(LiveTalkState.PAUSED)
    }

    fun resume() {
        if (!running.get() || !paused.getAndSet(false)) return
        vad?.reset()
        setState(LiveTalkState.LISTENING)
    }

    /** Replace the working conversation context between turns (JS is canonical). */
    fun setContext(messages: List<IntelligenceMessage>) {
        synchronized(conversation) {
            conversation.clear()
            conversation.addAll(messages)
        }
    }

    // ------------------------------------------------------------------
    // Capture loop (dedicated thread; never touches JS)
    // ------------------------------------------------------------------

    private fun runCaptureLoop(record: AudioRecord, config: LiveTalkConfig) {
        val frameSize = config.vadFrameSize
        val frame = ShortArray(frameSize)
        val turnDetector = TurnDetector(config)
        val preRoll = ArrayDeque<ShortArray>()
        val utterance = PcmBuffer(config.sampleRate * 5)
        val minSpeechFrames = MIN_UTTERANCE_MS * config.sampleRate / 1_000 / frameSize
        val vadWindow = ShortArray(LiveTalkConfig.VAD_WINDOW_SAMPLES)
        var vadWindowFill = 0
        var bargeInStreak = 0

        try {
            while (running.get()) {
                if (!readFully(record, frame)) continue
                if (paused.get()) {
                    turnDetector.reset()
                    utterance.clear()
                    preRoll.clear()
                    vadWindowFill = 0
                    continue
                }

                val processed = audioProcessor?.process(frame) ?: frame
                emitAudioLevelThrottled(processed)

                var probability: Float? = null
                var consumed = 0
                while (consumed < processed.size) {
                    val take = minOf(
                        LiveTalkConfig.VAD_WINDOW_SAMPLES - vadWindowFill,
                        processed.size - consumed,
                    )
                    System.arraycopy(processed, consumed, vadWindow, vadWindowFill, take)
                    vadWindowFill += take
                    consumed += take
                    if (vadWindowFill < LiveTalkConfig.VAD_WINDOW_SAMPLES) break
                    vadWindowFill = 0
                    probability = try {
                        vad?.speechProbability(vadWindow.copyOf())
                    } catch (e: Exception) {
                        Log.e(TAG, "VAD failure", e)
                        emitError(LiveTalkException.ERR_VAD, e.message ?: "VAD failed")
                        break
                    }
                }
                val frameProbability = probability ?: 0f

                // Echo guard: during assistant playback/think states, only a
                // sustained run of confident speech frames counts as barge-in.
                val assistantActive = state == LiveTalkState.SPEAKING ||
                    state == LiveTalkState.THINKING ||
                    state == LiveTalkState.PROCESSING
                val effectiveProbability = if (assistantActive) {
                    bargeInStreak = if (frameProbability >= config.bargeInSpeechThreshold) {
                        bargeInStreak + 1
                    } else {
                        0
                    }
                    if (bargeInStreak >= config.bargeInConfirmFrames) frameProbability else 0f
                } else {
                    bargeInStreak = 0
                    frameProbability
                }

                when (turnDetector.accept(effectiveProbability)) {
                    TurnDetector.Signal.SPEECH_START -> {
                        if (state == LiveTalkState.SPEAKING ||
                            state == LiveTalkState.THINKING ||
                            state == LiveTalkState.PROCESSING
                        ) {
                            interruptActiveTurn()
                        }
                        setState(LiveTalkState.USER_SPEAKING)
                        emit(mapOf("type" to "speech_started"))
                        utterance.clear()
                        for (prev in preRoll) utterance.append(prev)
                        utterance.append(processed)
                    }

                    TurnDetector.Signal.SPEECH_END -> {
                        utterance.append(processed)
                        if (turnDetector.endedSpeechFrames >= minSpeechFrames) {
                            endUtterance(utterance.toArray())
                        } else {
                            setState(LiveTalkState.LISTENING)
                        }
                        utterance.clear()
                    }

                    TurnDetector.Signal.NONE -> {
                        if (state == LiveTalkState.USER_SPEAKING) {
                            utterance.append(processed)
                            if (turnDetector.speechFrames >= turnDetector.maxSpeechFrames) {
                                turnDetector.reset()
                                endUtterance(utterance.toArray())
                                utterance.clear()
                            }
                        }
                    }
                }

                if (state != LiveTalkState.USER_SPEAKING) {
                    preRoll.addLast(processed.copyOf())
                    while (preRoll.size > PRE_ROLL_FRAMES) preRoll.removeFirst()
                } else {
                    preRoll.clear()
                }
            }
        } finally {
            Log.d(TAG, "Capture loop exited")
        }
    }

    private fun readFully(record: AudioRecord, frame: ShortArray): Boolean {
        var offset = 0
        while (offset < frame.size && running.get()) {
            val read = record.read(frame, offset, frame.size - offset)
            if (read <= 0) return false
            offset += read
        }
        return offset == frame.size
    }

    // ------------------------------------------------------------------
    // Turn pipeline (coroutine per utterance)
    // ------------------------------------------------------------------

    private fun endUtterance(pcm: ShortArray) {
        speechEndAtMs = SystemClock.elapsedRealtime()
        setState(LiveTalkState.PROCESSING)
        emit(mapOf("type" to "speech_ended"))

        val turnId = "turn-${turnCounter.incrementAndGet()}"
        activeTurnId = turnId
        turnJob = scope.launch { runTurn(turnId, pcm) }
    }

    private suspend fun runTurn(turnId: String, pcm: ShortArray) {
        try {
            emit(mapOf("type" to "transcription_started", "turnId" to turnId))
            val transcript = withContext(Dispatchers.IO) {
                asr?.transcribe(pcm, SAMPLE_RATE).orEmpty()
            }.trim()
            asrDoneAtMs = SystemClock.elapsedRealtime()
            emitLatency("speech_end_to_asr_ms", speechEndAtMs, asrDoneAtMs)
            emit(
                mapOf(
                    "type" to "transcription_completed",
                    "turnId" to turnId,
                    "text" to transcript,
                ),
            )
            if (transcript.isEmpty() || !isCurrentTurn(turnId)) {
                if (isCurrentTurn(turnId)) setState(LiveTalkState.LISTENING)
                return
            }

            appendConversation(IntelligenceMessage("user", transcript))
            setState(LiveTalkState.THINKING)
            emit(mapOf("type" to "thinking_started", "turnId" to turnId))

            firstDeltaAtMs = 0L
            val tts = ttsManager
            val streamSink = if (tts != null && ttsMode() == LiveTalkTtsMode.STREAM) {
                tts.speakStream()
            } else {
                null
            }

            val fullText = try {
                intelligence?.generate(turnId, conversationSnapshot()) { delta ->
                    if (!isCurrentTurn(turnId)) return@generate
                    if (firstDeltaAtMs == 0L) {
                        firstDeltaAtMs = SystemClock.elapsedRealtime()
                        emitLatency("asr_to_first_llm_ms", asrDoneAtMs, firstDeltaAtMs)
                    }
                    emit(mapOf("type" to "assistant_text", "turnId" to turnId, "delta" to delta))
                    streamSink?.append(delta)
                }.orEmpty()
            } finally {
                streamSink?.finish()
            }

            if (!isCurrentTurn(turnId)) return
            appendConversation(IntelligenceMessage("assistant", fullText))
            emit(
                mapOf(
                    "type" to "thinking_completed",
                    "turnId" to turnId,
                    "text" to fullText,
                ),
            )

            if (tts != null) {
                when (ttsMode()) {
                    LiveTalkTtsMode.STREAM -> streamSink?.awaitPlayback()
                    LiveTalkTtsMode.AFTER_GENERATION -> {
                        setState(LiveTalkState.SPEAKING)
                        tts.speakFull(fullText)
                    }
                    LiveTalkTtsMode.DISABLED -> Unit
                }
            }

            if (isCurrentTurn(turnId)) setState(LiveTalkState.LISTENING)
        } catch (e: CancellationException) {
            // Interrupted; the barge-in path owns the state transition.
        } catch (e: LiveTalkException) {
            emitError(e.code, e.message ?: "Live Talk error")
            if (isCurrentTurn(turnId)) setState(LiveTalkState.LISTENING)
        } catch (e: Exception) {
            Log.e(TAG, "Turn failed", e)
            emitError(LiveTalkException.ERR_INTELLIGENCE, e.message ?: "Turn failed")
            if (isCurrentTurn(turnId)) setState(LiveTalkState.LISTENING)
        }
    }

    private val ttsCallback = object : LiveTalkTtsManager.Callback {
        override fun onTtsStarted() {
            val turnId = activeTurnId ?: return
            emit(mapOf("type" to "tts_started", "turnId" to turnId))
        }

        override fun onFirstAudio() {
            if (firstDeltaAtMs != 0L) {
                emitLatency("first_llm_to_first_audio_ms", firstDeltaAtMs, SystemClock.elapsedRealtime())
            }
            if (state == LiveTalkState.THINKING) setState(LiveTalkState.SPEAKING)
        }

        override fun onTtsFinished(interrupted: Boolean) {
            val turnId = activeTurnId
            emit(
                mapOf(
                    "type" to "tts_stopped",
                    "turnId" to turnId,
                    "interrupted" to interrupted,
                ),
            )
            if (!interrupted && state == LiveTalkState.SPEAKING) {
                setState(LiveTalkState.LISTENING)
            }
        }
    }

    // ------------------------------------------------------------------
    // Barge-in
    // ------------------------------------------------------------------

    private fun interruptActiveTurn() {
        val turnId = activeTurnId ?: return
        interruptAtMs = SystemClock.elapsedRealtime()
        activeTurnId = null
        turnJob?.cancel()
        turnJob = null
        intelligence?.cancel(turnId)
        ttsManager?.interrupt()
        emitLatency("interrupt_to_audio_stop_ms", interruptAtMs, SystemClock.elapsedRealtime())
        setState(LiveTalkState.INTERRUPTED)
        emit(mapOf("type" to "interrupted", "turnId" to turnId))
    }

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    @Volatile
    private var sessionConfig: SessionConfig? = null

    private fun ttsMode(): LiveTalkTtsMode =
        sessionConfig?.let { if (it.ttsEnabled) it.ttsMode else LiveTalkTtsMode.DISABLED }
            ?: LiveTalkTtsMode.DISABLED

    private fun isCurrentTurn(turnId: String): Boolean =
        running.get() && activeTurnId == turnId

    private fun conversationSnapshot(): List<IntelligenceMessage> =
        synchronized(conversation) { conversation.toList() }

    private fun appendConversation(message: IntelligenceMessage) {
        synchronized(conversation) { conversation.add(message) }
    }

    private fun setState(next: LiveTalkState) {
        val changed = synchronized(stateLock) {
            if (state == next) false else {
                state = next
                true
            }
        }
        if (changed) {
            emit(mapOf("type" to "state", "state" to next.wire))
        }
    }

    private fun emitError(code: String, message: String) {
        emit(mapOf("type" to "error", "code" to code, "message" to message))
    }

    private fun emitLatency(metric: String, fromMs: Long, toMs: Long) {
        if (fromMs <= 0L || toMs < fromMs) return
        emit(mapOf("type" to "latency", "metric" to metric, "ms" to (toMs - fromMs)))
    }

    private fun emitAudioLevelThrottled(frame: ShortArray) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastLevelEmitAtMs < LEVEL_EMIT_INTERVAL_MS) return
        lastLevelEmitAtMs = now
        var sum = 0.0
        for (sample in frame) {
            val normalized = sample / 32768.0
            sum += normalized * normalized
        }
        val rms = sqrt(sum / frame.size)
        emit(mapOf("type" to "audio_level", "level" to rms.coerceIn(0.0, 1.0)))
    }

    private fun createAudioRecord(config: LiveTalkConfig): AudioRecord {
        val minBuf = AudioRecord.getMinBufferSize(
            config.sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) {
            throw LiveTalkException(
                LiveTalkException.ERR_AUDIO_INIT,
                "Unsupported capture config (minBuffer=$minBuf)",
            )
        }
        val bufferSize = maxOf(minBuf, config.vadFrameSize * BYTES_PER_SAMPLE * 8)
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                config.sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )
        } catch (e: Exception) {
            throw LiveTalkException(
                LiveTalkException.ERR_AUDIO_INIT,
                e.message ?: "AudioRecord creation failed",
            )
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw LiveTalkException(
                LiveTalkException.ERR_AUDIO_INIT,
                "AudioRecord failed to initialize",
            )
        }
        return record
    }

    private fun selectProcessor(forceWebRtc: Boolean): AudioProcessor {
        if (forceWebRtc && WebRtcAudioProcessor.isAvailable) {
            return WebRtcAudioProcessor()
        }
        if (AecDetector.isHardwareAecAvailable()) {
            return AndroidAudioProcessor()
        }
        if (WebRtcAudioProcessor.isAvailable) {
            return WebRtcAudioProcessor()
        }
        if (forceWebRtc) {
            emitError(
                LiveTalkException.ERR_WEBRTC_INIT,
                "WebRTC APM requested but unavailable; capturing without software AEC",
            )
        } else {
            emitError(
                LiveTalkException.ERR_AEC_UNAVAILABLE,
                "No AEC backend available; capturing without echo cancellation",
            )
        }
        return AndroidAudioProcessor()
    }

    private fun requestAudioFocus() {
        val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager = manager
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setOnAudioFocusChangeListener { change ->
                when (change) {
                    AudioManager.AUDIOFOCUS_LOSS -> {
                        emitError(LiveTalkException.ERR_AUDIO_FOCUS, "Audio focus lost")
                        stop()
                    }
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
                    -> interrupt()
                }
            }
            .build()
        focusRequest = request
        val result = manager.requestAudioFocus(request)
        if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.w(TAG, "Audio focus request denied ($result); continuing without focus")
        }
    }

    private fun abandonAudioFocus() {
        val request = focusRequest ?: return
        focusRequest = null
        runCatching { audioManager?.abandonAudioFocusRequest(request) }
        audioManager = null
    }

    private class PcmBuffer(initialCapacity: Int) {
        private var data = ShortArray(initialCapacity)
        var size = 0
            private set

        fun append(frame: ShortArray) {
            ensure(size + frame.size)
            System.arraycopy(frame, 0, data, size, frame.size)
            size += frame.size
        }

        fun toArray(): ShortArray = data.copyOf(size)

        fun clear() {
            size = 0
        }

        private fun ensure(capacity: Int) {
            if (capacity <= data.size) return
            var next = data.size
            while (next < capacity) next *= 2
            data = data.copyOf(next)
        }
    }

    companion object {
        private const val TAG = "LiveTalkSession"
        private const val SAMPLE_RATE = 16_000
        private const val BYTES_PER_SAMPLE = 2
        private const val PRE_ROLL_FRAMES = 10
        private const val MIN_UTTERANCE_MS = 250
        private const val LEVEL_EMIT_INTERVAL_MS = 100L
    }
}
