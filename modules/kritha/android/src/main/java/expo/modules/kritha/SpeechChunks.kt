package expo.modules.kritha

/**
 * Split a spoken reply into pieces for pipelined synthesis: the app plays
 * piece N while synthesizing piece N+1, so the first sound arrives after one
 * short synthesis instead of after the whole reply. Sentences stay whole; a
 * sentence longer than [MAX_CHARS] splits at the last clause boundary
 * (comma, semicolon, colon, dash) inside the budget, falling back to a word
 * boundary. Mirrors speech-core's synthesis chunker loosely — this split is
 * for playback latency, the core one is for the model's output capacity.
 */
object SpeechChunks {
    private const val MAX_CHARS = 30
    private const val MIN_CHARS = 10

    fun split(text: String, maxChars: Int = MAX_CHARS): List<String> {
        val out = mutableListOf<String>()
        for (sentence in splitSentences(text)) {
            if (sentence.length <= maxChars) out.add(sentence)
            else out.addAll(splitClauses(sentence, maxChars))
        }
        return out
    }

    private fun splitSentences(text: String): List<String> {
        val parts = mutableListOf<String>()
        val current = StringBuilder()
        for (ch in text) {
            if (ch == '\n') {
                current.toString().trim().takeIf { it.isNotEmpty() }?.let { parts.add(it) }
                current.clear()
                continue
            }
            current.append(ch)
            if (ch == '.' || ch == '!' || ch == '?') {
                current.toString().trim().takeIf { it.isNotEmpty() }?.let { parts.add(it) }
                current.clear()
            }
        }
        current.toString().trim().takeIf { it.isNotEmpty() }?.let { parts.add(it) }
        return parts
    }

    private fun splitClauses(sentence: String, maxChars: Int): List<String> {
        val out = mutableListOf<String>()
        var rest = sentence.trim()
        while (rest.length > maxChars) {
            val window = rest.substring(0, maxChars)
            val clauseCut = maxOf(
                window.lastIndexOf(','),
                window.lastIndexOf(';'),
                window.lastIndexOf(':'),
                window.lastIndexOf('—'),
            )
            // Keep the delimiter with the leading piece
            var cut = if (clauseCut >= 20) clauseCut + 1
            else window.lastIndexOf(' ').coerceAtLeast(1)

            if (rest.substring(cut).trim().length < MIN_CHARS) {
                val earlierWord = rest.lastIndexOf(' ', cut - 1)
                if (earlierWord >= MIN_CHARS) cut = earlierWord
            }
            out.add(rest.substring(0, cut).trim())
            rest = rest.substring(cut).trim()
        }
        if (rest.isNotEmpty()) out.add(rest)
        return out
    }
}
