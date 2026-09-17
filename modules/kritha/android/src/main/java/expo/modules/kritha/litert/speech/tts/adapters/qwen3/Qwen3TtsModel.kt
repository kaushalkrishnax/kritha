package expo.modules.kritha.litert.speech.tts.adapters.qwen3

import com.google.ai.edge.litert.TensorBuffer
import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTModelDescriptor
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.LiteRTTask
import java.io.File
import java.util.Random

data class Qwen3TtsFrame(val codes: IntArray)

internal data class Qwen3TtsTalkerStep(
    val logits: FloatArray,
    val hidden: FloatArray,
)

data class Qwen3TtsTimings(
    val prefillMs: Long,
    val talkerMs: Long,
    val mtpMs: Long,
    val codecMs: Long,
) {
    val totalInferenceMs: Long get() = prefillMs + talkerMs + mtpMs + codecMs
}

data class Qwen3TtsEngineResult(
    val pcm: FloatArray,
    val sampleRate: Int,
    val channels: Int,
    val frames: Int,
    val timings: Qwen3TtsTimings,
)

fun interface Qwen3TtsProgress {
    fun onFrame(frameIndex: Int)
}

internal class Qwen3TtsTalker(
    runtime: LiteRTRuntime,
    modelFile: File,
    execution: LiteRTExecutionOptions,
) : AutoCloseable {
    private val kvNames = (0 until Qwen3TtsConfig.TALKER_LAYERS).flatMap {
        listOf("kv_cache_k_$it", "kv_cache_v_$it")
    }

    private val loaded = runtime.load(talkerDescriptor(modelFile), execution)

    private val prefill = loaded.session(Qwen3TtsConfig.PREFILL_SIGNATURE)
    private val decode = loaded.session(
        Qwen3TtsConfig.DECODE_SIGNATURE,
        inputNames = listOf("embeddings", "input_pos", "mask") + kvNames,
        outputNames = listOf("logits") + kvNames,
    )

    private val cacheA = kvNames.associateWith {
        decode.createOutputBuffer(it)
    }
    private val cacheB = kvNames.associateWith {
        decode.createOutputBuffer(it)
    }
    private var currentCache = cacheA

    private val embeddingsIn = decode.createInputBuffer("embeddings")
    private val inputPosIn = decode.createInputBuffer("input_pos")
    private val maskIn = decode.createInputBuffer("mask")
    private val logitsOut = decode.createOutputBuffer("logits")
    private val decodeMask = FloatArray(Qwen3TtsConfig.TALKER_CACHE) { Qwen3TtsConfig.NEGATIVE_INFINITY }

    fun prefill(prompt: Array<FloatArray>) {
        val p = prompt.size
        require(p in 1..Qwen3TtsConfig.TALKER_PREFILL_SIZE) {
            "Talker prefill requires 1..32 positions, got $p"
        }

        val embeddings = FloatArray(32 * Qwen3TtsConfig.HIDDEN)
        for (i in prompt.indices) {
            require(prompt[i].size == Qwen3TtsConfig.HIDDEN) { "Invalid prompt embedding size at $i" }
            System.arraycopy(prompt[i], 0, embeddings, i * Qwen3TtsConfig.HIDDEN, Qwen3TtsConfig.HIDDEN)
        }

        val mask = FloatArray(32 * Qwen3TtsConfig.TALKER_CACHE) { Qwen3TtsConfig.NEGATIVE_INFINITY }
        for (row in 0 until 32) {
            val allowed = minOf(row, p - 1) + 1
            for (col in 0 until allowed) mask[row * Qwen3TtsConfig.TALKER_CACHE + col] = 0f
        }

        val inputs = prefill.createInputBuffers()
        require(inputs.size == 59) { "Unexpected Talker prefill input count: ${inputs.size}" }
        try {
            inputs[0].writeFloat(embeddings)
            inputs[1].writeInt(IntArray(32) { it })
            inputs[2].writeFloat(mask)
            val zeroKv = FloatArray(8 * Qwen3TtsConfig.TALKER_CACHE * 128)
            for (i in 3 until inputs.size) inputs[i].writeFloat(zeroKv)

            prefill.run(inputs, cacheA.values.toList())
            currentCache = cacheA
        } finally {
            inputs.forEach { runCatching { it.close() } }
        }
    }

    fun decode(embedding: FloatArray, position: Int): Qwen3TtsTalkerStep {
        require(embedding.size == Qwen3TtsConfig.HIDDEN) { "Talker embedding must be 1024 floats" }
        require(position in 0 until Qwen3TtsConfig.TALKER_CACHE) {
            "Talker position $position is outside KV cache"
        }

        embeddingsIn.writeFloat(embedding)
        inputPosIn.writeInt(intArrayOf(position))
        java.util.Arrays.fill(decodeMask, Qwen3TtsConfig.NEGATIVE_INFINITY)
        for (col in 0..position) decodeMask[col] = 0f
        maskIn.writeFloat(decodeMask)

        val nextCache = if (currentCache === cacheA) cacheB else cacheA
        val inputs = LinkedHashMap<String, TensorBuffer>(3 + kvNames.size)
        inputs["embeddings"] = embeddingsIn
        inputs["input_pos"] = inputPosIn
        inputs["mask"] = maskIn
        for (name in kvNames) inputs[name] = currentCache.getValue(name)

        val outputs = LinkedHashMap<String, TensorBuffer>(1 + kvNames.size)
        outputs["logits"] = logitsOut
        for (name in kvNames) outputs[name] = nextCache.getValue(name)

        decode.runNamed(
            inputs = inputs,
            outputs = outputs,
            inputNames = listOf("embeddings", "input_pos", "mask") + kvNames,
            outputNames = listOf("logits") + kvNames,
        )
        currentCache = nextCache

        val logits = logitsOut.readFloat()
        require(logits.size >= Qwen3TtsConfig.CODEC_VOCAB + Qwen3TtsConfig.HIDDEN) {
            "Talker logits output is too small: ${logits.size}"
        }
        return Qwen3TtsTalkerStep(
            logits = logits.copyOfRange(0, Qwen3TtsConfig.CODEC_VOCAB),
            hidden = logits.copyOfRange(
                Qwen3TtsConfig.CODEC_VOCAB,
                Qwen3TtsConfig.CODEC_VOCAB + Qwen3TtsConfig.HIDDEN,
            ),
        )
    }

    override fun close() {
        cacheA.values.forEach { runCatching { it.close() } }
        cacheB.values.forEach { runCatching { it.close() } }
        runCatching { embeddingsIn.close() }
        runCatching { inputPosIn.close() }
        runCatching { maskIn.close() }
        runCatching { logitsOut.close() }
        prefill.close()
        decode.close()
        loaded.close()
    }

    private fun talkerDescriptor(file: File): LiteRTModelDescriptor {
        val kv = (0 until Qwen3TtsConfig.TALKER_LAYERS).flatMap {
            listOf("kv_cache_k_$it", "kv_cache_v_$it")
        }
        return LiteRTModelDescriptor(
            id = "${Qwen3TtsConfig.MODEL_ID}:talker:${file.name}",
            path = file.absolutePath,
            task = LiteRTTask.TEXT_TO_SPEECH,
            architecture = "qwen3-tts-talker",
            signature = Qwen3TtsConfig.DECODE_SIGNATURE,
            metadata = mapOf(
                "inputs" to (listOf("embeddings", "input_pos", "mask") + kv).joinToString(","),
                "outputs" to (listOf("logits") + kv).joinToString(","),
                "outputTypes" to (List(1 + kv.size) { "FLOAT" }).joinToString(","),
            ),
        )
    }
}

