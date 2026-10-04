package expo.modules.kritha.liveTalk

/**
 * Abstraction over the audio-processing backend (platform AEC or WebRTC APM).
 * The rest of the Live Talk pipeline does not care which backend is active.
 */
interface AudioProcessor {
    /**
     * Called after AudioRecord is created, supplying its audio session ID so
     * that hardware effects (AEC, NS) can be attached to the correct session.
     */
    fun start(audioSessionId: Int)

    /**
     * Process a frame of captured PCM-16 samples.
     * Input and output arrays are the same size.
     * May return the input reference unchanged if no processing is applied
     * (e.g. hardware AEC processes inside the AudioRecord driver).
     */
    fun process(input: ShortArray): ShortArray

    /** Release all resources at the end of the capture session. */
    fun stop()
}
