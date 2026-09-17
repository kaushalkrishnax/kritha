package expo.modules.kritha.litert.speech.tts

interface AudioOutput : AutoCloseable {
    fun start(sampleRate: Int, channels: Int)
    fun write(pcm: FloatArray)
    fun stop()
    override fun close()
}
