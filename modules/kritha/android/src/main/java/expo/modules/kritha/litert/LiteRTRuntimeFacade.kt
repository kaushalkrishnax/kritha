package expo.modules.kritha.litert

import android.content.Context
import expo.modules.kritha.litert.llm.LiteRTLLM
import expo.modules.kritha.litert.llm.LiteRTLLMRequest
import expo.modules.kritha.litert.speech.tts.SynthesisOptions
import expo.modules.kritha.litert.speech.tts.SynthesisResult
import expo.modules.kritha.litert.speech.tts.Tts
import expo.modules.kritha.litert.speech.tts.TtsModelAssets
import expo.modules.kritha.litert.speech.tts.TtsModelId
import java.io.Closeable

/** Single entry point for Kritha's native local inference stack. */
class LiteRT(private val context: Context) : Closeable {
    val models = LiteRTRuntime(context)
    val tts = Tts(models)
    val llm = LiteRTLLM(context)

    fun loadModel(
        descriptor: LiteRTModelDescriptor,
        options: LiteRTExecutionOptions = LiteRTExecutionOptions()
    ): LiteRTRuntime.LoadedModel = models.load(descriptor, options)

    fun synthesizeTts(
        model: TtsModelAssets,
        text: String,
        options: SynthesisOptions = SynthesisOptions(),
    ): SynthesisResult = tts.synthesize(model, text, options)

    /** Free the TTS adapter for [modelId] (graphs, KV caches, buffers) to return memory to the system. */
    fun releaseTts(modelId: TtsModelId) = tts.release(modelId)

    suspend fun generate(
        request: LiteRTLLMRequest,
        onDelta: (String) -> Unit = {},
        onChannel: (String, String) -> Unit = { _, _ -> }
    ): String = llm.generate(request, onDelta, onChannel)

    override fun close() {
        tts.close()
        llm.close()
        models.close()
    }
}
