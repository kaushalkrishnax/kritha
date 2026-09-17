package expo.modules.kritha.litert.speech.tts

import expo.modules.kritha.runtime.tts.*
import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.speech.tts.adapters.TtsAdapterRegistry
import java.io.Closeable

/** Model-family behavior lives in [TtsAdapter] implementations. */
class Tts(
    private val runtime: LiteRTRuntime,
    private val executionOptions: LiteRTExecutionOptions = LiteRTExecutionOptions(),
) : Closeable, TtsProvider {
    private val adapters = mutableMapOf<TtsModelId, TtsAdapter>()

    @Synchronized
    override fun getAvailableSpecs(): List<TtsModelSpec> = TtsAdapterRegistry.allSpecs()

    override fun finishDownload(modelDir: java.io.File, modelId: String) {
        val provider = TtsAdapterRegistry.providerFor(TtsModelId(modelId))
        provider.finishDownload(modelDir)
    }

    @Synchronized
    override fun synthesize(
        model: TtsModelAssets,
        text: String,
        options: SynthesisOptions,
    ): SynthesisResult {
        require(text.isNotBlank()) { "TTS text cannot be blank" }
        return adapterFor(model).synthesize(text, options)
    }

    @Synchronized
    private fun adapterFor(assets: TtsModelAssets): TtsAdapter =
        adapters.getOrPut(assets.modelId) {
            TtsAdapterRegistry.create(runtime, assets, executionOptions)
        }

    override fun release(modelId: TtsModelId) {
        synchronized(this) {
            val adapter = adapters.remove(modelId)
            if (adapter != null) runCatching { adapter.close() }
        }
    }

    override fun releaseAll() {
        synchronized(this) {
            adapters.values.forEach { runCatching { it.close() } }
            adapters.clear()
        }
    }

    override fun close() {
        releaseAll()
    }
}
