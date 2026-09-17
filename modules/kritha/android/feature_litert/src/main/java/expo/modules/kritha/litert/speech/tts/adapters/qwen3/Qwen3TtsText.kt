package expo.modules.kritha.litert.speech.tts.adapters.qwen3


import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.speech.tts.internal.Npy
import java.io.File
import java.nio.ShortBuffer
import java.text.Normalizer
import java.util.Random
import kotlin.math.exp
import org.json.JSONObject

/**
 * Host-side text frontend for Qwen3-TTS: byte-level BPE tokenizer, projection
 * MLPs, conditioning builder, and sampling. Graph execution stays in [Qwen3TtsModel.kt].
 */
internal class Qwen3TtsTokenizer(vocabFile: File, mergesFile: File) {
    private val vocab = HashMap<String, Int>(160_000)
    private val ranks = HashMap<Long, Int>(160_000)
    private val pieceIds = HashMap<String, Int>()
    private val byteToChar = CharArray(256)

    private val pretokenize = Regex(
        "(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}|" +
            " ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+"
    )

    init {
        val direct = (('!'.code..'~'.code) + ('¡'.code..'¬'.code) +
            ('®'.code..'ÿ'.code)).toHashSet()
        var next = 256
        for (b in 0 until 256) {
            byteToChar[b] = if (b in direct) b.toChar() else (next++).toChar()
        }

        val json = JSONObject(vocabFile.readText())
        for (key in json.keys()) vocab[key] = json.getInt(key)

        var rank = 0
        mergesFile.forEachLine { line ->
            if (line.isNotBlank() && !line.startsWith("#version")) {
                val split = line.indexOf(' ')
                require(split > 0) { "Malformed BPE merge line: $line" }
                val left = line.substring(0, split)
                val right = line.substring(split + 1)
                ranks[pairKey(pieceId(left), pieceId(right))] = rank++
            }
        }
    }

    fun encode(text: String): IntArray {
        val normalized = Normalizer.normalize(text, Normalizer.Form.NFC)
        val out = ArrayList<Int>(normalized.length / 3 + 8)
        for (match in pretokenize.findAll(normalized)) {
            val bytes = match.value.toByteArray(Charsets.UTF_8)
            val mapped = StringBuilder(bytes.size)
            for (b in bytes) mapped.append(byteToChar[b.toInt() and 0xFF])
            bpe(mapped.toString(), out)
        }
        return out.toIntArray()
    }

    private fun pieceId(piece: String): Int = pieceIds.getOrPut(piece) {
        vocab[piece] ?: error("BPE piece not found in vocabulary: $piece")
    }

    private fun pairKey(a: Int, b: Int): Long = (a.toLong() shl 32) xor (b.toLong() and 0xFFFF_FFFFL)

    private fun bpe(token: String, out: ArrayList<Int>) {
        if (token.isEmpty()) return
        var pieces = token.map { it.toString() }
        if (pieces.size == 1) {
            out += vocab[token] ?: error("BPE byte piece missing: $token")
            return
        }

        while (pieces.size > 1) {
            var bestRank = Int.MAX_VALUE
            var bestIndex = -1
            for (i in 0 until pieces.size - 1) {
                val a = vocab[pieces[i]] ?: continue
                val b = vocab[pieces[i + 1]] ?: continue
                val rank = ranks[pairKey(a, b)] ?: continue
                if (rank < bestRank) {
                    bestRank = rank
                    bestIndex = i
                }
            }
            if (bestIndex < 0) break
            val merged = pieces[bestIndex] + pieces[bestIndex + 1]
            pieces = pieces.subList(0, bestIndex) + merged + pieces.subList(bestIndex + 2, pieces.size)
        }

        for (piece in pieces) {
            out += vocab[piece] ?: error("BPE piece not found after merge: $piece")
        }
    }
}

internal class Qwen3TtsEmbeddings(assets: Qwen3TtsAssets) : AutoCloseable {
    private val codecEmbedding = Npy.loadFloats(assets.codecEmbedding())
    private val mtpEmbedding: ShortBuffer = Npy.mmapHalf(assets.mtpEmbedding())
    private val textEmbedding: ShortBuffer = Npy.mmapHalf(assets.textEmbedding())
    private val projection: Map<String, FloatArray> = Npy.loadNpz(
        assets.textProjection(),
        listOf("w1", "b1", "w2", "b2")
    )

