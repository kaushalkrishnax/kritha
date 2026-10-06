package expo.modules.kritha.liveTalk

import expo.modules.kritha.SpeechChunks
import expo.modules.kritha.StreamingPcmPlayer
import expo.modules.kritha.TtsModuleBridge
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

enum class LiveTalkTtsMode(val wire: String) {
    DISABLED("disabled"),
    AFTER_GENERATION("after_generation"),
    STREAM("stream");

    companion object {
        fun fromWire(value: String?): LiveTalkTtsMode =
            entries.firstOrNull { it.wire == value } ?: AFTER_GENERATION
    }
}

/**
 * Synthesizes and plays assistant speech for one Live Talk session (spec §9–11).
 *
 * - `after_generation`: one-shot playback of the complete response.
 * - `stream`: LLM deltas are grouped by [StreamingTextChunker]; chunk N plays
 *   while chunk N+1 synthesizes, so speech starts before the full response.
 * - [interrupt] cancels in-flight synthesis, clears queued chunks and flushes
 *   the AudioTrack — no stale audio after barge-in.
 *
 * One playback pipeline runs at a time; starting a new one interrupts the old.
 */
class LiveTalkTtsManager(
    private val bridge: TtsModuleBridge,
    private val voice: String,
) {
    interface Callback {
        fun onTtsStarted()
        fun onFirstAudio()
        fun onTtsFinished(interrupted: Boolean)
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @Volatile
    private var playbackJob: Job? = null

    @Volatile
    private var playbackChannel: Channel<String>? = null

    @Volatile
    private var player: StreamingPcmPlayer? = null

    private val firstAudioEmitted = AtomicBoolean(false)

    private val generation = AtomicLong(0)

    var callback: Callback? = null

    val isSpeaking: Boolean
        get() = playbackJob?.isActive == true

    interface StreamSink {
        fun append(delta: String)
        fun finish()
        suspend fun awaitPlayback()
    }

    /** One-shot mode: split the complete response and play it to the end. */
    suspend fun speakFull(text: String) {
        val channel = startPipeline()
        try {
            for (chunk in SpeechChunks.split(text)) {
                channel.send(chunk)
            }
        } finally {
            channel.close()
        }
        playbackJob?.join()
    }

    /** Streaming mode: returns a sink for LLM deltas. */
    fun speakStream(): StreamSink {
        val channel = startPipeline()
        val chunker = StreamingTextChunker { chunk -> channel.trySend(chunk) }
        return object : StreamSink {
            override fun append(delta: String) = chunker.append(delta)

            override fun finish() {
                chunker.flush()
                channel.close()
            }

            override suspend fun awaitPlayback() {
                playbackJob?.join()
            }
        }
    }

    private fun startPipeline(): Channel<String> {
        interrupt()
        val gen = generation.incrementAndGet()
        val channel = Channel<String>(Channel.UNLIMITED)
        playbackChannel = channel
        firstAudioEmitted.set(false)
        callback?.onTtsStarted()
        playbackJob = scope.launch { consume(gen, channel) }
        return channel
    }

    private suspend fun consume(gen: Long, chunks: Channel<String>) {
        var localPlayer: StreamingPcmPlayer? = null
        var interrupted = false
        try {
            val selection = bridge.resolveActiveTts()
                ?: throw LiveTalkException(
                    LiveTalkException.ERR_MODEL_MISSING,
                    "TTS model is not downloaded",
                )
            for (chunk in chunks) {
                if (chunk.isBlank()) continue
                val audio = bridge.synthesizeTtsPcm(
                    modelId = selection.modelId,
                    modelDirectory = selection.directory.absolutePath,
                    text = chunk,
                    voice = voice,
                )
                if (generation.get() != gen) throw CancellationException()
                val pcm16 = if (audio.pcm.isEmpty()) ByteArray(0) else bridge.encodePcm16(audio.pcm)
                if (pcm16.isEmpty()) continue
                try {
                    val active = localPlayer
                    if (active == null) {
                        localPlayer = StreamingPcmPlayer(audio.sampleRate).also { it.start(pcm16) }
                        player = localPlayer
                    } else {
                        active.write(pcm16)
                    }
                } catch (e: IllegalStateException) {
                    throw CancellationException()
                }
                if (firstAudioEmitted.compareAndSet(false, true)) {
                    callback?.onFirstAudio()
                }
            }
            localPlayer?.awaitDrained()
        } catch (e: CancellationException) {
            interrupted = true
        } finally {
            runCatching { localPlayer?.stopPlayback() }
            runCatching { localPlayer?.close() }
            if (generation.get() == gen) {
                player = null
                bridge.releaseActiveTts()
                callback?.onTtsFinished(interrupted)
            }
        }
    }

    /** Immediate cancellation: synthesis job, queued chunks and AudioTrack. */
    fun interrupt() {
        playbackChannel?.cancel()
        playbackChannel = null
        playbackJob?.cancel()
        playbackJob = null
        runCatching { player?.stopPlayback() }
    }

    fun stop() = interrupt()
}

/**
 * Groups streamed LLM text at phrase/sentence boundaries so TTS starts before
 * the full response exists without synthesizing token-by-token (spec §10).
 */
class StreamingTextChunker(
    private val emit: (String) -> Unit,
) {
    private val buffer = StringBuilder()

    @Synchronized
    fun append(delta: String) {
        buffer.append(delta)
        drain()
    }

    @Synchronized
    fun flush() {
        val rest = buffer.toString().trim()
        buffer.setLength(0)
        if (rest.isNotEmpty()) emit(rest)
    }

    private fun drain() {
        while (true) {
            val text = buffer.toString()
            val cut = findCut(text) ?: return
            val piece = text.substring(0, cut).trim()
            buffer.delete(0, cut)
            if (piece.isNotEmpty()) emit(piece)
        }
    }

    private fun findCut(text: String): Int? {
        val sentenceEnd = text.indexOfFirst { it == '.' || it == '!' || it == '?' || it == '\n' }
        if (sentenceEnd in (MIN_CHARS - 1) until text.length) return sentenceEnd + 1

        if (text.length >= CLAUSE_CHARS) {
            val window = text.substring(0, CLAUSE_CHARS)
            val clauseCut = maxOf(
                window.lastIndexOf(','),
                window.lastIndexOf(';'),
                window.lastIndexOf(':'),
                window.lastIndexOf('—'),
            )
            if (clauseCut >= MIN_CHARS) return clauseCut + 1
        }

        if (text.length >= MAX_CHARS) {
            val space = text.lastIndexOf(' ', MAX_CHARS)
            if (space >= MIN_CHARS) return space + 1
        }
        return null
    }

    private companion object {
        const val MIN_CHARS = 12
        const val CLAUSE_CHARS = 48
        const val MAX_CHARS = 96
    }
}
