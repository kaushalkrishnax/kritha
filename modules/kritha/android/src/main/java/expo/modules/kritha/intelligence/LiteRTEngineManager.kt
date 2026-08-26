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

internal object LiteRTEngineManager {

    enum class Device {
        CPU, GPU, NPU;

        companion object {
            fun from(value: String?): Device = when (value?.lowercase()) {
                "gpu" -> GPU
                "npu" -> NPU
                else -> CPU
            }
        }
    }

    private const val PREFS = "kritha_intelligence"
    private const val KEY_DEVICE = "local_model_device"
    private const val IDLE_TTL_MS = 120_000L
    private const val TAG = "LiteRTEngineManager"

    private val mutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var engine: Engine? = null
    private var loadedModelPath: String? = null
    private var loadedDevice: Device? = null
    private var idleJob: Job? = null

    fun getDevice(context: Context): Device =
        Device.from(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_DEVICE, null)
        )

    fun setDevice(context: Context, device: Device) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_DEVICE, device.name.lowercase()).apply()
        scope.launch { mutex.withLock { releaseEngine() } }
    }

    suspend fun getEngine(modelPath: String, device: Device): Engine = mutex.withLock {
        cancelIdleTimer()

        if (engine != null && (loadedModelPath != modelPath || loadedDevice != device)) {
            Log.i(TAG, "Model/device changed — releasing engine ($loadedModelPath / $loadedDevice)")
            releaseEngine()
        }

        engine?.let { return@withLock it }

        Log.i(TAG, "Initialising engine: $modelPath on ${device.name}")
        val created = buildEngine(modelPath, device)
        engine = created
        loadedModelPath = modelPath
        loadedDevice = device
        created
    }

    fun close() {
        scope.launch { mutex.withLock { cancelIdleTimer(); releaseEngine() } }
    }

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

    private fun cancelIdleTimer() {
        idleJob?.cancel(); idleJob = null
    }

    private fun releaseEngine() {
        engine?.runCatching { close() }
        engine = null
        loadedModelPath = null
        loadedDevice = null
    }

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
