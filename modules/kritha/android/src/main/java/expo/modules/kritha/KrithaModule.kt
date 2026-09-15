package expo.modules.kritha

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import expo.modules.kotlin.Promise
import expo.modules.kritha.platform.LocalLlmExecutor
import expo.modules.kritha.platform.LocalLlmMessage
import expo.modules.kritha.platform.LiteRTEngineManager
import expo.modules.kritha.platform.wakeword.WakeWordForegroundService
import expo.modules.kritha.tools.DeviceTools
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class KrithaModule : Module() {

    private val moduleScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeGenerationJobs = ConcurrentHashMap<String, Job>()
    private val localLlmExecutor = LocalLlmExecutor()
    private var voiceManager: SoniqoVoiceManager? = null

    companion object {
        var instance: KrithaModule? = null
        val appContextStatic get() = instance?.appContext?.reactContext ?: instance?.appContext?.currentActivity?.applicationContext
        
        fun emitWakeWord(confidence: Float) {
            instance?.sendEvent("onWakeWordDetected", mapOf("confidence" to confidence))
        }
    }

    override fun definition() = ModuleDefinition {
        Name("Kritha")
        
        OnCreate {
            instance = this@KrithaModule
        }
        
        OnDestroy {
            if (instance === this@KrithaModule) {
                instance = null
            }
            voiceManager?.stop()
        }
        
        Events(
            "onWakeWordDetected",
            "onSpeechStarted",
            "onSpeechEnded",
            "onTranscript",
            "onResponseCreated",
            "onResponseDone",
            "onResponseInterrupted",
            "onError",
            "onLocalLlmDelta",
            "onVoiceModelProgress",
            "onSttStarted",
            "onSttStopped",
            "onSttCancelled",
            "onSttError",
            "onAudioLevel",
            "onTtsStarted",
            "onTtsPaused",
            "onTtsResumed",
            "onTtsCompleted",
            "onTtsStopped",
            "onTtsError"
        )

        AsyncFunction("soniqoInitialize") { llmModelPath: String?, llmDevice: String?, sttModelId: String?, ttsModelId: String?, promise: Promise ->
            if (voiceManager == null) {
                val context = resolveContext()
                voiceManager = SoniqoVoiceManager(context, localLlmExecutor) { event, data ->
                    sendEvent(event, data)
                }
            }
            moduleScope.launch {
                try {
                    voiceManager?.initialize(llmModelPath, sttModelId, ttsModelId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_SONIQO_INIT", e.message, e)
                }
            }
        }
        
        AsyncFunction("soniqoStartListening") { requestId: String, promise: Promise ->
            ensureVoiceManager()
            moduleScope.launch {
                try {
                    voiceManager?.startListening(requestId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_START", e.message, e)
                }
            }
        }

        AsyncFunction("soniqoStopListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                try {
                    val transcript = voiceManager?.stopListening(requestId) ?: ""
                    promise.resolve(transcript)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_STOP", e.message, e)
                }
            }
        }

        AsyncFunction("soniqoCancelListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                try {
                    voiceManager?.cancelListening(requestId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_CANCEL", e.message, e)
                }
            }
        }

        AsyncFunction("soniqoStart") { llmModelPath: String?, llmDevice: String? ->
            voiceManager?.start(llmModelPath, llmDevice ?: "cpu")
            null
        }
        
        AsyncFunction("soniqoStop") {
            voiceManager?.stop()
            null
        }

        AsyncFunction("soniqoSpeak") { requestId: String, text: String, voice: String?, promise: Promise ->
            ensureVoiceManager()
            voiceManager?.speak(requestId, text, voice ?: "F1") {
                promise.resolve(null)
            }
        }

        AsyncFunction("soniqoPauseSpeaking") { requestId: String? ->
            voiceManager?.pauseSpeaking(requestId)
            null
        }

        AsyncFunction("soniqoResumeSpeaking") { requestId: String? ->
            voiceManager?.resumeSpeaking(requestId)
            null
        }

        AsyncFunction("soniqoStopSpeaking") { requestId: String? ->
            voiceManager?.stopSpeaking(requestId)
            null
        }

        AsyncFunction("soniqoAddTool") { name: String, desc: String ->
            null
        }

        AsyncFunction("listVoiceModels") {
            val context = resolveContext()
            val nemotronInt8Ready = audio.soniqo.speech.ModelManager.areModelsReady(
                context,
                audio.soniqo.speech.ModelPrecision.INT8,
                audio.soniqo.speech.SttModel.NEMOTRON_MULTILINGUAL,
                audio.soniqo.speech.SttBackend.LITERT,
                audio.soniqo.speech.TtsModel.SUPERTONIC
            )
            val nemotronFp16Ready = audio.soniqo.speech.ModelManager.areModelsReady(
                context,
                audio.soniqo.speech.ModelPrecision.FP32,
                audio.soniqo.speech.SttModel.NEMOTRON_MULTILINGUAL,
                audio.soniqo.speech.SttBackend.LITERT,
                audio.soniqo.speech.TtsModel.SUPERTONIC
            )
            val supertonicReady = audio.soniqo.speech.ModelManager.areTtsModelsReady(
                context,
                audio.soniqo.speech.TtsModel.SUPERTONIC
            )

            listOf(
                mapOf(
                    "id" to "nemotron-multilingual-int8",
                    "name" to "Nemotron 3.5 Multilingual (LiteRT INT8)",
                    "size" to "250 MB",
                    "langs" to "Multilingual (25+ Languages)",
                    "category" to "stt",
                    "backend" to "LiteRT",
                    "isDownloaded" to nemotronInt8Ready
                ),
                mapOf(
                    "id" to "nemotron-multilingual-fp16",
                    "name" to "Nemotron 3.5 Multilingual (LiteRT FP16)",
                    "size" to "500 MB",
                    "langs" to "Multilingual (High Precision)",
                    "category" to "stt",
                    "backend" to "LiteRT",
                    "isDownloaded" to nemotronFp16Ready
                ),
                mapOf(
                    "id" to "supertonic-litert",
                    "name" to "Supertonic-3 (LiteRT)",
                    "size" to "140 MB",
                    "langs" to "English (10 Voices: F1-F5, M1-M5)",
                    "category" to "tts",
                    "backend" to "LiteRT",
                    "isDownloaded" to supertonicReady
                )
            )
        }

        AsyncFunction("downloadVoiceModel") { modelId: String, promise: Promise ->
            val context = resolveContext()
            moduleScope.launch {
                try {
                    if (isTtsOnlyModelId(modelId)) {
                        audio.soniqo.speech.ModelManager.ensureTtsModels(
                            context = context,
                            ttsModel = audio.soniqo.speech.TtsModel.SUPERTONIC,
                            onProgress = { p ->
                                val pct = if (p.totalBytes > 0) ((p.totalBytesDownloaded * 100) / p.totalBytes).toInt() else 0
                                sendEvent("onVoiceModelProgress", mapOf(
                                    "modelId" to modelId,
                                    "progress" to pct
                                ))
                            }
                        )
                    } else {
                        val precision = if (modelId.contains("fp16")) {
                            audio.soniqo.speech.ModelPrecision.FP32
                        } else {
                            audio.soniqo.speech.ModelPrecision.INT8
                        }
                        audio.soniqo.speech.ModelManager.ensureModels(
                            context = context,
                            precision = precision,
                            sttModel = audio.soniqo.speech.SttModel.NEMOTRON_MULTILINGUAL,
                            sttBackend = audio.soniqo.speech.SttBackend.LITERT,
                            ttsModel = audio.soniqo.speech.TtsModel.SUPERTONIC,
                            onProgress = { p ->
                                val pct = if (p.totalBytes > 0) ((p.totalBytesDownloaded * 100) / p.totalBytes).toInt() else 0
                                sendEvent("onVoiceModelProgress", mapOf(
                                    "modelId" to modelId,
                                    "progress" to pct
                                ))
                            }
                        )
                    }
                    sendEvent("onVoiceModelProgress", mapOf(
                        "modelId" to modelId,
                        "progress" to 100
                    ))
                    promise.resolve(null)
                } catch (e: Exception) {
                    sendEvent("onError", mapOf("message" to (e.message ?: "Download failed")))
                    promise.reject("ERR_DOWNLOAD", e.message, e)
                }
            }
        }

        AsyncFunction("deleteVoiceModel") { modelId: String ->
            val context = resolveContext()
            if (isTtsOnlyModelId(modelId)) {
                val dir = File(audio.soniqo.speech.ModelManager.ttsModelDir(context))
                if (dir.exists()) dir.deleteRecursively()
            } else {
                val precision = if (modelId.contains("fp16")) {
                    audio.soniqo.speech.ModelPrecision.FP32
                } else {
                    audio.soniqo.speech.ModelPrecision.INT8
                }
                val dir = File(audio.soniqo.speech.ModelManager.modelDir(
                    context,
                    precision,
                    audio.soniqo.speech.SttModel.NEMOTRON_MULTILINGUAL,
                    audio.soniqo.speech.SttBackend.LITERT,
                    audio.soniqo.speech.TtsModel.SUPERTONIC
                ))
                if (dir.exists()) dir.deleteRecursively()
            }
            null
        }

        Function("start") {
            WakeWordForegroundService.start(resolveContext())
        }

        Function("stop") {
            WakeWordForegroundService.stop(resolveContext())
        }
        
        Function("pauseForStt") {
            WakeWordForegroundService.pauseForStt()
        }
        
        Function("resumeFromStt") {
            WakeWordForegroundService.resumeFromStt()
        }

        Function("isRunning") {
            WakeWordForegroundService.isRunning
        }

        Function("isDefaultAssistant") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: return@Function false
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val roleManager = context.getSystemService(android.app.role.RoleManager::class.java)
                    roleManager?.isRoleHeld(android.app.role.RoleManager.ROLE_ASSISTANT) == true
                } else {
                    val setting = Settings.Secure.getString(context.contentResolver, "assistant")
                    setting != null && setting.contains(context.packageName)
                }
            } catch (e: Exception) {
                false
            }
        }

        Function("openAssistantSettings") {
            val context = appContext.currentActivity ?: appContext.reactContext ?: return@Function false
            val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        }

        Function("isNotificationListenerEnabled") {
            val context =
                appContext.reactContext ?: appContext.currentActivity?.applicationContext ?: return@Function false
            DeviceTools.isNotificationListenerEnabled(context)
        }

        Function("requestNotificationListenerPermission") {
            val context = appContext.currentActivity ?: appContext.reactContext ?: return@Function false
            DeviceTools.requestNotificationListenerPermission(context)
            true
        }

        AsyncFunction("generateLocal") { request: Map<String, Any?>, promise: Promise ->
            generateLocal(request, promise)
        }

        Function("cancelLocalGeneration") { requestId: String ->
            cancelLocalGeneration(requestId)
        }
    }

    private fun resolveContext(): Context = appContext.reactContext
        ?: appContext.currentActivity?.applicationContext
        ?: throw Exceptions.ReactContextLost()

    private fun ensureVoiceManager(): SoniqoVoiceManager {
        val existing = voiceManager
        if (existing != null) return existing
        val context = resolveContext()
        val created = SoniqoVoiceManager(context, localLlmExecutor) { event, data ->
            sendEvent(event, data)
        }
        voiceManager = created
        return created
    }

    private fun isTtsOnlyModelId(modelId: String): Boolean {
        val id = modelId.lowercase()
        return id.contains("supertonic") || id.contains("kokoro") || id.contains("pocket") || id.startsWith("tts")
    }

    private fun generateLocal(request: Map<String, Any?>, promise: Promise) {
        val requestId = request["requestId"] as? String
        val modelPath = request["modelPath"] as? String ?: ""
        val device = LiteRTEngineManager.Device.from(request["device"] as? String)
        val messages = parseMessages(request["messages"])

        if (requestId == null || modelPath.isEmpty() || messages == null || messages.isEmpty()) {
            promise.reject(
                "ERR_INVALID_REQUEST",
                "generateLocal requires a non-null requestId, a non-empty modelPath, and a non-empty messages list",
                null,
            )
            return
        }

        val job = moduleScope.launch {
            try {
                val text = localLlmExecutor.generateLocal(
                    requestId = requestId,
                    modelPath = modelPath,
                    device = device,
                    messages = messages,
                ) { delta ->
                    sendEvent("onLocalLlmDelta", mapOf("requestId" to requestId, "delta" to delta))
                }
                promise.resolve(text)
            } catch (e: CancellationException) {
                promise.reject("ERR_CANCELLED", "Local generation cancelled", e)
            } catch (e: Exception) {
                promise.reject("ERR_GENERATION_FAILED", e.message ?: "Local generation failed", e)
            } finally {
                activeGenerationJobs.remove(requestId)
            }
        }
        activeGenerationJobs[requestId] = job
    }

    private fun cancelLocalGeneration(requestId: String): Boolean {
        val job = activeGenerationJobs.remove(requestId) ?: return false
        moduleScope.launch {
            runCatching { localLlmExecutor.cancelProcess(requestId) }
            job.cancel()
        }
        return true
    }

    private fun parseMessages(raw: Any?): List<LocalLlmMessage>? {
        if (raw !is List<*>) return null
        val messages = mutableListOf<LocalLlmMessage>()
        for (item in raw) {
            if (item !is Map<*, *>) return null
            val role = item["role"] as? String ?: return null
            val content = item["content"] as? String ?: return null
            messages += LocalLlmMessage(role = role, content = content)
        }
        return messages
    }
}
