package expo.modules.kritha.intelligence

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Manages a single LiteRT-LM Engine instance across the app.
 *
 * Key design decisions (based on LiteRT-LM best practices):
 *  - Only ONE model loaded in memory at a time (enforced by mutex).
 *  - Engine.initialize() is expensive (~10s), so we cache and reuse the instance.
 *  - A 90-second idle TTL releases the engine to free RAM when not in use.
 *  - GPU/NPU are user-configurable but CPU is the safe default.
 *  - On model switch the old engine is closed before loading the new one.
 */
internal object LiteRTEngineManager {

    enum class Device { CPU, GPU, NPU;
        companion object {
            fun from(value: String?): Device = when (value?.lowercase()) {
                "gpu" -> GPU
                "npu" -> NPU
                else  -> CPU
            }
        }
    }

    private const val PREFS          = "kritha_intelligence"
    private const val KEY_DEVICE     = "local_model_device"
    private const val IDLE_TTL_MS    = 90_000L
    private const val TAG            = "LiteRTEngineManager"

    private val mutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var engine: Engine?      = null
    private var loadedModelPath: String? = null
    private var loadedDevice: Device?    = null
    private var idleJob: Job?            = null

    // Device preference

    fun getDevice(context: Context): Device =
        Device.from(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_DEVICE, null))

    fun setDevice(context: Context, device: Device) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_DEVICE, device.name.lowercase()).apply()
        // Invalidate cached engine so next call re-initialises on the new backend
        scope.launch { mutex.withLock { releaseEngine() } }
    }

    // Engine access (the only hot path) 

    /**
     * Returns a ready-to-use [Engine] for the given model path and device.
     *
     * Thread-safe: concurrent callers wait behind the mutex; only one
     * initialization ever runs at a time.
     */
    suspend fun getEngine(modelPath: String, device: Device): Engine = mutex.withLock {
        cancelIdleTimer()

        // If model or backend changed, release the old engine first
        if (engine != null && (loadedModelPath != modelPath || loadedDevice != device)) {
            Log.i(TAG, "Model/device changed — releasing engine ($loadedModelPath / $loadedDevice)")
            releaseEngine()
        }

        // Re-use cached engine if still valid
        engine?.let { return@withLock it }

        Log.i(TAG, "Initialising engine: $modelPath on ${device.name}")
        val created = buildEngine(modelPath, device)
        engine           = created
        loadedModelPath  = modelPath
        loadedDevice     = device
        created
    }

    /** Release resources immediately (e.g. on app destroy or model switch). */
    fun close() {
        scope.launch { mutex.withLock { cancelIdleTimer(); releaseEngine() } }
    }

    /** Start idle TTL countdown. Call after inference finishes. */
    fun startIdleTimer() {
        idleJob?.cancel()
        idleJob = scope.launch {
            delay(IDLE_TTL_MS)
            mutex.withLock {
                if (engine != null) {
                    Log.i(TAG, "Idle TTL reached — releasing engine to free RAM")
                    releaseEngine()
                }
            }
        }
    }

    // Private helpers

    private fun cancelIdleTimer() { idleJob?.cancel(); idleJob = null }

    private fun releaseEngine() {
        engine?.runCatching { close() }
        engine           = null
        loadedModelPath  = null
        loadedDevice     = null
    }

    /**
     * Builds and initialises an [Engine].
     * Falls back to CPU if the preferred backend fails.
     */
    private fun buildEngine(modelPath: String, preferredDevice: Device): Engine {
        return try {
            val backend = when (preferredDevice) {
                Device.CPU -> Backend.CPU()
                Device.GPU -> Backend.GPU()
                Device.NPU -> Backend.NPU(System.getProperty("java.library.path") ?: "")
            }
            Engine(EngineConfig(modelPath = modelPath, backend = backend)).also { it.initialize() }
        } catch (e: Exception) {
            Log.w(TAG, "Failed on ${preferredDevice.name}, falling back to CPU", e)
            if (preferredDevice != Device.CPU) {
                Engine(EngineConfig(modelPath = modelPath, backend = Backend.CPU())).also { it.initialize() }
            } else throw e
        }
    }
}
