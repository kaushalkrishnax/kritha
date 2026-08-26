package expo.modules.kritha

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kritha.intelligence.LiteRTEngineManager
import expo.modules.kritha.tools.DeviceTools
import expo.modules.kritha.wakeword.WakeWordEventHub
import expo.modules.kritha.wakeword.WakeWordForegroundService
import expo.modules.kritha.wakeword.WakeWordListeningActivity

class KrithaModule : Module() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun definition() = ModuleDefinition {
        Name("Kritha")
        Events("onWakeWordDetected", "onAssistantEvent", "onDownloadProgress")

        WakeWordEventHub.listener = { keyword, confidence ->
            mainHandler.post {
                try {
                    sendEvent("onWakeWordDetected", mapOf("keyword" to keyword, "confidence" to confidence))
                } catch (e: Exception) {
                    Log.e("KrithaModule", "Failed to send wake word event", e)
                }
            }
        }

        WakeWordEventHub.assistantEventListener = { type, payload ->
            mainHandler.post {
                try {
                    sendEvent(
                        "onAssistantEvent",
                        mapOf(
                            "type" to type,
                            "payload" to payload
                        )
                    )
                } catch (e: Exception) {
                    Log.e("KrithaModule", "Failed to send assistant event", e)
                }
            }
        }

        OnStopObserving {
        }

        // ASSISTANT & SYSTEM OPERATIONS
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

        Function("setBargeInEnabled") { enabled: Boolean ->
            BargeInMonitor.isEnabled = enabled
            if (!enabled) {
                BargeInMonitor.stop()
            }
        }

        Function("getLocalModelDevice") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            LiteRTEngineManager.getDevice(context).name.lowercase()
        }

        Function("setLocalModelDevice") { device: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val selectedDevice = when (device.lowercase()) {
                "gpu" -> LiteRTEngineManager.Device.GPU
                else -> LiteRTEngineManager.Device.CPU
            }
            LiteRTEngineManager.setDevice(context, selectedDevice)
            selectedDevice.name.lowercase()
        }

        Function("setCloudApiKey") { apiKey: String ->
            expo.modules.kritha.intelligence.L3CloudLLM.apiKey = apiKey
        }

        Function("getCustomInstructions") { ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val prefs = context.getSharedPreferences("kritha_settings", android.content.Context.MODE_PRIVATE)
            prefs.getString("custom_instructions", "") ?: ""
        }

        Function("setCustomInstructions") { instructions: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val prefs = context.getSharedPreferences("kritha_settings", android.content.Context.MODE_PRIVATE)
            prefs.edit().putString("custom_instructions", instructions).apply()
            AssistantCore.customInstructions = instructions
        }

        Function("getUserName") {
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val prefs = context.getSharedPreferences("kritha_settings", android.content.Context.MODE_PRIVATE)
            prefs.getString("user_name", "") ?: ""
        }

        Function("setUserName") { name: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()
            val prefs = context.getSharedPreferences("kritha_settings", android.content.Context.MODE_PRIVATE)
            prefs.edit().putString("user_name", name).apply()
            AssistantCore.userName = name
        }

        Function("getCurrentState") {
            AssistantCore.getCurrentStateMap()
        }

        Function("dispatchCommand") { commandMap: Map<String, Any?> ->
            val type = commandMap["type"] as? String ?: return@Function false
            val context = appContext.currentActivity ?: appContext.reactContext
            when (type.uppercase()) {

                "SUBMIT_TEXT" -> {
                    val text = commandMap["text"] as? String ?: ""
                    val chatSessionId = commandMap["chatSessionId"] as? String
                    val modelId = commandMap["modelId"] as? String
                    val assistantRunId = commandMap["assistantRunId"] as? String
                    val origin = commandMap["origin"] as? String ?: "MANUAL_TYPING"

                    @Suppress("UNCHECKED_CAST")
                    val historyList =
                        (commandMap["history"] as? List<*>)?.filterIsInstance<Map<String, Any>>() ?: emptyList()
                    if (context != null) {
                        AssistantCore.submitText(
                            context,
                            text,
                            chatSessionId,
                            modelId,
                            assistantRunId,
                            origin,
                            historyList
                        )
                        true
                    } else false
                }

                "START_LISTENING" -> {
                    val chatSessionId = commandMap["chatSessionId"] as? String
                    if (context != null) {
                        AssistantCore.startListening(context, chatSessionId)
                        true
                    } else false
                }

                "STOP_LISTENING" -> {
                    AssistantCore.stopListening()
                    true
                }

                "PLAY_TTS" -> {
                    val text = commandMap["text"] as? String ?: ""
                    val chatSessionId = commandMap["chatSessionId"] as? String
                    val assistantRunId = commandMap["assistantRunId"] as? String
                    val messageId = commandMap["messageId"] as? String
                    if (context != null) {
                        AssistantCore.playTts(context, text, chatSessionId, assistantRunId, messageId)
                        true
                    } else false
                }

                "PAUSE_TTS" -> {
                    AssistantCore.pauseTts()
                    true
                }

                "RESUME_TTS" -> {
                    AssistantCore.resumeTts()
                    true
                }

                "STOP_TTS" -> {
                    AssistantCore.stopTts()
                    true
                }

                "CANCEL" -> {
                    val assistantRunId = commandMap["assistantRunId"] as? String ?: ""
                    val requestId = commandMap["requestId"] as? String ?: ""
                    AssistantCore.cancel(assistantRunId, requestId)
                    true
                }

                "DISMISS" -> {
                    AssistantCore.dismiss()
                    true
                }

                "OPEN_MAIN_APP" -> {
                    if (context != null) {
                        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            context.startActivity(launchIntent)
                        }
                        WakeWordListeningActivity.stopSessionIfActive()
                        true
                    } else false
                }

                else -> false
            }
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

        Function("downloadModel") { modelId: String ->
            val context = appContext.reactContext
                ?: appContext.currentActivity?.applicationContext
                ?: throw Exceptions.ReactContextLost()

            ModelManager.getDownloadManager(context).downloadModel(modelId) { downloadedMb, totalMb, speedMbps ->
                mainHandler.post {
                    try {
                        sendEvent(
                            "onDownloadProgress", mapOf(
                                "modelId" to modelId,
                                "downloadedMb" to downloadedMb,
                                "totalMb" to totalMb,
                                "speedMbps" to speedMbps
                            )
                        )
                    } catch (e: Exception) {
                        Log.e("KrithaModule", "Failed to send download progress", e)
                    }
                }
            }
        }

        Function("pauseDownload") { modelId: String ->
            val context =
                appContext.reactContext ?: appContext.currentActivity?.applicationContext ?: return@Function false
            ModelManager.getDownloadManager(context).pauseDownload(modelId)
            true
        }

        Function("resumeDownload") { modelId: String ->
            val context =
                appContext.reactContext ?: appContext.currentActivity?.applicationContext ?: return@Function false
            ModelManager.getDownloadManager(context).resumeDownload(modelId)
            true
        }

        Function("cancelDownload") { modelId: String ->
            val context =
                appContext.reactContext ?: appContext.currentActivity?.applicationContext ?: return@Function false
            ModelManager.getDownloadManager(context).cancelDownload(modelId)
            true
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
    }
}