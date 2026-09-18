package expo.modules.kritha.runtime

import android.content.Context
import android.util.Log
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManager
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManagerFactory
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallRequest
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionState
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallUpdatedListener
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionStatus
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeout
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
        private const val INSTALL_TIMEOUT_MS = 15 * 60 * 1000L
    }

    private val manager: GlobalSplitInstallManager? by lazy {
        try {
            GlobalSplitInstallManagerFactory.create(context).also {
                Log.i(TAG, "GloballyDynamic self-hosted delivery client ready")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to initialize GlobalSplitInstallManager, falling back to classpath inspection", t)
            null
        }
    }

    override fun isInstalled(moduleName: String): Boolean {
        return try {
            manager?.installedModules?.contains(moduleName) == true ||
                classpathContainsProvider(moduleName)
        } catch (t: Throwable) {
            Log.w(TAG, "Error checking installed modules for $moduleName", t)
            false
        }
    }

    /**
     * Detects a feature that is present in the current classpath (e.g. bundled
     * splits) without knowing feature implementation class names. Relying on the
     * feature's META-INF/services registration keeps the base decoupled from the
     * feature packages.
     */
    private fun classpathContainsProvider(moduleName: String): Boolean {
        return try {
            RuntimeCatalog.allIds()
                .filter { RuntimeCatalog.getModuleName(it) == moduleName }
                .any { runtime ->
                    loadRuntimeProviders(runtime, context.classLoader).any()
                }
        } catch (_: Throwable) {
            false
        }
    }

    override suspend fun install(moduleName: String) {
        if (isInstalled(moduleName)) {
            return
        }

        val mgr = manager
            ?: throw IllegalStateException(
                "Dynamic delivery manager is not available to install $moduleName. " +
                    "Check that the GloballyDynamic self-hosted backend is configured " +
                    "(GLOBALLY_DYNAMIC_SERVER_URL pointing at the /download endpoint)."
            )

        val request = try {
            GlobalSplitInstallRequest.newBuilder()
                .addModule(moduleName)
                .build()
        } catch (t: Throwable) {
            throw IllegalStateException("Invalid install request for $moduleName: ${t.message}", t)
        }

        suspendCoroutine<Unit> { cont ->
            try {
                mgr.startInstall(request)
                    .addOnSuccessListener { cont.resume(Unit) }
                    .addOnFailureListener { e -> cont.resumeWithException(e) }
            } catch (t: Throwable) {
                cont.resumeWithException(t)
            }
        }
        Log.i(TAG, "Started install session for $moduleName")

        val terminal = try {
            withTimeout(INSTALL_TIMEOUT_MS) {
                observe(moduleName).first { state ->
                    state.status == RuntimeStatus.INSTALLED ||
                        state.status == RuntimeStatus.FAILED ||
                        state.status == RuntimeStatus.CANCELLED
                }
            }
        } catch (t: TimeoutCancellationException) {
            throw IllegalStateException("Install of $moduleName timed out waiting for completion", t)
        }

        when (terminal.status) {
            RuntimeStatus.FAILED -> throw terminal.error
                ?: IllegalStateException("Install of $moduleName failed")
            RuntimeStatus.CANCELLED -> throw IllegalStateException("Install of $moduleName was cancelled")
            else -> Unit
        }

        if (!isInstalled(moduleName)) {
            throw IllegalStateException(
                "Install session finished but $moduleName is not available"
            )
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
                val status = mapSessionStatus(state)
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

    private fun mapSessionStatus(state: GlobalSplitInstallSessionState): RuntimeStatus {
        return when (state.status()) {
            GlobalSplitInstallSessionStatus.PENDING -> RuntimeStatus.CHECKING
            GlobalSplitInstallSessionStatus.DOWNLOADING -> RuntimeStatus.INSTALLING
            GlobalSplitInstallSessionStatus.DOWNLOADED -> RuntimeStatus.INSTALLING
            GlobalSplitInstallSessionStatus.INSTALLING -> RuntimeStatus.INSTALLING
            GlobalSplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION -> RuntimeStatus.INSTALLING
            GlobalSplitInstallSessionStatus.INSTALLED -> RuntimeStatus.INSTALLED
            GlobalSplitInstallSessionStatus.FAILED -> RuntimeStatus.FAILED
            GlobalSplitInstallSessionStatus.CANCELED -> RuntimeStatus.CANCELLED
            else -> RuntimeStatus.NOT_INSTALLED
        }
    }
}