/** MTP wrapper: 16 positional decode steps produce 15 residual codes. */
internal class Qwen3TtsMtp(
    runtime: LiteRTRuntime,
    modelFile: File,
    execution: LiteRTExecutionOptions,
    private val embeddings: Qwen3TtsEmbeddings,
    private val sampler: Qwen3TtsSampling,
) : AutoCloseable {
    private val loaded = runtime.load(
        LiteRTModelDescriptor(
            id = "${Qwen3TtsConfig.MODEL_ID}:mtp:${modelFile.name}",
            path = modelFile.absolutePath,
            task = LiteRTTask.TEXT_TO_SPEECH,
            architecture = "qwen3-tts-mtp",
            signature = "",
        ),
        execution,
    )
    private val session = loaded.positionalSession()
    private val inputs = session.createInputBuffers()
    private val outputPing = session.createOutputBuffers()
    private val outputPong = session.createOutputBuffers()

    init {
        require(inputs.size == 5) { "Expected 5 MTP inputs, got ${inputs.size}" }
        require(outputPing.size == 3) { "Expected 3 MTP outputs, got ${outputPing.size}" }
        require(outputPong.size == 3) { "Expected 3 MTP outputs, got ${outputPong.size}" }
    }

    fun generate(
        hidden: FloatArray,
        semanticCode: Int,
        greedy: Boolean,
        random: Random,
    ): IntArray {
        require(hidden.size == Qwen3TtsConfig.HIDDEN) { "MTP hidden state must be 1024 floats" }
        require(semanticCode in 0 until Qwen3TtsConfig.CODEC_VOCAB) { "Invalid semantic code $semanticCode" }

        val zeroKv = FloatArray(Qwen3TtsConfig.MTP_LAYERS * 8 * Qwen3TtsConfig.MTP_CACHE * 128)
        inputs[3].writeFloat(zeroKv)
        inputs[4].writeFloat(zeroKv)

        var k = inputs[3]
        var v = inputs[4]
        var usePing = true
        val codes = IntArray(Qwen3TtsConfig.MTP_CODEBOOKS)
        val mask = FloatArray(Qwen3TtsConfig.MTP_CACHE) { Qwen3TtsConfig.NEGATIVE_INFINITY }

        for (t in 0 until Qwen3TtsConfig.MTP_INNER_STEPS) {
            val embedding = when {
                t == 0 -> hidden
                t == 1 -> embeddings.codecRow(semanticCode)
                else -> embeddings.mtpRow(t - 2, codes[t - 2])
            }

            inputs[0].writeFloat(embedding)
            inputs[1].writeInt(intArrayOf(t))
            mask[t] = 0f
            inputs[2].writeFloat(mask)

            val out = if (usePing) outputPing else outputPong
            session.run(
                listOf(inputs[0], inputs[1], inputs[2], k, v),
                listOf(out[0], out[1], out[2]),
            )

            if (t >= 1) {
                val allLogits = out[0].readFloat()
                val head = t - 1
                val begin = head * Qwen3TtsConfig.MTP_VOCAB
                require(begin + Qwen3TtsConfig.MTP_VOCAB <= allLogits.size) {
                    "MTP logits output is too small: ${allLogits.size}"
                }
                val logits = allLogits.copyOfRange(
                    begin,
                    begin + Qwen3TtsConfig.MTP_VOCAB,
                )
                codes[head] = sampler.sample(
                    logits = logits,
                    greedy = greedy,
                    random = random,
                    vocabLimit = Qwen3TtsConfig.MTP_VOCAB,
                    temperature = Qwen3TtsConfig.TEMPERATURE,
                    topK = Qwen3TtsConfig.TOP_K,
                )
            }

            k = out[1]
            v = out[2]
            usePing = !usePing
        }
        return codes
    }

    override fun close() {
        inputs.forEach { runCatching { it.close() } }
        outputPing.forEach { runCatching { it.close() } }
        outputPong.forEach { runCatching { it.close() } }
        session.close()
        loaded.close()
    }
}

