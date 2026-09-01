package expo.modules.kritha

import ai.moonshine.voice.MicTranscriber
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Minimal abstraction over the on-device speech-to-text engine so the assistant session is
 * decoupled from the concrete implementation (the Moonshine Voice SDK).
 *
 * Callbacks are delivered on the main thread.
 */
internal interface AsrEngine {

    interface Listener {
        /** Engine is capturing audio and ready to transcribe. */
        fun onListening()

        /** Microphone input level changed (dB). Optional; not every engine emits it. */
        fun onRmsChanged(rmsdB: Float) {}

        /** Streaming partial transcript. */
        fun onPartial(transcript: String)

        /** A complete utterance/line of transcript. */
        fun onFinal(transcript: String)

        /** Engine failure. */
        fun onError(message: String)
    }

    /** Loads (if needed) and starts listening. Implementations run their work off the caller thread. */
    fun start()

    /** Stops capturing audio. If speech was already heard, the engine should deliver it as a final transcript. */
    fun stopListening()

    /** Releases all engine resources. The engine cannot be used again after this. */
    fun shutdown()
}

/**
 * On-device STT using the official Moonshine Voice SDK.
 *
 * Models are downloaded on first use and cached, not bundled in the APK.
 * load()/start() run on the worker thread; callbacks are forwarded to
 * AsrEngine.Listener.
 *
 * MicTranscriber owns microphone capture, so MicrophoneManager must coordinate
 * with the wake-word recorder before starting and release it afterward.
 */
internal class MoonshineAsrEngine(
    private val context: Context,
    private val listener: AsrEngine.Listener
) : AsrEngine {

    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var transcriber: MicTranscriber? = null

    @Volatile
    private var latestText: String = ""

    @Volatile
    private var finalDelivered: Boolean = false

    @Volatile
    private var loaded: Boolean = false

    @Volatile
    private var running: Boolean = false

    /** True once start() has been called; guards against starting the same instance twice. */
    @Volatile
    private var started: Boolean = false

    /** True once shutdown() has been called; stops any in-flight start(). */
    @Volatile
    private var closed: Boolean = false

    override fun start() {
        if (started) return
        started = true
        worker.execute {
            try {
                if (closed) return@execute
                // Pause the wake-word recorder while Moonshine owns the microphone.
                MicrophoneManager.claimForStt()

                val mic = transcriber ?: MicTranscriber(context)
                    .onText { text ->
                        if (finalDelivered || closed) return@onText
                        if (!text.isNullOrBlank()) {
                            latestText = text
                            onMain { listener.onPartial(text) }
                        }
                    }
                    .onLine { line ->
                        if (finalDelivered || closed) return@onLine
                        val text = line?.text?.trim().orEmpty()
                        if (text.isNotEmpty()) {
                            finalDelivered = true
                            onMain { listener.onFinal(text) }
                        }
                    }
                    .onError { error ->
                        if (!closed) {
                            onMain { listener.onError(error?.message ?: "Moonshine transcription failed.") }
                        }
                    }
                    .onProgress { fraction, file ->
                        Log.d(TAG, "Downloading Moonshine model $file: ${(fraction * 100).toInt()}%")
                    }
                    .also { transcriber = it }

                if (!loaded) {
                    // Blocking; downloads the model on first use, cache hits afterwards.
                    mic.load()
                    loaded = true
                }

                if (closed) {
                    MicrophoneManager.releaseFromStt()
                    return@execute
                }

                // Blocking; starts microphone capture.
                mic.start()
                if (closed) {
                    runCatching { mic.stop() }
                    MicrophoneManager.releaseFromStt()
                    return@execute
                }
                running = true
                Log.i(TAG, "Moonshine transcription started")
                onMain { listener.onListening() }
            } catch (e: Throwable) {
                Log.e(TAG, "Moonshine engine failed to start", e)
                MicrophoneManager.releaseFromStt()
                onMain { listener.onError(e.message ?: "Moonshine engine failed to start.") }
            }
        }
    }

    override fun stopListening() {
        stopCapture()
        // Promote whatever was heard so far to a final transcript, mirroring
        // SpeechRecognizer.stopListening() semantics.
        val text = latestText.trim()
        if (text.isNotEmpty() && !finalDelivered) {
            finalDelivered = true
            listener.onFinal(text)
        }
    }

    override fun shutdown() {
        closed = true
        stopCapture()
        try {
            transcriber?.close()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to close Moonshine transcriber", e)
        }
        transcriber = null
        loaded = false
        MicrophoneManager.releaseFromStt()
        worker.shutdown()
    }

    private fun stopCapture() {
        try {
            if (running) {
                transcriber?.stop()
                running = false
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to stop Moonshine capture", e)
        }
    }

    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    companion object {
        private const val TAG = "MoonshineAsrEngine"
    }
}