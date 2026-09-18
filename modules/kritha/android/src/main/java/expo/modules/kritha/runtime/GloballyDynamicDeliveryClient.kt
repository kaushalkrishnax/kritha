package expo.modules.kritha.runtime

import expo.modules.kritha.tools.DeviceTools

import android.content.Context
import android.os.Build
import android.util.Log
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManager
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallManagerFactory
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallRequest
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionState
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallUpdatedListener
import com.jeppeman.globallydynamic.globalsplitinstall.GlobalSplitInstallSessionStatus
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

data class InstallState(
    val status: RuntimeStatus,
    val progress: Int? = null,
    val error: Throwable? = null
)

/**
 * Raised when the platform refuses to install split APKs until the user allows
 * Kritha to install unknown apps. Reported so the user can be sent to settings
 * instead of waiting on a session that will never finish.
 */
class InstallPermissionRequiredException(message: String) : IllegalStateException(message)

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
        private const val INSTALL_POLL_INTERVAL_MS = 500L
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
            manager?.installedModules.orEmpty()
                .any { installed -> RuntimeCatalog.isSameModuleName(installed, moduleName) } ||
                classpathContainsProvider(moduleName)
        } catch (t: Throwable) {
            Log.w(TAG, "Error checking installed modules for $moduleName", t)
            false
        }
    }

    /** Android only installs split APKs on behalf of the app when the user allows it. */
    fun canInstallPackages(): Boolean = DeviceTools.canInstallPackages(context)

    private fun requireInstallPermission() {
        if (!canInstallPackages()) {
            throw InstallPermissionRequiredException(
                "Android needs permission before Kritha can install runtime components. " +
                    "Allow installing unknown apps for Kritha in system settings and try again."
            )
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
                .filter { RuntimeCatalog.isSameModuleName(RuntimeCatalog.getModuleName(it), moduleName) }
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

        requireInstallPermission()

        val request = try {
            GlobalSplitInstallRequest.newBuilder()
                .addModule(moduleName)
                .build()
        } catch (t: Throwable) {
            throw IllegalStateException("Invalid install request for $moduleName: ${t.message}", t)
        }

        val states = Channel<InstallState>(Channel.CONFLATED)
        val registered = CompletableDeferred<Unit>()
        var lastStatus: RuntimeStatus? = null

        coroutineScope {
            val collector = launch {
                sessionStates(moduleName) { registered.complete(Unit) }
                    .collect { state -> states.send(state) }
            }

            try {
                registered.await()
                startInstall(mgr, request, moduleName)

                withTimeout(INSTALL_TIMEOUT_MS) {
                    while (true) {
                        if (isInstalled(moduleName)) return@withTimeout

                        val state = withTimeoutOrNull(INSTALL_POLL_INTERVAL_MS) { states.receive() }
                        if (state == null) continue

                        lastStatus = state.status
                        when (state.status) {
                            RuntimeStatus.INSTALLED, RuntimeStatus.READY -> return@withTimeout
                            RuntimeStatus.FAILED -> throw state.error
                                ?: IllegalStateException("Install of $moduleName failed")
                            RuntimeStatus.CANCELLED -> throw IllegalStateException("Install of $moduleName was cancelled")
                            RuntimeStatus.PERMISSION_REQUIRED -> throw InstallPermissionRequiredException(
                                "Android needs permission before Kritha can install $moduleName. " +
                                    "Allow installing unknown apps for Kritha in system settings and try again."
                            )
                            else -> Unit
                        }
                    }
                }
            } catch (t: TimeoutCancellationException) {
                throw IllegalStateException(
                    "Timed out waiting for $moduleName to finish installing" +
                        (lastStatus?.let { " (last status: ${it.name})" } ?: ""),
                    t,
                )
            } finally {
                collector.cancel()
            }
        }

        if (!isInstalled(moduleName)) {
            throw IllegalStateException(
                "Install session finished but $moduleName is not available"
            )
        }
    }

    private suspend fun startInstall(
        manager: GlobalSplitInstallManager,
        request: GlobalSplitInstallRequest,
        moduleName: String,
    ) {
        suspendCoroutine<Unit> { cont ->
            try {
                manager.startInstall(request)
                    .addOnSuccessListener { cont.resume(Unit) }
                    .addOnFailureListener { e -> cont.resumeWithException(e) }
            } catch (t: Throwable) {
                cont.resumeWithException(t)
            }
        }
        Log.i(TAG, "Started install session for $moduleName")
    }

    override fun observe(moduleName: String): Flow<InstallState> = sessionStates(moduleName)

    /**
     * [onRegistered] runs once the session listener is attached, so callers can
     * start an install knowing no state emitted in between can be missed.
     */
    private fun sessionStates(
        moduleName: String,
        onRegistered: () -> Unit = {},
    ): Flow<InstallState> = callbackFlow {
        val mgr = manager
        if (mgr == null) {
            val installed = isInstalled(moduleName)
            trySend(
                InstallState(
                    status = if (installed) RuntimeStatus.INSTALLED else RuntimeStatus.NOT_INSTALLED
                )
            )
            onRegistered()
            close()
            return@callbackFlow
        }

        val listener = GlobalSplitInstallUpdatedListener { state ->
            if (state.moduleNames().any { RuntimeCatalog.isSameModuleName(it, moduleName) }) {
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

        onRegistered()

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
            GlobalSplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION -> RuntimeStatus.PERMISSION_REQUIRED
            GlobalSplitInstallSessionStatus.INSTALLED -> RuntimeStatus.INSTALLED
            GlobalSplitInstallSessionStatus.FAILED -> RuntimeStatus.FAILED
            GlobalSplitInstallSessionStatus.CANCELED -> RuntimeStatus.CANCELLED
            else -> RuntimeStatus.NOT_INSTALLED
        }
    }
}
