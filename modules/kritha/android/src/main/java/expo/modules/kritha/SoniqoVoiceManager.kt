package expo.modules.kritha

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
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
import expo.modules.kritha.platform.LiteRTEngineManager
import expo.modules.kritha.platform.LocalLlmExecutor
import expo.modules.kritha.platform.LocalLlmMessage
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.cancellation.CancellationException

internal class SoniqoVoiceManager(
    private val context: Context,
    private val llmExecutor: LocalLlmExecutor,
    private val eventEmitter: (String, Map<String, Any?>) -> Unit
) {
    private var pipeline: SpeechPipeline? = null
    private var audioRecord: AudioRecord? = null
    private var speechPlayer: StreamingPcmPlayer? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isRecording = AtomicBoolean(false)
    private var micJob: Job? = null
    private var eventJob: Job? = null
    private var llmJob: Job? = null
    
    private val isEmulator = Build.FINGERPRINT.contains("generic")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("sdk")
            || Build.HARDWARE.contains("ranchu")

    // Pure LiteRT runtime configuration:
    private val sttBackend = SttBackend.LITERT
    private val sttModel = SttModel.NEMOTRON_MULTILINGUAL
    private val ttsModel = TtsModel.SUPERTONIC

    companion object {
        private const val TAG = "SoniqoVoiceManager"
    }

    suspend fun initialize(
        modelPath: String?,
        sttModelId: String? = null,
        ttsModelId: String? = null
    ): Unit = withContext(Dispatchers.IO) {
        try {
            val precision = if (sttModelId?.contains("fp16") == true) ModelPrecision.FP32 else ModelPrecision.INT8

            if (!ModelManager.areModelsReady(context, precision, sttModel, sttBackend, ttsModel)) {
                Log.w(TAG, "LiteRT models not ready. Automatic background download disabled. User must download via UI.")
                return@withContext
            }

            val modelDir = ModelManager.modelDir(context, precision, sttModel, sttBackend, ttsModel)

            val config = SpeechConfig(
                modelDir = modelDir,
                useNnapi = !isEmulator,
                sttModel = sttModel,
                sttBackend = sttBackend,
                ttsModel = ttsModel,
                pipelineMode = PipelineMode.TRANSCRIBE_ONLY,
                language = "en",
                enableEnhancer = false,
                precision = precision,
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

            Log.i(TAG, "Soniqo LiteRT SpeechPipeline initialized successfully in $modelDir")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize Soniqo LiteRT SpeechPipeline", e)
            eventEmitter("onError", mapOf("message" to (e.message ?: "Failed to initialize voice pipeline")))
        }
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

        val sampleRate = 16000
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT) * 2
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        audioRecord?.startRecording()

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
                        eventEmitter("onTranscript", mapOf("text" to event.text, "isFinal" to false))
                    }
                    is SpeechEvent.TranscriptionCompleted -> {
                        val text = event.text.trim()
                        eventEmitter("onTranscript", mapOf("text" to text, "isFinal" to true))
                        if (text.isNotEmpty() && llmModelPath != null) {
                            handleTranscription(text, llmModelPath, llmDevice)
                        } else {
                            p.resumeListening()
                        }
                    }
                    is SpeechEvent.Error -> {
                        Log.e(TAG, "SpeechEvent.Error: ${event.message}")
                        eventEmitter("onError", mapOf("message" to event.message))
                    }
                    else -> {}
                }
            }
        }
    }

    private fun handleTranscription(text: String, llmModelPath: String, llmDevice: String) {
        val p = pipeline ?: return
        eventEmitter("onResponseCreated", mapOf("text" to ""))
        
        val device = if (llmDevice.lowercase() == "gpu") LiteRTEngineManager.Device.GPU else LiteRTEngineManager.Device.CPU
        llmJob?.cancel()
        llmJob = scope.launch {
            try {
                val player = speechPlayer ?: StreamingPcmPlayer(p.ttsSampleRate).also { speechPlayer = it }
                var playerStarted = false
                val voice = "F1" // Supertonic LiteRT voice style

                llmExecutor.generateLocal(
                    requestId = "voice",
                    modelPath = llmModelPath,
                    device = device,
                    messages = listOf(LocalLlmMessage("user", text)),
                    onDelta = { chunk ->
                        eventEmitter("onResponseCreated", mapOf("text" to chunk))
                        val pieces = SpeechChunks.split(chunk)
                        for (piece in pieces) {
                            if (piece.isBlank()) continue
                            p.synthesizeStreaming(piece, "en", voice) { result, _ ->
                                val pcm = result.pcm16
                                if (pcm.isNotEmpty()) {
                                    if (!playerStarted) {
                                        player.start(pcm)
                                        playerStarted = true
                                    } else {
                                        player.write(pcm)
                                    }
                                }
                                Unit
                            }
                        }
                    }
                )
                if (playerStarted) {
                    player.awaitDrained()
                    player.resetForNextUtterance()
                }
                eventEmitter("onResponseDone", emptyMap())
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    Log.e(TAG, "Generation/Synthesis error", e)
                    eventEmitter("onError", mapOf("message" to (e.message ?: "Voice turn error")))
                }
            } finally {
                p.resumeListening()
            }
        }
    }

    private var speakJob: Job? = null

    fun speak(text: String, voice: String = "F1", onDone: (() -> Unit)? = null) {
        speakJob?.cancel()
        speakJob = scope.launch {
            try {
                if (pipeline == null) {
                    val precision = ModelPrecision.INT8
                    if (!ModelManager.areModelsReady(context, precision, sttModel, sttBackend, ttsModel)) {
                        Log.w(TAG, "Cannot speak: voice models not downloaded by user.")
                        onDone?.invoke()
                        return@launch
                    }
                    initialize(null)
                }
                val p = pipeline ?: run {
                    Log.e(TAG, "Cannot speak: SpeechPipeline is not initialized")
                    onDone?.invoke()
                    return@launch
                }

                val player = speechPlayer ?: StreamingPcmPlayer(p.ttsSampleRate).also { speechPlayer = it }
                var playerStarted = false
                val pieces = SpeechChunks.split(text)
                for (piece in pieces) {
                    if (piece.isBlank()) continue
                    p.synthesizeStreaming(piece, "en", voice) { result, _ ->
                        val pcm = result.pcm16
                        if (pcm.isNotEmpty()) {
                            if (!playerStarted) {
                                player.start(pcm)
                                playerStarted = true
                            } else {
                                player.write(pcm)
                            }
                        }
                    }
                }
                if (playerStarted) {
                    player.awaitDrained()
                    player.stopPlayback()
                }
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    Log.e(TAG, "Standalone speak error", e)
                    eventEmitter("onError", mapOf("message" to (e.message ?: "TTS error")))
                }
            } finally {
                eventEmitter("onResponseDone", emptyMap())
                onDone?.invoke()
            }
        }
    }

    fun stopSpeaking() {
        speakJob?.cancel()
        try {
            speechPlayer?.stopPlayback()
        } catch (_: Exception) {}
        eventEmitter("onResponseDone", emptyMap())
    }

    fun stop() {
        if (!isRecording.getAndSet(false)) return
        micJob?.cancel()
        eventJob?.cancel()
        llmJob?.cancel()
        speakJob?.cancel()

        llmExecutor.cancelProcess("voice")

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
    }
}
