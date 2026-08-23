package expo.modules.kritha

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.KeyEvent
import android.util.Log
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.functions.Coroutine
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kritha.intelligence.L2LocalLLM
import expo.modules.kritha.intelligence.LiteRTEngineManager
import expo.modules.kritha.wakeword.*
import java.util.Locale
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import java.util.concurrent.CancellationException

class KrithaModule : Module() {
    private var dictationContinuation: kotlinx.coroutines.CancellableContinuation<String>? = null
    private var dictationRecognizer: SpeechRecognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun definition() = ModuleDefinition {
        Name("Kritha")

        Events("onWakeWordDetected", "onAssistantEvent", "onDownloadProgress", "onDictationVolume", "onDictationPartial")

        WakeWordEventHub.listener = { keyword, confidence ->
            mainHandler.post {
                try {
                    sendEvent("onWakeWordDetected", mapOf("keyword" to keyword, "confidence" to confidence))
                } catch (e: Exception) {
                    Log.e("KrithaModule", "Failed to send wake word event", e)
                }
            }
        }
        
        WakeWordEventHub.assistantListener = { state, transcript, response, error, chunk, rms ->
            mainHandler.post {
                try {
                    sendEvent(
                        "onAssistantEvent",
                        mapOf(
                            "state" to state,
                            "transcript" to transcript,
                            "response" to response,
                            "error" to error,
                            "chunk" to chunk,
                            "rms" to rms
                        )
                    )
                } catch (e: Exception) {
                    Log.e("KrithaModule", "Failed to send assistant event", e)
                }
            }
        }

        OnStopObserving {
            // Do nothing here — keeping the hub permanently bound ensures we never drop background events
        }

        Function("start") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.start(context)
        }

