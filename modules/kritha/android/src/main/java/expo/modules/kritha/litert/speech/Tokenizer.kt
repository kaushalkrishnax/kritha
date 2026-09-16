package expo.modules.kritha.litert.speech

/**
 * Runtime tokenizer boundary.
 *
 * Tokenizers are model-family assets, not LiteRT runtime concerns. A future
 * tokenizer package can implement SentencePiece, Hugging Face tokenizers,
 * Whisper BPE, etc. without changing the LiteRT executor.
 */
class MapTokenizer(
    private val idToToken: Map<Int, String>,
    private val tokenToId: Map<String, Int> = emptyMap()
) : Tokenizer {
    override fun encode(text: String): IntArray =
        text.trim().split(Regex("\\s+"))
            .mapNotNull { tokenToId[it] }
            .toIntArray()

    override fun decode(tokenIds: IntArray): String =
        tokenIds.mapNotNull { idToToken[it] }
            .joinToString("")
}
