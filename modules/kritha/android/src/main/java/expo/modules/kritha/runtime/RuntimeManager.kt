package expo.modules.kritha.runtime

import android.content.Context
import kotlinx.coroutines.flow.Flow
import java.util.ServiceLoader

class RuntimeManager(private val context: Context) {
    private val client: DynamicDeliveryClient = GloballyDynamicDeliveryClient(context)
    private val cachedProviders = mutableMapOf<RuntimeId, RuntimeProvider>()

    fun isInstalled(runtime: RuntimeId): Boolean {
        val moduleName = RuntimeCatalog.getModuleName(runtime)
        return client.isInstalled(moduleName)
    }

    suspend fun ensureInstalled(runtime: RuntimeId): RuntimeProvider {
        val cached = cachedProviders[runtime]
        if (cached != null) return cached

        val moduleName = RuntimeCatalog.getModuleName(runtime)
        if (!client.isInstalled(moduleName)) {
            client.install(moduleName)
        }

        val provider = discoverProvider(runtime)
            ?: throw IllegalStateException("Provider for $runtime not found after installation")
            
        cachedProviders[runtime] = provider
        return provider
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
        // Because of dynamic modules, we need to load using the context class loader
        // or the class loader of a class from the dynamic module. However, ServiceLoader
        // handles it if it's in the merged classpath (which dynamic features are after install).
        val serviceLoader = ServiceLoader.load(RuntimeProvider::class.java, context.classLoader)
        for (provider in serviceLoader) {
            if (provider.id == runtime) {
                provider.initialize(context)
                return provider
            }
        }
        return null
    }

    fun release(runtime: RuntimeId) {
        // Feature delivery does not typically unload easily at runtime on Android
        // but we can clear our cache.
        cachedProviders.remove(runtime)
    }
}
