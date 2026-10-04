package expo.modules.kritha.onnx

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import expo.modules.kritha.runtime.asr.AsrProvider
import org.json.JSONObject
import java.io.File

/**
 * Moonshine (ONNX) utterance transcription: one encoder pass over the
 * complete utterance, then greedy decoding with the merged decoder
 * (KV cache carried between steps).
 *
 * Expected artifacts in the model directory:
 *   encoder_model.onnx, decoder_model_merged.onnx, vocab.json (id → piece)
 */
class MoonshineAsr : AsrProvider {
    private var env: OrtEnvironment? = null
    private var encoder: OrtSession? = null
    private var decoder: OrtSession? = null
    private var vocab: List<String> = emptyList()

    @Synchronized
    override fun load(modelDirectory: String) {
        release()
        val dir = File(modelDirectory)
        val vocabFile = File(dir, VOCAB_FILE)
        require(vocabFile.isFile) { "Missing vocab.json in $modelDirectory" }
        vocab = parseVocab(vocabFile)

        val environment = OrtEnvironment.getEnvironment()
        env = environment
        val options = OrtSession.SessionOptions().apply { setIntraOpNumThreads(4) }
        encoder = environment.createSession(File(dir, ENCODER_FILE).absolutePath, options)
        decoder = environment.createSession(File(dir, DECODER_FILE).absolutePath, options)
    }

    @Synchronized
    override fun transcribe(pcm: ShortArray, sampleRate: Int): String {
        require(sampleRate == SAMPLE_RATE) { "MoonshineAsr expects ${SAMPLE_RATE} Hz PCM" }
        val activeEncoder = encoder ?: error("MoonshineAsr not loaded")
        val activeDecoder = decoder ?: error("MoonshineAsr not loaded")
        val environment = env ?: error("MoonshineAsr not loaded")

        val samples = FloatArray(pcm.size) { pcm[it] / 32768f }
        val encoderHidden: Array<Array<FloatArray>>
        OnnxTensor.createTensor(environment, arrayOf(samples)).use { inputTensor ->
            val inputName = activeEncoder.inputNames.first()
            activeEncoder.run(mapOf(inputName to inputTensor)).use { results ->
                @Suppress("UNCHECKED_CAST")
                val value = results.get(0).value as Array<Array<FloatArray>>
                encoderHidden = Array(value.size) { b ->
                    Array(value[b].size) { t -> value[b][t].copyOf() }
                }
            }
        }

        val tokens = greedyDecode(activeDecoder, environment, encoderHidden)
        return detokenize(tokens)
    }

    private fun greedyDecode(
        decoder: OrtSession,
        environment: OrtEnvironment,
        encoderHidden: Array<Array<FloatArray>>,
    ): List<Int> {
        val tokens = mutableListOf(BOS_TOKEN_ID)
        var pastResults: OrtSession.Result? = null

        OnnxTensor.createTensor(environment, encoderHidden).use { hiddenTensor ->
            var step = 0
            while (step < MAX_DECODE_STEPS) {
                val stepTokens = if (pastResults == null) tokens.toIntArray() else intArrayOf(tokens.last())
                val inputs = mutableMapOf<String, OnnxTensor>()
                val inputIds = OnnxTensor.createTensor(
                    environment,
                    arrayOf(stepTokens.map { it.toLong() }.toLongArray()),
                )
                inputs["input_ids"] = inputIds
                inputs["encoder_hidden_states"] = hiddenTensor

                var cacheBranch: OnnxTensor? = null
                if (decoder.inputNames.contains("use_cache_branch")) {
                    cacheBranch = OnnxTensor.createTensor(environment, booleanArrayOf(step > 0))
                    inputs["use_cache_branch"] = cacheBranch
                }

                val previous = pastResults
                if (previous != null) {
                    for (entry in previous) {
                        val inputName = entry.key.replaceFirst("present", "past_key_values")
                        if (entry.key.startsWith("present") &&
                            decoder.inputNames.contains(inputName)
                        ) {
                            inputs[inputName] = entry.value as OnnxTensor
                        }
                    }
                }

                val results = decoder.run(inputs)
                // First output of the merged decoder export is the logits tensor.
                val nextToken = argmaxLastPosition(results.get(0).value)

                runCatching { inputIds.close() }
                runCatching { cacheBranch?.close() }
                // Safe to release the previous cache only after the new run
                // produced its own tensors.
                runCatching { previous?.close() }
                pastResults = results

                if (nextToken == EOS_TOKEN_ID) break
                tokens.add(nextToken)
                if (tokens.size - 1 >= maxTokensFor(encoderHidden)) break
                step += 1
            }
        }
        runCatching { pastResults?.close() }
        return tokens.drop(1)
    }

    private fun argmaxLastPosition(value: Any): Int {
        @Suppress("UNCHECKED_CAST")
        val logits = value as Array<Array<FloatArray>>
        val last = logits[0].last()
        var best = 0
        var bestValue = Float.NEGATIVE_INFINITY
        for (i in last.indices) {
            if (last[i] > bestValue) {
                bestValue = last[i]
                best = i
            }
        }
        return best
    }

    private fun maxTokensFor(encoderHidden: Array<Array<FloatArray>>): Int {
        val frames = encoderHidden[0].size
        return (frames / TOKENS_PER_SECOND_DIVISOR).coerceIn(32, MAX_DECODE_STEPS)
    }

    private fun detokenize(tokens: List<Int>): String {
        val text = StringBuilder()
        for (token in tokens) {
            val piece = vocab.getOrNull(token) ?: continue
            if (piece.startsWith("<") && piece.endsWith(">")) continue
            // Byte-level BPE exports bytes without printable pieces as "0xNN".
            if (piece.startsWith("0x") && piece.length == 4) {
                val byte = piece.substring(2).toIntOrNull(16) ?: continue
                if (byte in 0x20..0x7E) text.append(byte.toChar())
                continue
            }
            text.append(piece.replace('▁', ' '))
        }
        return text.toString().trim()
    }

    private fun parseVocab(file: File): List<String> {
        val text = file.readText().trim()
        // Supported shapes: JSON array indexed by token id (CTranslate2
        // vocabulary.json), or a JSON object mapping piece → id.
        if (text.startsWith("[")) {
            val array = org.json.JSONArray(text)
            return List(array.length()) { array.optString(it) }
        }
        val json = JSONObject(text)
        val map = HashMap<Int, String>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val piece = keys.next()
            map[json.getInt(piece)] = piece
        }
        val size = (map.keys.maxOrNull() ?: -1) + 1
        return List(size) { map[it].orEmpty() }
    }

    @Synchronized
    override fun release() {
        runCatching { encoder?.close() }
        runCatching { decoder?.close() }
        encoder = null
        decoder = null
        env = null
        vocab = emptyList()
    }

    private companion object {
        const val SAMPLE_RATE = 16_000
        const val ENCODER_FILE = "encoder_model.onnx"
        const val DECODER_FILE = "decoder_model_merged.onnx"
        const val VOCAB_FILE = "vocab.json"
        const val BOS_TOKEN_ID = 1
        const val EOS_TOKEN_ID = 2
        const val MAX_DECODE_STEPS = 448
        const val TOKENS_PER_SECOND_DIVISOR = 8
    }
}
