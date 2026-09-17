package expo.modules.kritha.litert.speech.tts.adapters

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.speech.tts.TtsAdapter
import expo.modules.kritha.litert.speech.tts.TtsModelAssets
import expo.modules.kritha.litert.speech.tts.TtsModelId
import expo.modules.kritha.litert.speech.tts.TtsModelSpec
import expo.modules.kritha.litert.speech.tts.adapters.kitten.KittenTtsProvider
import expo.modules.kritha.litert.speech.tts.adapters.qwen3.Qwen3TtsProvider
import java.io.File

/** Construction contract every TTS model family implements. */
interface TtsAdapterProvider {
    val spec: TtsModelSpec

    fun matches(modelId: TtsModelId): Boolean = modelId.value == spec.id.value

    fun create(
        runtime: LiteRTRuntime,
        assets: TtsModelAssets,
        execution: LiteRTExecutionOptions = LiteRTExecutionOptions(),
    ): TtsAdapter

    fun voiceIndex(voice: String?): Int = 0

    fun finishDownload(modelDir: File) {}
}

/** Adapter composition layer — only place that names concrete model families. */
object TtsAdapterRegistry {
    private val providers: List<TtsAdapterProvider> = listOf(
        Qwen3TtsProvider,
        KittenTtsProvider,
    )

    fun allSpecs(): List<TtsModelSpec> = providers.map { it.spec }

    fun providerFor(modelId: TtsModelId): TtsAdapterProvider =
        providers.firstOrNull { it.matches(modelId) }
            ?: error("No TTS adapter registered for model: ${modelId.value}")

    fun create(
        runtime: LiteRTRuntime,
        assets: TtsModelAssets,
        execution: LiteRTExecutionOptions = LiteRTExecutionOptions(),
    ): TtsAdapter = providerFor(assets.modelId).create(runtime, assets, execution)
}
