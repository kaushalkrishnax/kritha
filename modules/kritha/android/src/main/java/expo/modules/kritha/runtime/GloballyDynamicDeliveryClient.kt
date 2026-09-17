package expo.modules.kritha.runtime

import android.content.Context
import android.util.Log
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManager
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManagerFactory
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallRequest
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionState
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallUpdatedListener
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionStatus
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

data class InstallState(
    val status: RuntimeStatus,
    val progress: Int? = null,
    val error: Throwable? = null
)

interface DynamicDeliveryClient {
    fun isInstalled(moduleName: String): Boolean
    suspend fun install(moduleName: String)
    fun observe(moduleName: String): Flow<InstallState>
}

class GloballyDynamicDeliveryClient(
    private val context: Context
) : DynamicDeliveryClient {

    companion object {
        private const val TAG = "GloballyDynamicDelivery"

        private val MODULE_PROPRIETARY_CLASSES = mapOf(
            "feature-litert" to "expo.modules.kritha.litert.LiteRTRuntimeProvider",
            "feature-litertlm" to "expo.modules.kritha.litertlm.LiteRTLLMRuntimeProvider",
            "feature-onnx" to "expo.modules.kritha.onnx.OnnxRuntimeProvider"
        )
    }

    private val manager: GlobalSplitInstallManager? by lazy {
        try {
            GlobalSplitInstallManagerFactory.create(context)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to initialize GlobalSplitInstallManager, falling back to classpath inspection", t)
            null
        }
    }

    override fun isInstalled(moduleName: String): Boolean {
        // 1. Check if the module is already present in classloader
        val className = MODULE_PROPRIETARY_CLASSES[moduleName]
        if (className != null) {
            try {
                Class.forName(className, false, context.classLoader)
                return true
            } catch (_: ClassNotFoundException) {
                // Not in classpath yet
            } catch (_: Throwable) {
                // Ignore other classloading issues
            }
        }

        // 2. Check dynamic install manager if available
        return try {
            manager?.installedModules?.contains(moduleName) == true
        } catch (t: Throwable) {
            Log.w(TAG, "Error checking installed modules for $moduleName", t)
            false
        }
    }

    override suspend fun install(moduleName: String): Unit = suspendCoroutine { cont ->
        if (isInstalled(moduleName)) {
            cont.resume(Unit)
            return@suspendCoroutine
        }

        val mgr = manager
        if (mgr == null) {
            cont.resumeWithException(
                IllegalStateException("Dynamic delivery manager is not available to install $moduleName")
            )
            return@suspendCoroutine
        }

        try {
            val request = GlobalSplitInstallRequest.newBuilder()
                .addModule(moduleName)
                .build()

            mgr.startInstall(request)
                .addOnSuccessListener {
                    cont.resume(Unit)
                }
                .addOnFailureListener { e ->
                    cont.resumeWithException(e)
                }
        } catch (t: Throwable) {
            cont.resumeWithException(t)
        }
    }

    override fun observe(moduleName: String): Flow<InstallState> = callbackFlow {
        val mgr = manager
        if (mgr == null) {
            val installed = isInstalled(moduleName)
            trySend(
                InstallState(
                    status = if (installed) RuntimeStatus.INSTALLED else RuntimeStatus.NOT_INSTALLED
                )
            )
            close()
            return@callbackFlow
        }

        val listener = GlobalSplitInstallUpdatedListener { state ->
            if (state.moduleNames().contains(moduleName)) {
                val status = when (state.status()) {
                    GlobalSplitInstallSessionStatus.PENDING -> RuntimeStatus.CHECKING
                    GlobalSplitInstallSessionStatus.DOWNLOADING -> RuntimeStatus.INSTALLING
                    GlobalSplitInstallSessionStatus.DOWNLOADED -> RuntimeStatus.INSTALLING
                    GlobalSplitInstallSessionStatus.INSTALLING -> RuntimeStatus.INSTALLING
                    GlobalSplitInstallSessionStatus.INSTALLED -> RuntimeStatus.INSTALLED
                    GlobalSplitInstallSessionStatus.FAILED -> RuntimeStatus.FAILED
                    GlobalSplitInstallSessionStatus.CANCELED -> RuntimeStatus.CANCELLED
                    else -> RuntimeStatus.NOT_INSTALLED
                }
                
                val progress = if (state.totalBytesToDownload() > 0) {
                    ((state.bytesDownloaded() * 100) / state.totalBytesToDownload()).toInt()
                } else null

                trySend(
                    InstallState(
                        status = status,
                        progress = progress,
                        error = if (status == RuntimeStatus.FAILED) Exception("Install error code: ${state.errorCode()}") else null
                    )
                )
            }
        }
        
        try {
            mgr.registerListener(listener)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to register listener for $moduleName", t)
        }

        awaitClose {
            try {
                mgr.unregisterListener(listener)
            } catch (_: Throwable) {}
        }
    }
}
