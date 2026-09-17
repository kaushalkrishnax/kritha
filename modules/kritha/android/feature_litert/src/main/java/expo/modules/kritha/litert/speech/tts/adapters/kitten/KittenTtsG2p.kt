package expo.modules.kritha.litert.speech.tts.adapters.kitten

import expo.modules.kritha.runtime.tts.*

import expo.modules.kritha.litert.LiteRTExecutionOptions
import expo.modules.kritha.litert.LiteRTModelDescriptor
import expo.modules.kritha.litert.LiteRTRuntime
import expo.modules.kritha.litert.LiteRTTask
import com.google.ai.edge.litert.TensorBuffer
import java.io.BufferedReader
import java.io.Closeable
import java.io.File
import java.io.InputStreamReader
import java.util.zip.GZIPInputStream
import kotlin.math.min
import org.json.JSONObject

/**
 * English front-end for KittenTTS nano 0.8.
 * Primary path: espeak-IPA dictionary. Fallback: DeepPhonemizer graph for unknown words.
 * Resulting IPA maps into the 178-symbol StyleTTS2 inventory.
 */
internal class KittenTtsG2p(
    runtime: LiteRTRuntime,
    private val assets: KittenTtsAssets,
    execution: LiteRTExecutionOptions,
) : Closeable {

    private val dictionary = HashMap<String, String>(300_000)
    private val charToIndex = HashMap<Char, Int>()
    private val indexToPhoneme = HashMap<Int, String>()
    private val specialTokens: Set<String>
    private val charRepeats: Int
    private val startId: Int
    private val endId: Int
    private val maxTokens: Int
    private val numPhonemes: Int
    private val symbolToId = HashMap<Char, Int>()

    private val model = runtime.load(
        LiteRTModelDescriptor(
            id = "${KittenTtsConfig.MODEL_ID}:g2p:${assets.g2p().name}",
            path = assets.g2p().absolutePath,
            task = LiteRTTask.TEXT_TO_SPEECH,
            architecture = "deep-phonemizer",
        ),
        execution.copy(device = expo.modules.kritha.litert.LiteRTDevice.CPU),
    )
    private val session = model.positionalSession()
    private val inputs: List<TensorBuffer> = session.createInputBuffers()
    private val outputs: List<TensorBuffer> = session.createOutputBuffers()

    init {
        require(inputs.size == 1) { "Kitten G2P expects one input, got ${inputs.size}" }
        require(outputs.size >= 1) { "Kitten G2P produced no outputs" }

        val meta = JSONObject(assets.g2pMeta().readText())
        val char2idx = meta.getJSONObject("char2idx")
        for (key in char2idx.keys()) {
            if (key.length == 1) charToIndex[key[0]] = char2idx.getInt(key)
        }
        val idx2ph = meta.getJSONObject("idx2ph")
        for (key in idx2ph.keys()) indexToPhoneme[key.toInt()] = idx2ph.getString(key)
        charRepeats = meta.getInt("char_repeats")
        startId = meta.getInt("start")
        endId = meta.getInt("end")
        maxTokens = meta.getInt("MAXT")
        numPhonemes = meta.getInt("n_phonemes")
        val special = meta.getJSONArray("special")
        specialTokens = (0 until special.length()).map { special.getString(it) }.toSet()

        val config = JSONObject(assets.config().readText())
        val symbols = config.getJSONArray("symbols")
        for (i in 0 until symbols.length()) {
            val symbol = symbols.getString(i)
            if (symbol.length == 1) symbolToId[symbol[0]] = i
        }

        assets.dictionary()?.let { loadDictionary(it) }
    }

    fun phonemize(text: String): IntArray {
        val ipa = StringBuilder()
        var first = true

        fun append(value: String) {
            if (value.isEmpty()) return
            if (!first) ipa.append(' ')
            ipa.append(value)
            first = false
        }

        for (match in TOKEN.findAll(text)) {
            val token = match.value
            when {
                ACRONYM.matches(token) -> {
                    append(token.lowercase().mapNotNull { LETTER_IPA[it] }.joinToString(""))
                }
                token.firstOrNull()?.isDigit() == true -> {
                    for (word in numberToWords(token)) {
                        append(dictionary[word] ?: phonemizeWord(word))
                    }
                }
                WORD.matches(token) -> {
                    val lower = token.lowercase()
                    append(dictionary[lower] ?: phonemizeWord(lower))
                }
                else -> append(token)
            }
        }

        val ids = ArrayList<Int>(ipa.length)
        for (ch in ipa) symbolToId[ch]?.let(ids::add)
        return ids.toIntArray()
    }

    private fun loadDictionary(file: File) {
        val reader = if (file.name.endsWith(".gz")) {
            BufferedReader(InputStreamReader(GZIPInputStream(file.inputStream()), Charsets.UTF_8))
        } else {
            file.bufferedReader(Charsets.UTF_8)
        }
        reader.useLines { lines ->
            lines.forEach { line ->
                val tab = line.indexOf('\t')
                if (tab > 0) dictionary[line.substring(0, tab)] = line.substring(tab + 1)
            }
        }
    }

    private fun phonemizeWord(word: String): String {
        val ids = ArrayList<Int>(maxTokens)
        ids.add(startId)
        for (ch in word) {
            charToIndex[ch]?.let { id -> repeat(charRepeats) { ids.add(id) } }
        }
        ids.add(endId)

        val length = min(ids.size, maxTokens)
        val input = FloatArray(maxTokens) { if (it < length) ids[it].toFloat() else 0f }
        inputs[0].writeFloat(input)
        session.run(inputs, outputs)
        val logits = outputs[0].readFloat()

        val result = StringBuilder()
        var previous = -1
        for (t in 0 until length) {
            var best = 0
            var bestScore = logits[t * numPhonemes]
            for (k in 1 until numPhonemes) {
                val score = logits[t * numPhonemes + k]
                if (score > bestScore) {
                    bestScore = score
                    best = k
                }
            }
            if (best == previous) continue
            previous = best
            val phoneme = indexToPhoneme[best] ?: continue
            if (phoneme in specialTokens || best == 0) continue
            for (ch in phoneme) if (ch != '-') result.append(ch)
        }
        return result.toString()
    }

    private fun numberToWords(raw: String): List<String> {
        val token = raw.replace(",", "")
        if (token.contains('.')) {
            val parts = token.split('.', limit = 2)
            val words = (if (parts[0].isNotEmpty()) integerToWords(parts[0].toLongOrNull() ?: 0L)
            else listOf("zero")).toMutableList()
            words.add("point")
            parts[1].forEach { if (it.isDigit()) words.add(ONES[it - '0']) }
            return words
        }
        return integerToWords(token.toLongOrNull() ?: return emptyList())
    }

    private fun wordsUnderThousand(value: Int): List<String> {
        var n = value
        val words = ArrayList<String>(4)
        if (n >= 100) {
            words += ONES[n / 100]
            words += "hundred"
            n %= 100
        }
        if (n >= 20) {
            words += TENS[n / 10]
            n %= 10
        }
        if (n > 0) words += ONES[n]
        return words
    }

    private fun integerToWords(value: Long): List<String> {
        if (value == 0L) return listOf("zero")
        if (value < 0) return listOf("minus") + integerToWords(-value)
        val groups = ArrayList<Int>()
        var n = value
        while (n > 0) {
            groups += (n % 1000).toInt()
            n /= 1000
        }
        if (groups.size > SCALES.size) return value.toString().map { ONES[it - '0'] }

        val words = ArrayList<String>()
        for (i in groups.indices.reversed()) {
            if (groups[i] == 0) continue
            words += wordsUnderThousand(groups[i])
            if (SCALES[i].isNotEmpty()) words += SCALES[i]
        }
        return words
    }

    override fun close() {
        inputs.forEach { runCatching { it.close() } }
        outputs.forEach { runCatching { it.close() } }
        session.close()
        model.close()
    }

    companion object {
        private val TOKEN = Regex("[A-Z]{2,}|\\d[\\d,]*(?:\\.\\d+)?|[A-Za-z']+|[.,!?;:—…\"]")
        private val ACRONYM = Regex("[A-Z]{2,}")
        private val WORD = Regex("[A-Za-z']+")

        private val LETTER_IPA = mapOf(
            'a' to "ˈeɪ", 'b' to "bˈiː", 'c' to "sˈiː", 'd' to "dˈiː", 'e' to "ˈiː",
            'f' to "ˈɛf", 'g' to "dʒˈiː", 'h' to "ˈeɪtʃ", 'i' to "ˈaɪ", 'j' to "dʒˈeɪ",
            'k' to "kˈeɪ", 'l' to "ˈɛl", 'm' to "ˈɛm", 'n' to "ˈɛn", 'o' to "ˈoʊ",
            'p' to "pˈiː", 'q' to "kjˈuː", 'r' to "ˈɑːɹ", 's' to "ˈɛs", 't' to "tˈiː",
            'u' to "jˈuː", 'v' to "vˈiː", 'w' to "dˈʌbəljˌuː", 'x' to "ˈɛks",
            'y' to "wˈaɪ", 'z' to "zˈiː",
        )
        private val ONES = arrayOf(
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
            "seventeen", "eighteen", "nineteen",
        )
        private val TENS = arrayOf("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
        private val SCALES = arrayOf("", "thousand", "million", "billion", "trillion")
    }
}
