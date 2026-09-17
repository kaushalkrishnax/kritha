package expo.modules.kritha.litert.speech

class MapTokenizer(
    private val idToToken: Map<Int, String>,
    private val tokenToId: Map<String, Int> = emptyMap()
) : Tokenizer {
    override fun encode(text: String): IntArray =
        text.trim().split(Regex("\\s+"))
            .mapNotNull { tokenToId[it] }
            .toIntArray()

    override fun decode(tokenIds: IntArray): String =
        tokenIds.asSequence()
            .mapNotNull { idToToken[it] }
            .joinToString("")
}
