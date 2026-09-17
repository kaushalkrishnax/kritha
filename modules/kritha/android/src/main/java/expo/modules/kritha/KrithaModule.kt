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
import java.util.concurrent.ConcurrentHashMap

class KrithaModule : Module() {

    private val moduleScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeGenerationJobs = ConcurrentHashMap<String, Job>()
    private val activeVoiceDownloads = ConcurrentHashMap.newKeySet<String>()
    private val localLlmExecutor = LocalLlmExecutor()
    private var liteRtBridge: LiteRTModuleBridge? = null
    private var voiceManager: LiteRTVoiceManager? = null

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
            liteRtBridge = LiteRTModuleBridge(resolveContext())
        }
        
        OnDestroy {
            if (instance === this@KrithaModule) {
                instance = null
            }
            voiceManager?.stop()
            liteRtBridge?.close()
            liteRtBridge = null
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

        AsyncFunction("speechInitialize") { llmModelPath: String?, llmDevice: String?, sttModelId: String?, ttsModelId: String?, promise: Promise ->
            ensureVoiceManager()
            ensureLiteRtBridge().setTtsModelSelection(ttsModelId)
            promise.resolve(null)
        }

        AsyncFunction("startListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                try {
                    ensureVoiceManager().startListening(requestId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_START", e.message, e)
                }
            }
        }

        AsyncFunction("stopListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                try {
                    val transcript = ensureVoiceManager().stopListening(requestId)
                    promise.resolve(transcript)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_STOP", e.message, e)
                }
            }
        }

        AsyncFunction("cancelListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                try {
                    ensureVoiceManager().cancelListening(requestId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_STT_CANCEL", e.message, e)
                }
            }
        }

        AsyncFunction("speechStart") { llmModelPath: String?, llmDevice: String? ->
            ensureVoiceManager().start(llmModelPath, llmDevice ?: "cpu")
            null
        }
        
        AsyncFunction("speechStop") {
            voiceManager?.stop()
            null
        }

        AsyncFunction("speak") { requestId: String, text: String, voice: String?, promise: Promise ->
            ensureVoiceManager().speak(requestId, text, voice ?: "F1") {
                promise.resolve(null)
            }
        }

        AsyncFunction("pauseSpeaking") { requestId: String? ->
            voiceManager?.pauseSpeaking(requestId)
            null
        }

        AsyncFunction("resumeSpeaking") { requestId: String? ->
            voiceManager?.resumeSpeaking(requestId)
            null
        }

        AsyncFunction("stopSpeaking") { requestId: String? ->
            voiceManager?.stopSpeaking(requestId)
            null
        }

        AsyncFunction("addTool") { name: String, desc: String ->
            null
        }

        AsyncFunction("listVoiceModels") {
            val bridge = ensureLiteRtBridge()
            listOf(
                mapOf(
                    "id" to "nemotron-multilingual-int8",
                    "name" to "Nemotron 3.5 Multilingual (LiteRT INT8)",
                    "size" to "250 MB",
                    "langs" to "Multilingual (25+ Languages)",
                    "category" to "stt",
                    "backend" to "LiteRT",
                    "isDownloaded" to false
                ),
                mapOf(
                    "id" to "nemotron-multilingual-fp16",
                    "name" to "Nemotron 3.5 Multilingual (LiteRT FP16)",
                    "size" to "500 MB",
                    "langs" to "Multilingual (High Precision)",
                    "category" to "stt",
                    "backend" to "LiteRT",
                    "isDownloaded" to false
                )
            ) + bridge.ttsCatalog()
        }

        AsyncFunction("downloadVoiceModel") { modelId: String, promise: Promise ->
            val bridge = ensureLiteRtBridge()
            moduleScope.launch {
                try {
                    if (!bridge.isTtsModel(modelId)) {
                        throw IllegalStateException(
                            "STT is stubbed; LiteRT speech-to-text is not implemented yet."
                        )
                    }
                    if (!activeVoiceDownloads.add(modelId)) {
                        throw IllegalStateException("Download for $modelId is already in progress")
                    }
                    try {
                        val onProgress: (Float) -> Unit = { progress ->
                            sendEvent(
                                "onVoiceModelProgress",
                                mapOf("modelId" to modelId, "progress" to progress),
                            )
                        }
                        val target = bridge.downloadTtsModel(modelId, onProgress)
                        sendEvent(
                            "onVoiceModelProgress",
                            mapOf(
                                "modelId" to modelId,
                                "progress" to 100,
                                "path" to target.absolutePath,
                            ),
                        )
                        promise.resolve(null)
                    } finally {
                        activeVoiceDownloads.remove(modelId)
                    }
                } catch (e: Exception) {
                    sendEvent(
                        "onError",
                        mapOf("modelId" to modelId, "message" to (e.message ?: "Download failed")),
                    )
                    promise.reject("ERR_DOWNLOAD", e.message, e)
                }
            }
        }

        AsyncFunction("deleteVoiceModel") { modelId: String ->
            if (isTtsModel(modelId)) {
                liteRtBridge?.deleteTtsModel(modelId)
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

        AsyncFunction("liteRtInfo") {
            liteRtBridge?.info()
                ?: throw IllegalStateException("LiteRT bridge is not initialized")
        }

        AsyncFunction("liteRtInspectModel") {
            request: Map<String, Any?>,
            promise: Promise ->
            moduleScope.launch {
                try {
                    val bridge = ensureLiteRtBridge()

                    val id = request["id"] as? String ?: error("id is required")
                    val path = request["path"] as? String ?: error("path is required")
                    val task = request["task"] as? String ?: "tts"
                    val signature = request["signature"] as? String ?: error("signature is required")
                    val inputs = (request["inputs"] as? List<*>)
                        ?.map { it as? String ?: error("inputs must contain strings") }
                        ?: emptyList()
                    val outputs = (request["outputs"] as? List<*>)
                        ?.map { it as? String ?: error("outputs must contain strings") }
                        ?: emptyList()
                    val outputTypes = (request["outputTypes"] as? List<*>)
                        ?.map { it as? String ?: error("outputTypes must contain strings") }
                        ?: emptyList()

                    promise.resolve(
                        bridge.inspectModel(
                            id = id,
                            path = path,
                            task = task,
                            signature = signature,
                            inputNames = inputs,
                            outputNames = outputs,
                            outputTypes = outputTypes,
                        )
                    )
                } catch (e: Exception) {
                    promise.reject("ERR_LITERT_INSPECT", e.message, e)
                }
            }
        }

        AsyncFunction("liteRtTtsSynthesize") {
            request: Map<String, Any?>,
            promise: Promise ->
            moduleScope.launch {
                try {
                    val bridge = ensureLiteRtBridge()

                    val modelId = request["modelId"] as? String ?: ensureLiteRtBridge().defaultTtsModelId()
                    val modelDirectory = request["modelDirectory"] as? String
                        ?: error("modelDirectory is required")
                    val text = request["text"] as? String
                        ?: error("text is required")
                    val language = request["language"] as? String ?: "english"
                    val voice = (request["voice"] as? Number)?.toInt() ?: 0
                    val speed = (request["speed"] as? Number)?.toFloat() ?: 1f
                    val greedy = request["greedy"] as? Boolean ?: true
                    val seed = (request["seed"] as? Number)?.toLong()

                    promise.resolve(
                        bridge.synthesizeTts(
                            modelId = modelId,
                            modelDirectory = modelDirectory,
                            text = text,
                            language = language,
                            voice = voice,
                            speed = speed,
                            greedy = greedy,
                            seed = seed,
                        )
                    )
                } catch (e: Exception) {
                    promise.reject("ERR_LITERT_TTS", e.message, e)
                }
            }
        }
    }

    private fun resolveContext(): Context = appContext.reactContext
        ?: appContext.currentActivity?.applicationContext
        ?: throw Exceptions.ReactContextLost()

    private fun ensureLiteRtBridge(): LiteRTModuleBridge {
        val existing = liteRtBridge
        if (existing != null) return existing
        val created = LiteRTModuleBridge(resolveContext())
        liteRtBridge = created
        return created
    }

    private fun ensureVoiceManager(): LiteRTVoiceManager {
        val existing = voiceManager
        if (existing != null) return existing
        val created = LiteRTVoiceManager(ensureLiteRtBridge()) { event, data ->
            sendEvent(event, data)
        }
        voiceManager = created
        return created
    }

    private fun isTtsModel(modelId: String): Boolean {
        return runCatching { ensureLiteRtBridge().isTtsModel(modelId) }.getOrDefault(false)
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