package expo.modules.kritha

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
    private val localLlmExecutor = LocalLlmExecutor()

    override fun definition() = ModuleDefinition {
        Name("Kritha")
        Events(
            "onWakeWordDetected",
            "onLocalLlmDelta",
        )

        Function("start") {
            WakeWordForegroundService.start(resolveContext())
        }

        Function("stop") {
            WakeWordForegroundService.stop(resolveContext())
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

    private fun resolveContext() = appContext.reactContext
        ?: appContext.currentActivity?.applicationContext
        ?: throw Exceptions.ReactContextLost()
}