        Function("stop") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.stop(context)
        }

        Function("isRunning") {
            WakeWordForegroundService.isRunning
        }

        Function("getLocalModelDevice") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            LiteRTEngineManager.getDevice(context).name.lowercase()
        }

        Function("setLocalModelDevice") { device: String ->
            val selectedDevice = LiteRTEngineManager.Device.from(device)
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            LiteRTEngineManager.setDevice(context, selectedDevice)
            selectedDevice.name.lowercase()
        }

        Function("setCloudApiKey") { apiKey: String ->
            expo.modules.kritha.intelligence.L3CloudLLM.apiKey = apiKey
        }

        Function("stopGeneration") {
            L2LocalLLM.cancelInference()
            expo.modules.kritha.intelligence.L3CloudLLM.cancelInference()
        }

        Function("stopAssistantSession") {
            L2LocalLLM.cancelInference()
            expo.modules.kritha.intelligence.L3CloudLLM.cancelInference()
            WakeWordListeningActivity.activeSession?.cancelPipeline()
            WakeWordForegroundService.stopAssistantSession()
        }

        Function("openMainApp") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
            if (context != null) {
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(launchIntent)
                }
            }
            WakeWordListeningActivity.stopSessionIfActive()
        }

        Function("triggerAssistantSession") {
            val context = appContext.currentActivity
                ?: appContext.reactContext
                ?: throw Exceptions.ReactContextLost()
            WakeWordForegroundService.triggerAssistantSession(context)
        }

        Function("sendToAssistant") { text: String, autoTts: Boolean ->
            WakeWordListeningActivity.processPrompt(text, autoTts)
        }

        Function("pauseTts") {
            WakeWordListeningActivity.activeSession?.pauseTts()
        }

        Function("resumeTts") {
            WakeWordListeningActivity.activeSession?.resumeTts()
        }

        Function("replayTts") {
            WakeWordListeningActivity.activeSession?.replayTts()
        }

        Function("stopTts") {
            WakeWordListeningActivity.activeSession?.stopTts()
        }

        AsyncFunction("startDictation") Coroutine { ->
            val context = appContext.currentActivity
                ?: appContext.reactContext
                ?: throw Exceptions.ReactContextLost()
            
            suspendCancellableCoroutine<String> { continuation ->
                mainHandler.post {
                    WakeWordForegroundService.pauseListening()
                    dictationContinuation = continuation
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    }
                    try {
                        dictationRecognizer?.cancel()
                        dictationRecognizer?.destroy()
                    } catch (e: Exception) {}
                    dictationRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                        setRecognitionListener(object : RecognitionListener {
                            override fun onReadyForSpeech(params: Bundle?) = Unit
                            override fun onBeginningOfSpeech() = Unit
                            override fun onRmsChanged(rmsdB: Float) {
                                sendEvent("onDictationVolume", mapOf("volume" to rmsdB))
                            }
                            override fun onBufferReceived(buffer: ByteArray?) = Unit
                            override fun onEndOfSpeech() = Unit
                            override fun onPartialResults(partialResults: Bundle?) {
                                val partial = partialResults
                                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                    ?.firstOrNull()
                                    ?.trim()
                                if (!partial.isNullOrEmpty()) {
                                    sendEvent("onDictationPartial", mapOf("text" to partial))
                                }
                            }
                            override fun onEvent(eventType: Int, params: Bundle?) = Unit

                            override fun onResults(results: Bundle?) {
                                val transcript = results
                                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                    ?.firstOrNull()
                                    ?.trim()
                                    .orEmpty()
                                dictationContinuation?.takeIf { it.isActive }?.resume(transcript)
                                dictationContinuation = null
                                WakeWordForegroundService.resumeListening()
                            }

                            override fun onError(error: Int) {
                                dictationContinuation?.takeIf { it.isActive }?.resume("")
                                dictationContinuation = null
                                WakeWordForegroundService.resumeListening()
                            }
                        })
                        startListening(intent)
                    }
                }
                
                continuation.invokeOnCancellation {
                    mainHandler.post {
                        dictationRecognizer?.cancel()
                        dictationContinuation = null
                        WakeWordForegroundService.resumeListening()
                    }
                }
            }
        }

        Function("stopDictation") {
            mainHandler.post {
                dictationRecognizer?.stopListening()
                WakeWordListeningActivity.activeSession?.stopListening()
            }
        }

        Function("cancelDictation") {
            mainHandler.post {
                dictationRecognizer?.cancel()
                dictationContinuation?.takeIf { it.isActive }?.resumeWithException(CancellationException("Dictation cancelled"))
                dictationContinuation = null
                WakeWordListeningActivity.activeSession?.cancelPipeline()
                WakeWordListeningActivity.activeSession?.stopListening()
            }
        }

        Function("respondToAssistant") { _: String ->
            WakeWordListeningActivity.stopSessionIfActive()
        }

        Function("getAvailableModels") {
            ModelManager.getAllModels().map { model ->
                mapOf(
                    "id" to model.id,
                    "name" to model.name,
                    "provider" to model.provider,
                    "remoteUrl" to model.remoteUrl,
                    "localPath" to model.localPath
                )
            }
        }

        Function("getSelectedModel") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getSelectedModel(context)
        }

        Function("setSelectedModel") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.setSelectedModel(context, modelId)
            modelId
        }

        Function("isModelDownloaded") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.isModelDownloaded(context, modelId)
        }

        Function("getDownloadedModels") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getDownloadedModels(context)
        }

        AsyncFunction("downloadModel") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getDownloadManager(context).downloadModel(modelId) { downloaded, total, speed ->
                sendEvent("onDownloadProgress", mapOf(
                    "modelId" to modelId,
                    "downloadedMb" to downloaded,
                    "totalMb" to total,
                    "speedMbps" to speed
                ))
            }
        }

        Function("pauseDownload") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getDownloadManager(context).pauseDownload(modelId)
        }

        Function("resumeDownload") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getDownloadManager(context).resumeDownload(modelId)
        }

        Function("cancelDownload") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            ModelManager.getDownloadManager(context).cancelDownload(modelId)
        }

        Function("speakText") { text: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: return@Function null
            TtsManager.speak(context, text)
        }

        Function("speakChunk") { chunk: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: return@Function null
            TtsManager.handleStreamingChunk(context, chunk)
        }

        Function("flushTts") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: return@Function null
            TtsManager.flushStreaming(context)
        }

        Function("stopTts") {
            TtsManager.stop()
        }

        AsyncFunction("generateLocalResponse") Coroutine { prompt: String, modelId: String? ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val selectedModelId = modelId ?: ModelManager.getSelectedModel(context)
            if (ModelCatalog.isCloudModel(selectedModelId)) {
                expo.modules.kritha.intelligence.L3CloudLLM(context).infer(prompt) { chunk ->
                    WakeWordEventHub.emitAssistant("streaming", transcript = prompt, chunk = chunk)
                } ?: ""
            } else {
                L2LocalLLM(context).infer(prompt, selectedModelId) { chunk ->
                    WakeWordEventHub.emitAssistant("streaming", transcript = prompt, chunk = chunk)
                } ?: ""
            }
        }

        Function("dispatchMediaKey") { keyCode: Int ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val eventTime = SystemClock.uptimeMillis()
            val downEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0)
            val upEvent = KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0)
            audioManager.dispatchMediaKeyEvent(downEvent)
            audioManager.dispatchMediaKeyEvent(upEvent)
        }

        Function("openAssistantSettings") {
            val context = appContext.currentActivity ?: appContext.reactContext
            if (context != null) {
                val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } else {
                false
            }
        }
    }
}