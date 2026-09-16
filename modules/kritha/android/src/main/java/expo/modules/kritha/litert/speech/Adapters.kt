package expo.modules.kritha.litert.speech

import expo.modules.kritha.litert.*
import kotlin.math.ln
import kotlin.math.exp

/**
 * Common CTC decoder. It is useful for CTC ASR models such as Parakeet-CTC and
 * other models that expose a [time, vocab] logits tensor.
 */
class CtcAsrAdapter(
    private val runtime: LiteRTRuntime,
    private val manifest: SpeechModelManifest,
    execution: LiteRTExecutionOptions,
    private val tokenizer: Tokenizer,
) : AsrAdapter {
    private val model = runtime.load(
        LiteRTModelDescriptor(
            id = manifest.id,
            path = manifest.modelPath,
            task = LiteRTTask.ASR,
            architecture = manifest.architecture,
            signature = manifest.signature,
            metadata = mapOf(
                "inputs" to manifest.inputNames.joinToString(","),
                "outputs" to manifest.outputNames.joinToString(","),
                "outputTypes" to manifest.outputTypes.joinToString(","),
            )
        ),
        execution
    )

    override fun transcribe(audio: FloatArray, options: TranscriptionOptions): Transcription {
        val start = System.nanoTime()
        val prepared = prepareAudio(audio)
        val result = model.runNamed(
            mapOf(manifest.inputNames.first() to prepared),
            manifest.signature
        )
        val logits = result.outputs.first().data as FloatArray
        val vocab = logits.size / timeSteps(logits)
        val ids = IntArray(timeSteps(logits)) { t ->
            var best = 0
            var score = Float.NEGATIVE_INFINITY
            for (v in 0 until vocab) {
                val value = logits[t * vocab + v]
                if (value > score) { score = value; best = v }
            }
            best
        }
        val blank = manifest.metadata["blankId"]?.toIntOrNull() ?: 0
        val collapsed = IntArray(ids.size)
        var n = 0
        var previous = -1
        for (id in ids) {
            if (id != blank && id != previous) collapsed[n++] = id
            previous = id
        }
        val text = tokenizer.decode(collapsed.copyOf(n))
        return Transcription(
            text = text,
            tokenIds = collapsed.copyOf(n),
            elapsedMs = (System.nanoTime() - start) / 1_000_000
        )
    }

    private fun prepareAudio(audio: FloatArray): FloatArray {
        return if (manifest.mel != null) {
            Audio.logMel(audio, manifest.audio.sampleRate, manifest.mel)
        } else {
            audio
        }
    }

    private fun timeSteps(logits: FloatArray): Int {
        val configured = manifest.metadata["timeSteps"]?.toIntOrNull()
        return configured ?: error(
            "CTC model ${manifest.id} requires metadata.timeSteps because LiteRT does not " +
                "expose arbitrary semantic dimensions through the high-level Kotlin API."
        )
    }

    override fun close() = model.close()
}

/**
 * Encoder-decoder ASR adapter for Whisper/Moonshine-style graphs.
 *
 * The model must expose an encoder and decoder signature and a tokenizer. The
 * manifest carries the graph names and token IDs. This keeps the inference
 * engine generic while the model-family contract stays explicit.
 */