/** Qwen3-TTS codec decoder: 64-frame windows with 25-frame left context. */
internal class Qwen3TtsCodec(
    runtime: LiteRTRuntime,
    modelFile: File,
    execution: LiteRTExecutionOptions,
) : AutoCloseable {
    private val loaded = runtime.load(
        LiteRTModelDescriptor(
            id = "${Qwen3TtsConfig.MODEL_ID}:codec:${modelFile.name}",
            path = modelFile.absolutePath,
            task = LiteRTTask.TEXT_TO_SPEECH,
            architecture = "qwen3-tts-codec",
            signature = "",
        ),
        execution,
    )
    private val session = loaded.positionalSession()
    private val inputs = session.createInputBuffers()
    private val outputs = session.createOutputBuffers()

    init {
        require(inputs.size == 1) { "Expected one codec input, got ${inputs.size}" }
        require(outputs.size >= 1) { "Codec produced no outputs" }
    }

    fun decode(frames: List<Qwen3TtsFrame>): FloatArray {
        if (frames.isEmpty()) return FloatArray(0)

        val pieces = ArrayList<FloatArray>()
        var index = 0
        while (index < frames.size) {
            val context = minOf(Qwen3TtsConfig.CODEC_CONTEXT, index)
            val end = minOf(
                index + Qwen3TtsConfig.CODEC_CHUNK - context,
                frames.size,
            )
            val count = end - (index - context)
            require(count <= Qwen3TtsConfig.CODEC_CHUNK) { "Codec chunk overflow" }

            val codes = IntArray(Qwen3TtsConfig.CODEBOOKS * Qwen3TtsConfig.CODEC_CHUNK)
            for (t in 0 until count) {
                val frame = frames[index - context + t].codes
                require(frame.size == Qwen3TtsConfig.CODEBOOKS) {
                    "Qwen3 codec frame must contain 16 codes"
                }
                for (codebook in 0 until Qwen3TtsConfig.CODEBOOKS) {
                    codes[codebook * Qwen3TtsConfig.CODEC_CHUNK + t] = frame[codebook]
                }
            }

            inputs[0].writeInt(codes)
            session.run(inputs, outputs)
            val waveform = outputs[0].readFloat()
            val start = context * Qwen3TtsConfig.CODEC_SAMPLES_PER_FRAME
            val stop = count * Qwen3TtsConfig.CODEC_SAMPLES_PER_FRAME
            require(stop <= waveform.size) {
                "Codec waveform output ${waveform.size} is smaller than expected $stop"
            }
            pieces += waveform.copyOfRange(start, stop)
            index = end
        }

        val total = pieces.sumOf { it.size }
        val result = FloatArray(total)
        var offset = 0
        for (piece in pieces) {
            System.arraycopy(piece, 0, result, offset, piece.size)
            offset += piece.size
        }
        return result
    }

    override fun close() {
        inputs.forEach { runCatching { it.close() } }
        outputs.forEach { runCatching { it.close() } }
        session.close()
        loaded.close()
    }
}
