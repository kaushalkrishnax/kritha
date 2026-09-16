package expo.modules.kritha.litert

import android.content.Context
import expo.modules.kritha.litert.llm.LiteRTLLM
import expo.modules.kritha.litert.llm.LiteRTLLMRequest
import expo.modules.kritha.litert.speech.SpeechRuntime
import expo.modules.kritha.litert.speech.Tokenizer
import expo.modules.kritha.litert.speech.SpeechModelManifest
import java.io.Closeable

/**
 * Single entry point for Kritha's local LiteRT stack.
 *
 * LLM requests go through LiteRT-LM. Ordinary .tflite models go through
 * LiteRT CompiledModel. Speech model semantics are supplied by speech adapters.
 */
class LiteRT(private val context: Context) : Closeable {
    val models = LiteRTRuntime(context)
    val speech = SpeechRuntime(context)
    val llm = LiteRTLLM(context)

    fun loadModel(
        descriptor: LiteRTModelDescriptor,
        options: LiteRTExecutionOptions = LiteRTExecutionOptions()
    ): LiteRTRuntime.LoadedModel = models.load(descriptor, options)

    fun loadSpeech(
        manifest: SpeechModelManifest,
        tokenizer: Tokenizer,
        options: LiteRTExecutionOptions = LiteRTExecutionOptions()
    ): Closeable {
        // SpeechRuntime owns its own LiteRTRuntime so adapters can be independently released.
        return speech.load(manifest, tokenizer)
    }

    suspend fun generate(
        request: LiteRTLLMRequest,
        onDelta: (String) -> Unit = {},
        onChannel: (String, String) -> Unit = { _, _ -> }
    ): String = llm.generate(request, onDelta, onChannel)

    override fun close() {
        speech.close()
        llm.close()
        models.close()
    }
}
