package expo.modules.kritha.litert.speech.tts.adapters.kitten

data class KittenTtsEngineResult(
    val pcm: FloatArray,
    val sampleRate: Int = KittenTtsConfig.SAMPLE_RATE,
    val channels: Int = 1,
    val tokens: Int,
    val frames: Int,
    val synthMs: Long,
)

fun interface KittenTtsProgress {
    fun onSentenceComplete(sentenceIndex: Int)
}

/** Faithful sentence chunking used by Google's current KittenTTS LiteRT sample. */
internal object KittenTtsSentenceChunker {
    private val SENTENCE_END = Regex("[.!?]+")
    private const val MAX_CHUNK_CHARS = 400
    private const val PUNCTUATION = ".!?,;:"

    fun chunk(text: String): List<String> {
        val chunks = ArrayList<String>()
        for (sentence in SENTENCE_END.split(text)) {
            val trimmed = sentence.trim()
            if (trimmed.isEmpty()) continue
            if (trimmed.length <= MAX_CHUNK_CHARS) {
                chunks += ensurePunctuation(trimmed)
            } else {
                val builder = StringBuilder()
                for (word in trimmed.split(Regex("\\s+"))) {
                    if (builder.length + word.length + 1 > MAX_CHUNK_CHARS && builder.isNotEmpty()) {
                        chunks += ensurePunctuation(builder.toString())
                        builder.setLength(0)
                    }
                    if (builder.isNotEmpty()) builder.append(' ')
                    builder.append(word)
                }
                if (builder.isNotEmpty()) chunks += ensurePunctuation(builder.toString())
            }
        }
        return chunks
    }

    private fun ensurePunctuation(sentence: String): String =
        if (sentence.last() in PUNCTUATION) sentence else "$sentence,"
}
