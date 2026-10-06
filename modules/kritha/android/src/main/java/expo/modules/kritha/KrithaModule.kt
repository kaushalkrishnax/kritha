package expo.modules.kritha

import expo.modules.kritha.runtime.RuntimeManager
import expo.modules.kritha.runtime.RuntimeCatalog
import expo.modules.kritha.runtime.RuntimeId
import expo.modules.kritha.runtime.InstallPermissionRequiredException
import expo.modules.kritha.liveTalk.IntelligenceConfig
import expo.modules.kritha.liveTalk.IntelligenceMessage
import expo.modules.kritha.liveTalk.LiveTalkConfig
import expo.modules.kritha.liveTalk.LiveTalkException
import expo.modules.kritha.liveTalk.LiveTalkSession
import expo.modules.kritha.liveTalk.LiveTalkTtsMode
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import expo.modules.kotlin.Promise

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
    private val runtimeManager by lazy { RuntimeManager(appContext.reactContext ?: throw IllegalStateException("No context")) }


    private val moduleScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeGenerationJobs = ConcurrentHashMap<String, Job>()
    private val activeVoiceDownloads = ConcurrentHashMap.newKeySet<String>()
    private var ttsBridge: TtsModuleBridge? = null
    private var voiceManager: VoiceManager? = null
    private var speechModelBridge: SpeechModelBridge? = null
    private var liveTalkSession: LiveTalkSession? = null

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
            try {
                ttsBridge = TtsModuleBridge(resolveContext())
            } catch (t: Throwable) {
                android.util.Log.e("KrithaModule", "Failed to initialize TtsModuleBridge", t)
            }
        }
        
        OnDestroy {
            if (instance === this@KrithaModule) {
                instance = null
            }
            liveTalkSession?.stop()
            liveTalkSession = null
            voiceManager?.stop()
            ttsBridge?.close()
            ttsBridge = null
            speechModelBridge?.close()
            speechModelBridge = null
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
            "onTtsError",
            "onRuntimeInstallProgress",
            "onLiveTalkEvent"
        )

        AsyncFunction("speechInitialize") { llmModelPath: String?, llmDevice: String?, sttModelId: String?, ttsModelId: String?, promise: Promise ->
            val vm = ensureVoiceManager()
            vm.setSttModelId(sttModelId)
            promise.resolve(null)
        }

        AsyncFunction("startListening") { requestId: String, promise: Promise ->
            moduleScope.launch {
                WakeWordForegroundService.pauseForStt()
                try {
                    ensureVoiceManager().startListening(requestId)
                    promise.resolve(null)
                } catch (e: Exception) {
                    WakeWordForegroundService.resumeFromStt()
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
                } finally {
                    WakeWordForegroundService.resumeFromStt()
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
                } finally {
                    WakeWordForegroundService.resumeFromStt()
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
            val bridge = ensureTtsBridge()
            ensureSpeechModelBridge().sttCatalog() + bridge.ttsCatalog()
        }

        AsyncFunction("downloadVoiceModel") { modelId: String, promise: Promise ->
            val bridge = ensureTtsBridge()
            val speechBridge = ensureSpeechModelBridge()
            moduleScope.launch {
                try {
                    val isTts = bridge.isTtsModel(modelId)
                    val isSpeech = speechBridge.isSpeechModel(modelId)
                    if (!isTts && !isSpeech) {
                        throw IllegalStateException("Unknown voice model: $modelId")
                    }
                    if (!activeVoiceDownloads.add(modelId)) {
                        throw IllegalStateException("Download for $modelId is already in progress")
                    }
                    try {
                        val onProgress: (Float) -> Unit = { progress ->
                            sendEvent(
                                "onVoiceModelProgress",
                                mapOf(
                                    "modelId" to modelId,
                                    // UI consumes this as a percent; never emit >100.
                                    "progress" to progress.coerceIn(0f, 100f),
                                ),
                            )
                        }
                        val target = if (isTts) {
                            bridge.downloadTtsModel(modelId, onProgress)
                        } else {
                            speechBridge.download(modelId, onProgress)
                        }
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
                ttsBridge?.deleteTtsModel(modelId)
            } else {
                speechModelBridge?.delete(modelId)
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

        Function("dismissAssistantOverlay") {
            WakeWordForegroundService.stopAssistantSession()
        }

        Function("openMainApp") {
            val context = resolveContext()
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP) }
                ?: return@Function false
            context.startActivity(intent)
            WakeWordForegroundService.stopAssistantSession()
            true
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

        Function("canInstallPackages") {
            val context =
                appContext.reactContext ?: appContext.currentActivity?.applicationContext ?: return@Function false
            DeviceTools.canInstallPackages(context)
        }

        Function("openInstallPermissionSettings") {
            val context = appContext.currentActivity ?: appContext.reactContext ?: return@Function false
            DeviceTools.openInstallPermissionSettings(context)
        }

        AsyncFunction("listRuntimes") {
            runtimeManager.allRuntimes().map { id ->
                mapOf(
                    "id" to RuntimeCatalog.getJsId(id),
                    "module" to RuntimeCatalog.getModuleName(id),
                    "installed" to runCatching { runtimeManager.isInstalled(id) }.getOrDefault(false),
                    "displayName" to RuntimeCatalog.getDisplayName(id),
                    "description" to RuntimeCatalog.getDescription(id),
                    "capabilities" to RuntimeCatalog.getCapabilities(id),
                )
            }
        }

        AsyncFunction("installRuntime") { input: Any?, promise: Promise ->
            moduleScope.launch {
                try {
                    val jsIds = parseRuntimeIds(input)
                    if (jsIds.isEmpty()) {
                        promise.reject(
                            "ERR_INVALID_REQUEST",
                            "installRuntime requires one runtime ID or an array of runtime IDs",
                            null,
                        )
                        return@launch
                    }
                    val unknown = jsIds.filter { RuntimeCatalog.fromJsId(it) == null }
                    if (unknown.isNotEmpty()) {
                        promise.reject(
                            "ERR_UNKNOWN_RUNTIME",
                            "Unknown runtime ID(s): ${unknown.joinToString()}. Available: litert, litert-lm, onnx",
                            null,
                        )
                        return@launch
                    }
                    val results = jsIds.map { jsId -> installOneRuntime(jsId) }
                    promise.resolve(results)
                } catch (e: Exception) {
                    promise.reject("ERR_INSTALL", e.message, e)
                }
            }
        }

        AsyncFunction("generateLocal") { request: Map<String, Any?>, promise: Promise ->
            generateLocal(request, promise)
        }
        Function("cancelLocalGeneration") { requestId: String ->
            cancelLocalGeneration(requestId)
        }

        // ------------------------------------------------------------------
        // Live Talk native API contract (RULES §9.1)
        //
        // startLiveTalk(config): Promise<void>
        //   config = {
        //     intelligence: { kind: "local"|"cloud", modelId, modelPath?, device?, apiKey? },
        //     context: [{ role, content }],
        //     tts: { enabled: boolean, mode: "disabled"|"after_generation"|"stream", voice? },
        //     sttModelId: string,
        //     vad?: { speechThreshold?, silenceThreshold?, silenceTimeoutMs?, maxUtteranceMs? },
        //     forceWebRtcAec?: boolean,
        //   }
        //   Rejects with coded LiveTalkException errors (MODEL_MISSING,
        //   RUNTIME_MISSING, MIC_PERMISSION_DENIED, AUDIO_INIT_FAILED, ...).
        //
        // stopLiveTalk(): Promise<void>     — full teardown to IDLE
        // interruptLiveTalk(): void         — manual barge-in; stop speaking, keep listening
        // pauseLiveTalkSession(): void      — freeze pipeline (mic stays open)
        // resumeLiveTalkSession(): void
        // setLiveTalkContext(messages): void — replace working context between turns
        // isLiveTalkActive(): boolean
        //
        // Events (single channel "onLiveTalkEvent", payload { type, ... }):
        //   session_started { aec, ttsMode }   session_stopped {}
        //   state { state }                     — idle|listening|user_speaking|processing|
        //                                         thinking|speaking|interrupted|paused
        //   speech_started {}                   speech_ended {}
        //   transcription_started { turnId }    transcription_completed { turnId, text }
        //   thinking_started { turnId }         assistant_text { turnId, delta }
        //   thinking_completed { turnId, text }
        //   tts_started { turnId }              tts_stopped { turnId, interrupted }
        //   interrupted { turnId }
        //   audio_level { level }               — throttled to ~10 Hz
        //   latency { metric, ms }              — spec §18 metrics
        //   error { code, message }
        // ------------------------------------------------------------------

        AsyncFunction("startLiveTalk") { config: Map<String, Any?>, promise: Promise ->
            moduleScope.launch {
                try {
                    startLiveTalkSession(config)
                    promise.resolve(null)
                } catch (e: LiveTalkException) {
                    promise.reject(e.code, e.message, e)
                } catch (e: Exception) {
                    promise.reject("ERR_LIVE_TALK_START", e.message, e)
                }
            }
        }

        AsyncFunction("stopLiveTalk") { promise: Promise ->
            moduleScope.launch {
                try {
                    stopLiveTalkSession()
                    promise.resolve(null)
                } catch (e: Exception) {
                    promise.reject("ERR_LIVE_TALK_STOP", e.message, e)
                }
            }
        }

        Function("interruptLiveTalk") {
            liveTalkSession?.interrupt()
        }

        Function("pauseLiveTalkSession") {
            liveTalkSession?.pause()
        }

        Function("resumeLiveTalkSession") {
            liveTalkSession?.resume()
        }

        Function("setLiveTalkContext") { messages: List<Map<String, String>> ->
            liveTalkSession?.setContext(
                messages.mapNotNull { raw ->
                    val role = raw["role"]
                    val content = raw["content"]
                    if (role == null || content == null) null else IntelligenceMessage(role, content)
                },
            )
        }

        Function("isLiveTalkActive") {
            liveTalkSession?.isActive == true
        }
    }

    private fun resolveContext(): Context = appContext.reactContext
        ?: appContext.currentActivity?.applicationContext
        ?: throw Exceptions.ReactContextLost()

    private fun ensureTtsBridge(): TtsModuleBridge {
        val existing = ttsBridge
        if (existing != null) return existing
        val created = TtsModuleBridge(resolveContext())
        ttsBridge = created
        return created
    }

    private fun ensureVoiceManager(): VoiceManager {
        val existing = voiceManager
        if (existing != null) return existing
        val created = VoiceManager(
            ensureTtsBridge(),
            ensureSpeechModelBridge(),
            runtimeManager,
            resolveContext(),
        ) { event, data ->
            sendEvent(event, data)
        }
        voiceManager = created
        return created
    }

    private fun ensureSpeechModelBridge(): SpeechModelBridge {
        val existing = speechModelBridge
        if (existing != null) return existing
        val created = SpeechModelBridge(resolveContext())
        speechModelBridge = created
        return created
    }

    @Synchronized
    private fun startLiveTalkSession(config: Map<String, Any?>) {
        liveTalkSession?.stop()
        liveTalkSession = null

        val session = LiveTalkSession(
            context = resolveContext(),
            runtimeManager = runtimeManager,
            ttsBridge = ensureTtsBridge(),
            speechModels = ensureSpeechModelBridge(),
        ) { payload ->
            sendEvent("onLiveTalkEvent", payload)
        }
        liveTalkSession = session

        WakeWordForegroundService.pauseForStt()
        try {
            session.start(parseLiveTalkConfig(config))
        } catch (e: Exception) {
            runCatching { session.stop() }
            liveTalkSession = null
            WakeWordForegroundService.resumeFromStt()
            throw e
        }
    }

    @Synchronized
    private fun stopLiveTalkSession() {
        val session = liveTalkSession ?: return
        liveTalkSession = null
        try {
            session.stop()
        } finally {
            WakeWordForegroundService.resumeFromStt()
        }
    }

    private fun parseLiveTalkConfig(config: Map<String, Any?>): LiveTalkSession.SessionConfig {
        val rawIntelligence = config["intelligence"] as? Map<*, *>
            ?: throw LiveTalkException(
                LiveTalkException.ERR_INTELLIGENCE,
                "startLiveTalk requires an intelligence config",
            )
        val intelligence = IntelligenceConfig(
            kind = rawIntelligence["kind"] as? String ?: "local",
            modelId = rawIntelligence["modelId"] as? String
                ?: throw LiveTalkException(
                    LiveTalkException.ERR_INTELLIGENCE,
                    "intelligence.modelId is required",
                ),
            modelPath = rawIntelligence["modelPath"] as? String,
            device = rawIntelligence["device"] as? String ?: "cpu",
            apiKey = rawIntelligence["apiKey"] as? String,
        )

        val context = (config["context"] as? List<*>)?.mapNotNull { item ->
            (item as? Map<*, *>)?.let { raw ->
                val role = raw["role"] as? String
                val content = raw["content"] as? String
                if (role == null || content == null) null else IntelligenceMessage(role, content)
            }
        } ?: emptyList()

        val rawTts = config["tts"] as? Map<*, *>
        val ttsEnabled = (rawTts?.get("enabled") as? Boolean) ?: true
        val ttsMode = LiveTalkTtsMode.fromWire(rawTts?.get("mode") as? String)
        val ttsVoice = rawTts?.get("voice") as? String ?: "F1"

        val rawVad = config["vad"] as? Map<*, *>
        val vadConfig = LiveTalkConfig(
            vadSpeechThreshold = (rawVad?.get("speechThreshold") as? Number)?.toFloat() ?: 0.5f,
            vadSilenceThreshold = (rawVad?.get("silenceThreshold") as? Number)?.toFloat() ?: 0.35f,
            silenceFrameCount = ((rawVad?.get("silenceTimeoutMs") as? Number)?.toLong()
                ?.let { it / vadFrameMs }?.toInt()) ?: 22,
            absoluteUtteranceTimeoutMs = (rawVad?.get("maxUtteranceMs") as? Number)?.toLong()
                ?: 30_000L,
            forceWebRtcApm = config["forceWebRtcAec"] as? Boolean ?: false,
        )

        return LiveTalkSession.SessionConfig(
            intelligence = intelligence,
            context = context,
            ttsEnabled = ttsEnabled,
            ttsMode = ttsMode,
            ttsVoice = ttsVoice,
            sttModelId = config["sttModelId"] as? String ?: SpeechModelBridge.DEFAULT_STT_MODEL_ID,
            vadConfig = vadConfig,
        )
    }

    /** 512 samples @ 16 kHz; converts the JS silence timeout into VAD frames. */
    private val vadFrameMs: Long = 32L

    private fun isTtsModel(modelId: String): Boolean {
        return runCatching { ensureTtsBridge().isTtsModel(modelId) }.getOrDefault(false)
    }

    private fun parseRuntimeIds(input: Any?): List<String> {
        return when (input) {
            is String -> listOf(input)
            is List<*> -> input.mapNotNull { it?.toString() }
            else -> emptyList()
        }
    }

    private suspend fun installOneRuntime(jsId: String): Map<String, Any?> {
        val runtime = RuntimeCatalog.fromJsId(jsId) ?: return mapOf(
            "id" to jsId,
            "module" to null,
            "installed" to false,
            "providerAvailable" to false,
            "error" to "Unknown runtime ID: $jsId",
            "errorCode" to "UNKNOWN_RUNTIME",
        )
        val canonicalId = RuntimeCatalog.getJsId(runtime)
        val moduleName = RuntimeCatalog.getModuleName(runtime)

        val progressJob = moduleScope.launch {
            try {
                runtimeManager.observeInstall(runtime).collect { state ->
                    sendEvent(
                        "onRuntimeInstallProgress",
                        mapOf(
                            "runtimeId" to canonicalId,
                            "module" to moduleName,
                            "status" to state.status.name,
                            "progress" to state.progress,
                        ),
                    )
                }
            } catch (_: Exception) {
            }
        }
        return try {
            runtimeManager.ensureInstalled(runtime)
            sendEvent(
                "onRuntimeInstallProgress",
                mapOf(
                    "runtimeId" to canonicalId,
                    "module" to moduleName,
                    "status" to "READY",
                    "progress" to 100,
                ),
            )
            mapOf(
                "id" to canonicalId,
                "module" to moduleName,
                "installed" to true,
                "providerAvailable" to true,
                "error" to null,
                "errorCode" to null,
            )
        } catch (e: InstallPermissionRequiredException) {
            sendEvent(
                "onRuntimeInstallProgress",
                mapOf(
                    "runtimeId" to canonicalId,
                    "module" to moduleName,
                    "status" to "PERMISSION_REQUIRED",
                    "progress" to null,
                ),
            )
            mapOf(
                "id" to canonicalId,
                "module" to moduleName,
                "installed" to false,
                "providerAvailable" to false,
                "error" to (e.message ?: "Install permission required"),
                "errorCode" to "PERMISSION_REQUIRED",
            )
        } catch (e: Exception) {
            val installed = runCatching { runtimeManager.isInstalled(runtime) }.getOrDefault(false)
            sendEvent(
                "onRuntimeInstallProgress",
                mapOf(
                    "runtimeId" to canonicalId,
                    "module" to moduleName,
                    "status" to "FAILED",
                    "progress" to null,
                ),
            )
            mapOf(
                "id" to canonicalId,
                "module" to moduleName,
                "installed" to installed,
                "providerAvailable" to false,
                "error" to (e.message ?: "Install failed"),
                "errorCode" to "INSTALL_FAILED",
            )
        } finally {
            progressJob.cancel()
        }
    }

    private fun generateLocal(request: Map<String, Any?>, promise: Promise) {
        val requestId = request["requestId"] as? String
        val modelPath = request["modelPath"] as? String ?: ""
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
                val provider = runtimeManager.provider(RuntimeId.LITERT_LM)?.llm() ?: throw IllegalStateException("LiteRT-LM is not installed")
                val text = provider.generate(request, onDelta = { delta ->
                    sendEvent("onLocalLlmDelta", mapOf("requestId" to requestId, "delta" to delta))
                })
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
            
            job.cancel()
        }
        return true
    }

    private fun parseMessages(raw: Any?): List<Map<String, String>>? {
        if (raw !is List<*>) return null
        val messages = mutableListOf<Map<String, String>>()
        for (item in raw) {
            if (item !is Map<*, *>) return null
            val role = item["role"] as? String ?: return null
            val content = item["content"] as? String ?: return null
            messages += mapOf("role" to role, "content" to content)
        }
        return messages
    }
}