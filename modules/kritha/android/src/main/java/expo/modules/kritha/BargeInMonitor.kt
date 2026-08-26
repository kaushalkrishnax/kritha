package expo.modules.kritha

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Lightweight voice-activity monitor used for "barge-in" during Live Talk:
 * while the assistant is speaking, it watches the microphone and fires a
 * one-shot callback when the user starts talking, so the caller can cancel
 * TTS/generation and hand the floor back to the user.
 */
object BargeInMonitor {
    private const val TAG = "BargeInMonitor"

    private const val SAMPLE_RATE = 16000
    private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    /** ~128 ms of audio per read. */
    private const val READ_SAMPLES = 2048

    /** Raw PCM RMS amplitude considered "speech" (room noise is usually < 300). */
    private const val AMPLITUDE_THRESHOLD = 2200.0

    /** Sustained speech needed before triggering: 5 reads ≈ 640 ms. */
    private const val REQUIRED_CONSECUTIVE_READS = 5

    /** Ignore audio right after arming so TTS onset/speaker reverb can't self-trigger. */
    private const val WARMUP_MS = 600L

    /** Hard safety cap so a stuck session can't hold the mic forever. */
    private const val MAX_SESSION_MS = 90_000L

    @Volatile
    var isEnabled: Boolean = false

    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    private var abortRequested: Boolean = false

    private var audioRecord: AudioRecord? = null
    private var echoCanceler: AcousticEchoCanceler? = null
    private var worker: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun start(onBargeIn: () -> Unit) {
        if (!isEnabled || isRunning) return
        isRunning = true
        abortRequested = false
        worker = Thread({ recordLoop(onBargeIn) }, "kritha-barge-in").apply {
            priority = Thread.MIN_PRIORITY + 1
            start()
        }
        Log.d(TAG, "Barge-in monitoring started")
    }

    fun stop() {
        if (!isRunning) return
        abortRequested = true
        val t = worker
        worker = null
        t?.interrupt()
        Log.d(TAG, "Barge-in monitoring stopped")
    }

    @SuppressLint("MissingPermission")
    private fun recordLoop(onBargeIn: () -> Unit) {
        var triggered = false
        var record: AudioRecord? = null
        try {
            val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            if (minBuf <= 0) return

            record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                maxOf(minBuf, READ_SAMPLES * 2),
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) return

            audioRecord = record
            if (AcousticEchoCanceler.isAvailable()) {
                echoCanceler = AcousticEchoCanceler.create(record.audioSessionId)?.apply {
                    enabled = true
                }
            }

            val buffer = ShortArray(READ_SAMPLES)
            var consecutiveSpeechReads = 0
            val startedAt = System.currentTimeMillis()
            record.startRecording()

            while (!abortRequested && !Thread.currentThread().isInterrupted) {
                val elapsed = System.currentTimeMillis() - startedAt
                if (elapsed > MAX_SESSION_MS) break

                val read = record.read(buffer, 0, buffer.size)
                if (read <= 0) break
                if (elapsed < WARMUP_MS) continue

                var sum = 0.0
                for (i in 0 until read) {
                    val sample = buffer[i].toDouble()
                    sum += sample * sample
                }
                val rms = Math.sqrt(sum / read)

                consecutiveSpeechReads = if (rms >= AMPLITUDE_THRESHOLD) {
                    consecutiveSpeechReads + 1
                } else {
                    0
                }

                if (consecutiveSpeechReads >= REQUIRED_CONSECUTIVE_READS) {
                    triggered = true
                    Log.d(TAG, "User speech detected (rms=$rms) – barging in")
                    break
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Barge-in monitor ended abnormally", e)
        } finally {
            try {
                record?.stop()
            } catch (_: Throwable) {
            }
            try {
                record?.release()
            } catch (_: Throwable) {
            }
            try {
                echoCanceler?.release()
            } catch (_: Throwable) {
            }
            audioRecord = null
            echoCanceler = null
            isRunning = false
            if (triggered) {
                mainHandler.post {
                    try {
                        onBargeIn()
                    } catch (e: Throwable) {
                        Log.e(TAG, "Barge-in callback failed", e)
                    }
                }
            }
        }
    }
}