    init {
        require(codecEmbedding.size % Qwen3TtsConfig.HIDDEN == 0) {
            "Codec embedding table has invalid size: ${codecEmbedding.size}"
        }
        require(projection["w1"]?.size == 2048 * 2048) { "Unexpected text projection w1 size" }
        require(projection["b1"]?.size == 2048) { "Unexpected text projection b1 size" }
        require(projection["w2"]?.size == Qwen3TtsConfig.HIDDEN * 2048) {
            "Unexpected text projection w2 size"
        }
        require(projection["b2"]?.size == Qwen3TtsConfig.HIDDEN) { "Unexpected text projection b2 size" }
    }

    fun codecRow(id: Int, out: FloatArray = FloatArray(Qwen3TtsConfig.HIDDEN)): FloatArray {
        require(id in 0 until Qwen3TtsConfig.CODEC_VOCAB) { "codec id out of range: $id" }
        val base = id * Qwen3TtsConfig.HIDDEN
        System.arraycopy(codecEmbedding, base, out, 0, Qwen3TtsConfig.HIDDEN)
        return out
    }

    fun addMtpRow(acc: FloatArray, table: Int, id: Int) {
        require(table in 0 until Qwen3TtsConfig.MTP_CODEBOOKS) { "MTP table out of range: $table" }
        require(id in 0 until Qwen3TtsConfig.MTP_VOCAB) { "MTP token out of range: $id" }
        val base = (table * Qwen3TtsConfig.MTP_VOCAB + id) * Qwen3TtsConfig.HIDDEN
        require(base + Qwen3TtsConfig.HIDDEN <= mtpEmbedding.limit()) { "MTP table is smaller than expected" }
        for (i in 0 until Qwen3TtsConfig.HIDDEN) {
            acc[i] += Npy.halfToFloat(mtpEmbedding.get(base + i))
        }
    }

    fun mtpRow(table: Int, id: Int): FloatArray =
        FloatArray(Qwen3TtsConfig.HIDDEN).also { addMtpRow(it, table, id) }

    /** text_embedding lookup + 2048->1024 SiLU MLP used by the exported Talker. */
    fun embedText(ids: IntArray): Array<FloatArray> {
        val w1 = projection.getValue("w1")
        val b1 = projection.getValue("b1")
        val w2 = projection.getValue("w2")
        val b2 = projection.getValue("b2")

        return Array(ids.size) { n ->
            require(ids[n] >= 0) { "Text token id cannot be negative: ${ids[n]}" }
            val x = FloatArray(2048)
            val base = ids[n] * 2048
            require(base >= 0 && base + 2048 <= textEmbedding.limit()) {
                "Text token id ${ids[n]} exceeds embedding table"
            }
            for (i in 0 until 2048) x[i] = Npy.halfToFloat(textEmbedding.get(base + i))

            val hidden = FloatArray(2048)
            for (r in 0 until 2048) {
                var sum = b1[r]
                val row = r * 2048
                for (c in 0 until 2048) sum += w1[row + c] * x[c]
                hidden[r] = sum / (1f + exp(-sum))
            }

            val output = FloatArray(Qwen3TtsConfig.HIDDEN)
            for (r in 0 until Qwen3TtsConfig.HIDDEN) {
                var sum = b2[r]
                val row = r * 2048
                for (c in 0 until 2048) sum += w2[row + c] * hidden[c]
                output[r] = sum
            }
            output
        }
    }

    override fun close() {}
}

internal class Qwen3TtsConditioning(private val embeddings: Qwen3TtsEmbeddings) {
    data class Prompt(
        val prefill: Array<FloatArray>,
        val trailingTextConditions: Array<FloatArray>,
    )

