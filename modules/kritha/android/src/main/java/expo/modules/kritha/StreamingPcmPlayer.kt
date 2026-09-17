package expo.modules.kritha

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTimestamp
import android.media.AudioTrack
import android.os.SystemClock
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.delay
import kotlin.math.max
import kotlin.math.min

internal class StreamingPcmPlayer(val sampleRate: Int) : AutoCloseable {

    private val closed = AtomicBoolean(false)
    private var started = false
    private var paused = false
    private var framePositionAtStart = 0L
    private var underrunsAtStart = 0

    val bufferSizeBytes: Int
    val track: AudioTrack
    var framesWritten: Long = 0
        private set

    val performanceMode: Int
        get() = track.performanceMode

    val underrunCount: Int
        get() = (track.underrunCount - underrunsAtStart).coerceAtLeast(0)

    init {
        require(sampleRate > 0) { "Invalid PCM sample rate: $sampleRate" }
        val minimum = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        require(minimum > 0) { "AudioTrack rejected ${sampleRate} Hz PCM: $minimum" }

        val frame160Ms = sampleRate * PCM_BYTES_PER_FRAME * 160 / 1_000
        bufferSizeBytes = max(minimum, frame160Ms)
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .setBufferSizeInBytes(bufferSizeBytes)
            .build()
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            error("AudioTrack failed to initialize at ${sampleRate} Hz")
        }
    }

    fun start(firstPcm16: ByteArray) {
        check(!started) { "Streaming PCM playback already started" }
        require(firstPcm16.isNotEmpty()) { "First PCM frame is empty" }
        require(firstPcm16.size % PCM_BYTES_PER_FRAME == 0) { "PCM16 byte count must be even" }

        framePositionAtStart = track.playbackHeadPosition.toLong() and UINT32_MASK
        underrunsAtStart = track.underrunCount

        // A non-blocking prefill cannot deadlock on a Kokoro-sized callback.
        var offset = writeBytes(firstPcm16, 0, min(firstPcm16.size, bufferSizeBytes), blocking = false)
        track.play()
        started = true
        if (offset < firstPcm16.size) {
            offset = writeBytes(
                firstPcm16,
                offset,
                firstPcm16.size - offset,
                blocking = true,
            )
        }
        check(offset == firstPcm16.size)
    }

    fun write(pcm16: ByteArray) {
        if (pcm16.isEmpty()) return
        check(started) { "Call start() before write()" }
        require(pcm16.size % PCM_BYTES_PER_FRAME == 0) { "PCM16 byte count must be even" }
        val written = writeBytes(pcm16, 0, pcm16.size, blocking = true)
        check(written == pcm16.size)
    }

    suspend fun awaitFirstPresentationNanos(timeoutMs: Long = 500): Long? {
        if (!started || closed.get()) return null
        val timestamp = AudioTimestamp()
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        while (!closed.get() && SystemClock.elapsedRealtime() < deadline) {
            if (track.getTimestamp(timestamp) && timestamp.framePosition > framePositionAtStart) {
                val presentedFrames = timestamp.framePosition - framePositionAtStart
                val elapsedForFrames = presentedFrames * NANOS_PER_SECOND / sampleRate
                return timestamp.nanoTime - elapsedForFrames
            }
            delay(4)
        }
        return null
    }

    suspend fun awaitDrained() {
        if (!started || closed.get()) return
        val durationMs = framesWritten * 1_000 / sampleRate
        var deadline = SystemClock.elapsedRealtime() + durationMs + DRAIN_GRACE_MS
        while (!closed.get() && SystemClock.elapsedRealtime() < deadline) {
            if (paused) {
                delay(20)
                deadline += 20
                continue
            }
            val position = track.playbackHeadPosition.toLong() and UINT32_MASK
            val played = (position - framePositionAtStart) and UINT32_MASK
            if (played >= framesWritten) return
            val remainingMs = (framesWritten - played) * 1_000 / sampleRate
            delay(remainingMs.coerceIn(4, 20))
        }
        if (!closed.get()) {
            error("AudioTrack drain timed out: played=${track.playbackHeadPosition} written=$framesWritten")
        }
    }

    fun resetForNextUtterance() {
        check(!closed.get()) { "Streaming PCM playback is closed" }
        check(started) { "Streaming PCM playback has not started" }
        track.pause()
        track.flush()
        started = false
        paused = false
        framesWritten = 0
        stopPlayback()
    }

    fun pausePlayback() {
        if (closed.get() || !started || paused) return
        try {
            track.pause()
        } catch (_: Exception) {}
        paused = true
    }

    fun resumePlayback() {
        if (closed.get() || !started || !paused) return
        try {
            track.play()
        } catch (_: Exception) {}
        paused = false
    }

    val isPaused: Boolean
        get() = paused

    val isStarted: Boolean
        get() = started

    fun stopPlayback() {
        if (!closed.get() && started) {
            try {
                track.pause()
                track.flush()
            } catch (_: Exception) {}
            started = false
            paused = false
            framesWritten = 0
        }
    }

    private fun writeBytes(
        pcm16: ByteArray,
        initialOffset: Int,
        length: Int,
        blocking: Boolean,
    ): Int {
        check(!closed.get()) { "Streaming PCM playback is closed" }
        var offset = initialOffset
        val end = initialOffset + length
        val mode = if (blocking) AudioTrack.WRITE_BLOCKING else AudioTrack.WRITE_NON_BLOCKING
        while (offset < end && !closed.get()) {
            val count = track.write(pcm16, offset, end - offset, mode)
            when {
                count > 0 -> {
                    offset += count
                    framesWritten += count / PCM_BYTES_PER_FRAME
                }
                count == 0 && !blocking -> break
                count == 0 -> Thread.yield()
                else -> error("AudioTrack.write failed: $count")
            }
        }
        check(!closed.get()) { "Streaming PCM playback was closed during write" }
        return offset
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        try {
            if (track.playState != AudioTrack.PLAYSTATE_STOPPED) track.stop()
        } catch (_: Exception) {
        }
        track.release()
    }

    private companion object {
        const val PCM_BYTES_PER_FRAME = 2
        const val NANOS_PER_SECOND = 1_000_000_000L
        const val UINT32_MASK = 0xffff_ffffL
        const val DRAIN_GRACE_MS = 2_000L
    }
}