class Seq2SeqAsrAdapter(
    private val runtime: LiteRTRuntime,
    private val manifest: SpeechModelManifest,
    execution: LiteRTExecutionOptions,
    private val tokenizer: Tokenizer,
) : AsrAdapter {
    private val model = runtime.load(
        LiteRTModelDescriptor(
            id = manifest.id,
            path = manifest.modelPath,
            task = LiteRTTask.ASR,
            architecture = manifest.architecture,
            signature = manifest.signature,
            metadata = mapOf(
                "inputs" to manifest.inputNames.joinToString(","),
                "outputs" to manifest.outputNames.joinToString(","),
                "outputTypes" to manifest.outputTypes.joinToString(","),
            )
        ),
        execution
    )

    override fun transcribe(audio: FloatArray, options: TranscriptionOptions): Transcription {
        val start = System.nanoTime()
        val features = if (manifest.mel != null) {
            Audio.logMel(audio, manifest.audio.sampleRate, manifest.mel)
        } else audio

        val encode = model.runNamed(
            mapOf(manifest.inputNames.first() to features),
            manifest.metadata["encoderSignature"] ?: manifest.signature
        )
        val encoded = encode.outputs.map { it.data }.toTypedArray()

        val startToken = manifest.startTokenId
            ?: error("Seq2Seq ASR requires startTokenId")
        val stopToken = manifest.stopTokenId ?: -1
        val maxTokens = options.maxTokens ?: manifest.maxDecodeTokens

        val tokens = IntArray(maxTokens)
        tokens[0] = startToken
        var count = 1

        while (count < maxTokens) {
            val tokenIds = tokens.copyOf(count)
            val decoderInputName = manifest.metadata["decoderInput"]
                ?: error("Seq2Seq ASR requires metadata.decoderInput")

            val inputMap = linkedMapOf<String, Any>()
            inputMap[decoderInputName] = tokenIds

            manifest.metadata["decoderExtraInputs"]
                ?.split(',')
                ?.filter { it.isNotBlank() }
                ?.forEach { key ->
                    val value = manifest.metadata["decoderExtra.$key"]
                        ?: error("Missing decoderExtra.$key")
                    inputMap[key] = value.split(',').map { it.trim().toFloat() }.toFloatArray()
                }

            val output = model.runNamed(
                inputMap,
                manifest.metadata["decoderSignature"] ?: manifest.signature
            )
            val logits = output.outputs.first().data as FloatArray
            val vocab = manifest.metadata["vocabSize"]?.toIntOrNull()
                ?: error("Seq2Seq ASR requires vocabSize")
            val offset = (count - 1) * vocab
            var best = 0
            var score = Float.NEGATIVE_INFINITY
            for (v in 0 until vocab) {
                val s = logits.getOrElse(offset + v) { Float.NEGATIVE_INFINITY }
                if (s > score) { score = s; best = v }
            }
            tokens[count++] = best
            if (best == stopToken) break
        }

        return Transcription(
            text = tokenizer.decode(tokens.copyOf(count)),
            tokenIds = tokens.copyOf(count),
            elapsedMs = (System.nanoTime() - start) / 1_000_000
        )
    }

    override fun close() = model.close()
}

/**
 * Generic single-graph TTS adapter. Model-specific tokenisation is deliberately
 * injected instead of hardcoded into the runtime.
 */
class SingleGraphTtsAdapter(
    private val runtime: LiteRTRuntime,
    private val manifest: SpeechModelManifest,
    execution: LiteRTExecutionOptions,
    private val tokenizer: Tokenizer,
) : TtsAdapter {
    private val model = runtime.load(
        LiteRTModelDescriptor(
            id = manifest.id,
            path = manifest.modelPath,
            task = LiteRTTask.TTS,
            architecture = manifest.architecture,
            signature = manifest.signature,
            metadata = mapOf(
                "inputs" to manifest.inputNames.joinToString(","),
                "outputs" to manifest.outputNames.joinToString(","),
                "outputTypes" to manifest.outputTypes.joinToString(","),
            )
        ),
        execution
    )

    override fun synthesize(text: String, options: SynthesisOptions): SynthesisResult {
        val start = System.nanoTime()
        val ids = tokenizer.encode(text)
        val inputs = linkedMapOf<String, Any>()
        inputs[manifest.inputNames.first()] = ids
        manifest.metadata["voiceInput"]?.let { inputs[it] = intArrayOf(options.voice) }
        manifest.metadata["speedInput"]?.let { inputs[it] = floatArrayOf(options.speed) }

        val result = model.runNamed(inputs, manifest.signature)
        val audio = result.outputs.first().data as FloatArray
        return SynthesisResult(
            SpeechAudio(audio, manifest.metadata["sampleRate"]?.toIntOrNull() ?: 24000),
            (System.nanoTime() - start) / 1_000_000
        )
    }

    override fun close() = model.close()
}