    fun build(
        textTokenIds: IntArray,
        language: String,
        speaker: FloatArray,
    ): Prompt {
        require(textTokenIds.isNotEmpty()) { "Qwen3-TTS text tokenizer produced zero tokens" }
        require(speaker.size == Qwen3TtsConfig.HIDDEN) {
            "Qwen3-TTS speaker x-vector must be ${Qwen3TtsConfig.HIDDEN} floats"
        }

        val ttsBos = embeddings.embedText(intArrayOf(Qwen3TtsConfig.TTS_BOS))[0]
        val ttsEos = embeddings.embedText(intArrayOf(Qwen3TtsConfig.TTS_EOS))[0]
        val ttsPad = embeddings.embedText(intArrayOf(Qwen3TtsConfig.TTS_PAD))[0]

        val control = if (language.equals("auto", ignoreCase = true)) {
            intArrayOf(
                Qwen3TtsConfig.NOTHINK,
                Qwen3TtsConfig.THINK_BOS,
                Qwen3TtsConfig.THINK_EOS,
            )
        } else {
            val languageId = Qwen3TtsConfig.LANGUAGE_IDS[language.lowercase()]
                ?: error("Unsupported Qwen3-TTS language: $language")
            intArrayOf(
                Qwen3TtsConfig.THINK,
                Qwen3TtsConfig.THINK_BOS,
                languageId,
                Qwen3TtsConfig.THINK_EOS,
            )
        }

        val codecPre = ArrayList<FloatArray>(control.size + 3)
        control.forEach { codecPre += embeddings.codecRow(it) }
        codecPre += speaker.copyOf()
        codecPre += embeddings.codecRow(Qwen3TtsConfig.PAD_ID)
        codecPre += embeddings.codecRow(Qwen3TtsConfig.BOS_ID)

        val role = embeddings.embedText(Qwen3TtsConfig.PROMPT_PREFIX)
        val body = Array(codecPre.size - 1) { i ->
            val cond = if (i < codecPre.size - 2) ttsPad else ttsBos
            add(cond, codecPre[i])
        }
        val firstText = add(
            embeddings.embedText(intArrayOf(textTokenIds[0]))[0],
            codecPre.last(),
        )
        val prefill = Array(role.size + body.size + 1) { index ->
            when {
                index < role.size -> role[index]
                index < role.size + body.size -> body[index - role.size]
                else -> firstText
            }
        }
        require(prefill.size <= Qwen3TtsConfig.TALKER_PREFILL_SIZE) {
            "Qwen3 prompt has ${prefill.size} positions, but ${Qwen3TtsConfig.PREFILL_SIGNATURE} supports 32"
        }

        val trailing = ArrayList<FloatArray>(textTokenIds.size)
        for (i in 1 until textTokenIds.size) {
            trailing += embeddings.embedText(intArrayOf(textTokenIds[i]))[0]
        }
        trailing += ttsEos

        return Prompt(prefill, trailing.toTypedArray())
    }

    private fun add(a: FloatArray, b: FloatArray): FloatArray =
        FloatArray(Qwen3TtsConfig.HIDDEN) { a[it] + b[it] }
}

internal class Qwen3TtsSampling {
    fun sample(
        logits: FloatArray,
        greedy: Boolean,
        random: Random,
        vocabLimit: Int? = null,
        temperature: Double = Qwen3TtsConfig.TEMPERATURE,
        topK: Int = Qwen3TtsConfig.TOP_K,
    ): Int {
        require(logits.isNotEmpty()) { "Cannot sample empty logits" }
        val limit = vocabLimit?.coerceIn(1, logits.size) ?: logits.size
        if (greedy) return argmax(logits, limit)

        val k = minOf(topK.coerceAtLeast(1), limit)
        val indices = (0 until limit).sortedByDescending { logits[it] }.take(k)
        val maxLogit = logits[indices[0]] / temperature
        val weights = DoubleArray(k)
        var total = 0.0
        for (i in 0 until k) {
            weights[i] = exp((logits[indices[i]] / temperature) - maxLogit)
            total += weights[i]
        }
        var target = random.nextDouble() * total
        for (i in 0 until k) {
            target -= weights[i]
            if (target <= 0.0) return indices[i]
        }
        return indices.last()
    }

    private fun argmax(values: FloatArray, limit: Int): Int {
        var best = 0
        for (i in 1 until limit) if (values[i] > values[best]) best = i
        return best
    }

    fun applyTalkerControls(logits: FloatArray, history: Set<Int>, frameCount: Int) {
        for (i in Qwen3TtsConfig.MTP_VOCAB until logits.size) logits[i] = Qwen3TtsConfig.NEGATIVE_INFINITY
        if (frameCount < Qwen3TtsConfig.MIN_NEW_FRAMES) logits[Qwen3TtsConfig.EOS] = Qwen3TtsConfig.NEGATIVE_INFINITY
        for (token in history) {
            logits[token] = if (logits[token] > 0f) {
                logits[token] / Qwen3TtsConfig.REPETITION_PENALTY
            } else {
                logits[token] * Qwen3TtsConfig.REPETITION_PENALTY
            }
        }
    }
}
