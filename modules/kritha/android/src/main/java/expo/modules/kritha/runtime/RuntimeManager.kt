package expo.modules.kritha.runtime

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap

class RuntimeManager(private val context: Context) {
    companion object {
        private const val TAG = "RuntimeManager"
    }

    private val client: DynamicDeliveryClient = GloballyDynamicDeliveryClient(context)
    private val cachedProviders = mutableMapOf<RuntimeId, RuntimeProvider>()
    private val installLocks = ConcurrentHashMap<RuntimeId, Mutex>()

    fun allRuntimes(): List<RuntimeId> = RuntimeCatalog.allIds()

    fun isInstalled(runtime: RuntimeId): Boolean {
        val moduleName = RuntimeCatalog.getModuleName(runtime)
        return client.isInstalled(moduleName)
    }

    suspend fun ensureInstalled(runtime: RuntimeId): RuntimeProvider {
        val cached = cachedProviders[runtime]
        if (cached != null) return cached

        val lock = installLocks.getOrPut(runtime) { Mutex() }
        return lock.withLock {
            val rechecked = cachedProviders[runtime]
            if (rechecked != null) return@withLock rechecked

            val moduleName = RuntimeCatalog.getModuleName(runtime)
            if (!client.isInstalled(moduleName)) {
                client.install(moduleName)
            }

            val provider = discoverProvider(runtime)
                ?: throw IllegalStateException("Provider for $runtime not found after installation")

            cachedProviders[runtime] = provider
            provider
        }
    }

    fun observeInstall(runtime: RuntimeId): Flow<InstallState> {
        return client.observe(RuntimeCatalog.getModuleName(runtime))
    }

    fun provider(runtime: RuntimeId): RuntimeProvider? {
        if (!isInstalled(runtime)) return null
        if (cachedProviders.containsKey(runtime)) return cachedProviders[runtime]
        
        val provider = discoverProvider(runtime)
        if (provider != null) {
            cachedProviders[runtime] = provider
        }
        return provider
    }

    private fun discoverProvider(runtime: RuntimeId): RuntimeProvider? {
        return try {
            val serviceLoader = loadRuntimeProviders(runtime, context.classLoader)
            for (provider in serviceLoader) {
                if (provider.id == runtime) {
                    provider.initialize(context)
                    return provider
                }
            }
            null
        } catch (t: Throwable) {
            Log.e(TAG, "Provider discovery error for $runtime", t)
            null
        }
    }

    fun release(runtime: RuntimeId) {
        cachedProviders.remove(runtime)
    }
}
