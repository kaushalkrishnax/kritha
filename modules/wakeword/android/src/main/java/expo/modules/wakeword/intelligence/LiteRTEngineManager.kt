package expo.modules.wakeword.intelligence

import android.util.Log
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal object LiteRTEngineManager {
    private var engine: Engine? = null
    private var currentModelPath: String? = null
    private var cleanupJob: Job? = null
    private val mutex = Mutex()
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    suspend fun getEngine(modelPath: String): Engine = mutex.withLock {
        cleanupJob?.cancel()
        
        if (engine != null && currentModelPath != modelPath) {
            Log.i("LiteRTEngineManager", "Unloading previous model: $currentModelPath")
            engine?.close()
            engine = null
        }
        
        if (engine == null) {
            Log.i("LiteRTEngineManager", "Loading model into engine: $modelPath")
            val config = EngineConfig(modelPath = modelPath)
            engine = Engine(config).apply { initialize() }
            currentModelPath = modelPath
        }
        
        return engine!!
    }

    suspend fun scheduleCleanup() = mutex.withLock {
        cleanupJob?.cancel()
        cleanupJob = scope.launch {
            delay(60_000) // 1 minute timeout
            mutex.withLock {
                if (engine != null) {
                    Log.i("LiteRTEngineManager", "Idle timeout reached (60s). Releasing resources: $currentModelPath")
                    engine?.close()
                    engine = null
                    currentModelPath = null
                }
            }
        }
    }

    fun close() {
        scope.launch {
            mutex.withLock {
                cleanupJob?.cancel()
                engine?.close()
                engine = null
                currentModelPath = null
            }
        }
    }
}
