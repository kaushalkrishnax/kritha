package expo.modules.kritha.litert.speech.tts.adapters.kitten

import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTModelDescriptor
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.LiteRTTask
import java.io.Closeable
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import org.tensorflow.lite.Interpreter

/**
 * Host-side KittenTTS nano 0.8 orchestration (G2P → predictor → duration repeat → prosody → vocoder).
 *
 * Predictor/prosody/vocoder use the classic Interpreter API because the official converted
 * predictor/prosody graphs contain variable LSTM state, while LiteRT still owns the
 * CompiledModel-based G2P graph.
 */
internal class KittenTtsEngine(
    private val runtime: LiteRTRuntime,
    private val assets: KittenTtsAssets,
    execution: LiteRTExecutionOptions,
) : Closeable {

    private val closed = AtomicBoolean(false)
    private val lock = Any()

    private val predictor = Interpreter(
        assets.predictor(),
        Interpreter.Options().apply {
            // The converted Kitten graphs carry variable LSTM state and are
            // resized per call; XNNPack cannot prepare/reshape them.
            setUseXNNPACK(false)
            setNumThreads(execution.cpuThreads ?: KittenTtsConfig.NUM_THREADS)
        },
    )

    private val prosody = Interpreter(
        assets.prosody(),
        Interpreter.Options().apply {
            setUseXNNPACK(false)
            setNumThreads(execution.cpuThreads ?: KittenTtsConfig.NUM_THREADS)
        },
    )

    private val vocoder = Interpreter(
        assets.vocoder(),
        Interpreter.Options().apply {
            setUseXNNPACK(false)
            setNumThreads(execution.cpuThreads ?: KittenTtsConfig.NUM_THREADS)
        },
    )

    private val g2p = KittenTtsG2p(
        runtime = runtime,
        assets = assets,
        execution = execution,
    )

    private val voiceTable: FloatArray = loadVoiceTable()

    init {
        require(execution.device.name == "CPU") {
            "KittenTTS nano 0.8 uses the validated CPU LiteRT/TFLite path only"
        }
    }

    fun synthesize(
        text: String,
        voice: Int,
        speed: Float,
    ): KittenTtsEngineResult = synchronized(lock) {
        check(!closed.get()) { "KittenTTS engine is closed" }
        require(text.isNotBlank()) { "KittenTTS text cannot be blank" }
        require(voice in 0 until KittenTtsConfig.VOICE_COUNT) { "Invalid voice index: $voice" }
        require(speed > 0f && speed.isFinite()) { "Invalid speed: $speed" }

        val started = System.nanoTime()
        val chunks = KittenTtsSentenceChunker.chunk(text)
        require(chunks.isNotEmpty()) { "KittenTTS sentence chunker produced no text" }

        val audioPieces = ArrayList<FloatArray>(chunks.size)
        var totalTokens = 0
        var totalFrames = 0

        for (chunk in chunks) {
            val symbolIds = g2p.phonemize(chunk)
            require(symbolIds.isNotEmpty()) {
                "KittenTTS G2P produced no StyleTTS2 symbols for: $chunk"
            }

            val style = styleFor(voice, chunk.length)
            val tokenCount = symbolIds.size + 2
            require(tokenCount <= KittenTtsConfig.MAX_TEXT) {
                "KittenTTS sentence is too long after G2P ($tokenCount tokens); " +
                    "sentence chunking produced an oversized phoneme sequence"
            }

            val ids = IntArray(tokenCount)
            symbolIds.copyInto(ids, destinationOffset = 1)
            val predictorResult = runPredictor(ids, style, speed)

            val durations = predictorResult.durations
            require(durations.all { it > 0 }) {
                "Kitten predictor returned non-positive duration"
            }
            val frameCount = durations.sum()
            require(frameCount > 0 && frameCount <= 4096) {
                "KittenTTS predicted duration is invalid: $frameCount frames"
            }

            val en = repeatRows(predictorResult.d, durations, KittenTtsConfig.D_DIM)
            val asr = repeatRows(predictorResult.tEn, durations, KittenTtsConfig.ASR_DIM)

            val prosodyResult = runProsody(en, frameCount, style)
            val waveform = runVocoder(asr, frameCount, prosodyResult, style)

            val sampleCount = max(
                waveform.size - KittenTtsConfig.TAIL_TRIM,
                KittenTtsConfig.MIN_SAMPLES.coerceAtMost(waveform.size),
            )
            audioPieces += FloatArray(sampleCount) { waveform[it].coerceIn(-1f, 1f) }
            totalTokens += tokenCount
            totalFrames += frameCount
        }

        val totalSamples = audioPieces.sumOf { it.size }
        val pcm = FloatArray(totalSamples)
        var offset = 0
        for (piece in audioPieces) {
            System.arraycopy(piece, 0, pcm, offset, piece.size)
            offset += piece.size
        }

        KittenTtsEngineResult(
            pcm = pcm,
            sampleRate = KittenTtsConfig.SAMPLE_RATE,
            channels = 1,
            tokens = totalTokens,
            frames = totalFrames,
            synthMs = (System.nanoTime() - started) / 1_000_000L,
        )
    }

    private data class PredictorResult(
        val d: FloatArray,
        val tEn: FloatArray,
        val durations: IntArray,
    )

    private fun runPredictor(
        ids: IntArray,
        style: FloatArray,
        speed: Float,
    ): PredictorResult {
        val tokenCount = ids.size
        val styleIndex = inputIndex(predictor, "style")
        val speedIndex = inputIndex(predictor, "speed")
        val inputIdsIndex = inputIndex(predictor, "input_ids")
        predictor.resizeInput(inputIdsIndex, intArrayOf(1, tokenCount))
        predictor.resizeInput(styleIndex, intArrayOf(1, KittenTtsConfig.STYLE_DIM))
        predictor.resizeInput(speedIndex, intArrayOf(1))
        predictor.allocateTensors()
        predictor.resetVariableTensors()

        val inputValues = arrayOfNulls<Any>(predictor.inputTensorCount)
        inputValues[inputIdsIndex] = intBuffer(ids)
        inputValues[styleIndex] = floatBuffer(style)
        inputValues[speedIndex] = floatBuffer(floatArrayOf(speed))

        // Graph contract (litert-community/kitten-tts-nano-0.8 predictor):
        //   inputs [style, speed, input_ids], outputs [t_en, d, durations].
        // Multi-dim outputs are copied through direct ByteBuffers (the TFLite
        // Java API rejects flat arrays for rank>1 output tensors).
        val outputs = arrayOfNulls<Any>(predictor.outputTensorCount)
        val tEnIndex = outputIndexBySuffix(predictor, ":0")
        val dIndex = outputIndexBySuffix(predictor, ":2")
        val durationIndex = outputIndexBySuffix(predictor, ":1")
        outputs[tEnIndex] = floatOut(tokenCount * KittenTtsConfig.ASR_DIM)
        outputs[dIndex] = floatOut(tokenCount * KittenTtsConfig.D_DIM)
        outputs[durationIndex] = intOut(tokenCount)

        predictor.runForMultipleInputsOutputs(
            inputValues,
            outputs.withIndex().associate { it.index to it.value },
        )

        val durations = readI32(outputs[durationIndex] as ByteBuffer)
        require(durations.size == tokenCount) {
            "Kitten predictor returned ${durations.size} durations for $tokenCount tokens"
        }

        return PredictorResult(
            d = readF32(outputs[dIndex] as ByteBuffer),
            tEn = readF32(outputs[tEnIndex] as ByteBuffer),
            durations = durations,
        )
    }

    private data class ProsodyResult(
        val f0: FloatArray,
        val noise: FloatArray,
        val harmonics: FloatArray,
    )

    private fun runProsody(
        en: FloatArray,
        frameCount: Int,
        style: FloatArray,
    ): ProsodyResult {
        val enIndex = inputIndex(prosody, "en")
        val styleIndex = inputIndex(prosody, "style")
        prosody.resizeInput(enIndex, intArrayOf(1, frameCount, KittenTtsConfig.D_DIM))
        prosody.resizeInput(styleIndex, intArrayOf(1, KittenTtsConfig.STYLE_DIM))
        prosody.allocateTensors()
        prosody.resetVariableTensors()

        // Graph contract (litert-community/kitten-tts-nano-0.8 prosody):
        //   inputs [style, en]; outputs [f0 (1,2T), har (1,120T+1,22), n (1,2T)].
        val f0 = floatOut(frameCount * 2)
        val harmonics = floatOut((frameCount * 120 + 1) * KittenTtsConfig.HAR_DIM)
        val noise = floatOut(frameCount * 2)

        val inputValues = arrayOfNulls<Any>(prosody.inputTensorCount)
        inputValues[enIndex] = floatBuffer(en)
        inputValues[styleIndex] = floatBuffer(style)

        prosody.runForMultipleInputsOutputs(
            inputValues,
            mapOf(
                outputIndexBySuffix(prosody, ":0") to f0,
                outputIndexBySuffix(prosody, ":2") to harmonics,
                outputIndexBySuffix(prosody, ":1") to noise,
            ),
        )

        return ProsodyResult(
            f0 = readF32(f0),
            noise = readF32(noise),
            harmonics = readF32(harmonics),
        )
    }

    private fun runVocoder(
        asr: FloatArray,
        frameCount: Int,
        prosody: ProsodyResult,
        style: FloatArray,
    ): FloatArray {
        val asrIndex = inputIndex(vocoder, "asr")
        val f0Index = inputIndex(vocoder, "f0")
        val noiseIndex = inputIndex(vocoder, "n")
        val harmonicsIndex = inputIndex(vocoder, "har")
        val styleIndex = inputIndex(vocoder, "style")
        vocoder.resizeInput(asrIndex, intArrayOf(1, frameCount, KittenTtsConfig.ASR_DIM))
        vocoder.resizeInput(f0Index, intArrayOf(1, prosody.f0.size))
        vocoder.resizeInput(noiseIndex, intArrayOf(1, prosody.noise.size))
        vocoder.resizeInput(
            harmonicsIndex,
            intArrayOf(1, prosody.harmonics.size / KittenTtsConfig.HAR_DIM, KittenTtsConfig.HAR_DIM),
        )
        vocoder.resizeInput(styleIndex, intArrayOf(1, KittenTtsConfig.STYLE_DIM))
        vocoder.allocateTensors()

        val output = floatOut(KittenTtsConfig.SAMPLES_PER_FRAME * frameCount)
        val inputValues = arrayOfNulls<Any>(vocoder.inputTensorCount)
        inputValues[asrIndex] = floatBuffer(asr)
        inputValues[f0Index] = floatBuffer(prosody.f0)
        inputValues[noiseIndex] = floatBuffer(prosody.noise)
        inputValues[harmonicsIndex] = floatBuffer(prosody.harmonics)
        inputValues[styleIndex] = floatBuffer(style)

        vocoder.runForMultipleInputsOutputs(inputValues, mapOf(0 to output))
        return readF32(output)
    }

    private fun styleFor(voice: Int, textLength: Int): FloatArray {
        val row = textLength.coerceIn(0, KittenTtsConfig.STYLE_ROWS - 1)
        val offset = (voice * KittenTtsConfig.STYLE_ROWS + row) * KittenTtsConfig.STYLE_DIM
        return voiceTable.copyOfRange(offset, offset + KittenTtsConfig.STYLE_DIM)
    }

    private fun loadVoiceTable(): FloatArray {
        val file = assets.voices()
        val expected =
            KittenTtsConfig.VOICE_COUNT *
                KittenTtsConfig.STYLE_ROWS *
                KittenTtsConfig.STYLE_DIM
        val bytes = file.length()
        require(bytes == expected.toLong() * 4L) {
            "Invalid voices.bin size $bytes, expected ${expected * 4L}"
        }
        val out = FloatArray(expected)
        ByteBuffer.wrap(file.readBytes())
            .order(ByteOrder.LITTLE_ENDIAN)
            .asFloatBuffer()
            .get(out)
        return out
    }

    private fun repeatRows(x: FloatArray, durations: IntArray, dim: Int): FloatArray {
        var total = 0
        for (duration in durations) total += duration.coerceAtLeast(0)
        val out = FloatArray(total * dim)
        var write = 0
        for (row in durations.indices) {
            val repeats = durations[row].coerceAtLeast(0)
            repeat(repeats) {
                System.arraycopy(x, row * dim, out, write, dim)
                write += dim
            }
        }
        return out
    }

    private fun floatBuffer(data: FloatArray): ByteBuffer =
        ByteBuffer.allocateDirect(data.size * 4)
            .order(ByteOrder.nativeOrder())
            .also { it.asFloatBuffer().put(data) }

    private fun intBuffer(data: IntArray): ByteBuffer =
        ByteBuffer.allocateDirect(data.size * 4)
            .order(ByteOrder.nativeOrder())
            .also { it.asIntBuffer().put(data) }

    private fun floatOut(size: Int): ByteBuffer =
        ByteBuffer.allocateDirect(size * 4).order(ByteOrder.LITTLE_ENDIAN)

    private fun intOut(size: Int): ByteBuffer =
        ByteBuffer.allocateDirect(size * 4).order(ByteOrder.LITTLE_ENDIAN)

    private fun readF32(buffer: ByteBuffer): FloatArray {
        buffer.rewind()
        val floats = buffer.asFloatBuffer()
        val out = FloatArray(floats.remaining())
        floats.get(out)
        return out
    }

    private fun readI32(buffer: ByteBuffer): IntArray {
        buffer.rewind()
        val ints = buffer.asIntBuffer()
        val out = IntArray(ints.remaining())
        ints.get(out)
        return out
    }

    private fun tensorName(interpreter: Interpreter, index: Int): String =
        interpreter.getOutputTensor(index).name()
            .removePrefix("serving_default_")

    private fun outputIndexBySuffix(interpreter: Interpreter, suffix: String): Int {
        for (index in 0 until interpreter.outputTensorCount) {
            if (tensorName(interpreter, index).endsWith(suffix)) return index
        }
        error("Kitten graph output ending with '$suffix' not found in " +
            (0 until interpreter.outputTensorCount).joinToString {
                tensorName(interpreter, it)
            })
    }

    private fun inputIndex(interpreter: Interpreter, expectedName: String): Int {
        for (index in 0 until interpreter.inputTensorCount) {
            val name = interpreter.getInputTensor(index).name()
                .removePrefix("serving_default_")
                .substringBefore(':')
            if (name == expectedName) return index
        }
        error("Kitten graph input '$expectedName' not found; available=" +
            (0 until interpreter.inputTensorCount).joinToString {
                interpreter.getInputTensor(it).name()
            })
    }

    override fun close() = synchronized(lock) {
        if (!closed.compareAndSet(false, true)) return@synchronized
        g2p.close()
        predictor.close()
        prosody.close()
        vocoder.close()
    }
}
