package expo.modules.wakeword

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlin.concurrent.thread

class WakeWordModule : Module() {

    companion object {
        init {
            try {
                System.loadLibrary("wakeword_bridge")
                Log.i("WakeWord", "Successfully loaded Cpp library")
            } catch (e: Throwable) {
                // This will print the EXACT reason it failed to load
                Log.e("WakeWord", "Failed to load Cpp library: ${e.message}", e)
            }
        }
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE = 16000
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false

    private external fun runInference(samples: ShortArray): FloatArray?

    override fun definition() = ModuleDefinition {
        Name("WakeWord")

        Events("onWakeWordDetected")

        Function("start") {
            if (!isRecording) {
                val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
                val recordBufferSize = maxOf(minBufferSize, BUFFER_SIZE)

                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    AUDIO_FORMAT,
                    recordBufferSize
                )

                audioRecord?.startRecording()
                isRecording = true

                thread(start = true) {
                    processAudioStream()
                }
            }
        }

        Function("stop") {
            isRecording = false
            audioRecord?.apply {
                stop()
                release()
            }
            audioRecord = null
        }

        OnDestroy {
            if (isRecording) {
                isRecording = false
                audioRecord?.stop()
                audioRecord?.release()
                audioRecord = null
            }
        }
    }

    private fun processAudioStream() {
        val audioBuffer = ShortArray(BUFFER_SIZE)
        while (isRecording) {
            val shortsRead = audioRecord?.read(audioBuffer, 0, BUFFER_SIZE) ?: 0
            if (shortsRead > 0) {
                // Add this line to see if the mic is actually hearing you, or just returning [0, 0, 0]
                Log.d("WakeWord", "Audio check: ${audioBuffer[0]}, ${audioBuffer[500]}, ${audioBuffer[1000]}")
                
                val results = runInference(audioBuffer)
                if (results != null && results.isNotEmpty()) {
                    Log.d("WakeWord", "Inference results: ${results.joinToString(", ")}")
                    if (results[0] > 0.5f) {
                        sendEvent("onWakeWordDetected", mapOf("keyword" to "hey_kritha", "confidence" to results[0]))
                    }
                }
            }
        }
    }
}