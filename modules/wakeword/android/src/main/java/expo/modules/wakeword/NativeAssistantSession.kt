package expo.modules.wakeword

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import expo.modules.wakeword.commands.*
import java.util.Locale

internal class NativeAssistantSession(
    context: Context,
    private val callback: Callback
) : RecognitionListener {
    interface Callback {
        fun onAssistantListening()
        fun onAssistantProcessing(transcript: String)
        fun onAssistantFinished(transcript: String?, response: String)
        fun onAssistantError(message: String)
        fun onAssistantResponseSpoken()
    }

    companion object {
        @Volatile
        private var sharedTts: TextToSpeech? = null
        @Volatile
        private var isTtsInitialized = false
        @Volatile
        private var pendingSpeech: String? = null

        @Volatile
        private var sharedRecognizer: SpeechRecognizer? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        fun prewarm(context: Context) {
            val appContext = context.applicationContext
            mainHandler.post {
                if (sharedTts == null) {
                    sharedTts = TextToSpeech(appContext) { status ->
                        if (status == TextToSpeech.SUCCESS) {
                            sharedTts?.language = Locale.US
                            isTtsInitialized = true
                            mainHandler.post {
                                pendingSpeech?.let {
                                    val textToSpeak = it
                                    pendingSpeech = null
                                    sharedTts?.speak(textToSpeak, TextToSpeech.QUEUE_FLUSH, null, "kritha-native-response")
                                }
                            }
                        }
                    }
                }
                if (sharedRecognizer == null && SpeechRecognizer.isRecognitionAvailable(appContext)) {
                    sharedRecognizer = SpeechRecognizer.createSpeechRecognizer(appContext)
                }
            }
        }
    }

    private val appContext = context.applicationContext
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var hasCompleted = false
    private var lastTranscript: String? = null

    fun speakAndFinish(response: String) {
        mainHandler.post {
            finishWithResponse(lastTranscript, response)
        }
    }

    fun start() {
        mainHandler.post {
            val isAvailable = sharedRecognizer != null || SpeechRecognizer.isRecognitionAvailable(appContext)
            if (!isAvailable) {
                finishWithError("Speech recognition is not available on this device")
                return@post
            }

            if (sharedTts == null) {
                prewarm(appContext)
            }
            tts = sharedTts

            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(utteranceId: String?) {
                    mainHandler.post { callback.onAssistantResponseSpoken() }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    mainHandler.post { callback.onAssistantResponseSpoken() }
                }
            })

            if (sharedRecognizer == null) {
                sharedRecognizer = SpeechRecognizer.createSpeechRecognizer(appContext)
            }
            recognizer = sharedRecognizer
            recognizer?.setRecognitionListener(this@NativeAssistantSession)

            callback.onAssistantListening()
            recognizer?.startListening(buildRecognizerIntent())
        }
    }

    fun shutdown() {
        mainHandler.post {
            recognizer?.let {
                runCatching { it.cancel() }
                it.setRecognitionListener(null)
            }
            recognizer = null
            tts?.stop()
            tts = null
        }
    }

    override fun onReadyForSpeech(params: Bundle?) = Unit
    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onPartialResults(partialResults: Bundle?) = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    override fun onResults(results: Bundle?) {
        val transcript = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()

        lastTranscript = transcript
        callback.onAssistantProcessing(transcript)

        // Process command natively and speak response
        val response = processCommand(transcript)
        finishWithResponse(transcript, response)
    }

    override fun onError(error: Int) {
        val response = when (error) {
            SpeechRecognizer.ERROR_NO_MATCH -> "I did not catch that."
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "I did not hear anything."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition is busy."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is missing."
            else -> "Speech recognition failed."
        }

        if (error == SpeechRecognizer.ERROR_NO_MATCH || 
            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT || 
            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) {
            
            Log.w("NativeAssistant", "Temporary error: $error. Restarting listening...")
            mainHandler.postDelayed({
                if (!hasCompleted && recognizer != null) {
                    callback.onAssistantListening()
                    recognizer?.startListening(buildRecognizerIntent())
                }
            }, 1000)
        } else {
            finishWithError(response)
        }
    }

    private fun buildRecognizerIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1_200L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 900L)
        }

    private fun processCommand(command: String): String {
        val lower = command.lowercase(Locale.US)
        return when {
            lower in setOf("stop", "cancel", "never mind", "nevermind") -> {
                "Okay."
            }
            lower.startsWith("hello") || lower.startsWith("hi") -> {
                "Hi, I am listening."
            }
            "help" in lower || "what can you do" in lower -> {
                "I can control your alarm, timer, music, volume, wifi, bluetooth, flashlight, and read notifications or calendar events."
            }
            "time" in lower -> {
                "The current time is ${java.text.DateFormat.getTimeInstance(java.text.DateFormat.SHORT).format(java.util.Date())}."
            }
            "date" in lower || "day" in lower -> {
                "Today is ${java.text.DateFormat.getDateInstance(java.text.DateFormat.FULL).format(java.util.Date())}."
            }
            DeviceCommandHandler.canHandle(lower) -> {
                DeviceCommandHandler.handle(lower, appContext)
            }
            MediaCommandHandler.canHandle(lower) -> {
                MediaCommandHandler.handle(lower, appContext)
            }
            OrganizerCommandHandler.canHandle(lower) -> {
                OrganizerCommandHandler.handle(lower, appContext)
            }
            CommunicationCommandHandler.canHandle(lower, command) -> {
                CommunicationCommandHandler.handle(command, lower, appContext)
            }
            InfoCommandHandler.canHandle(lower) -> {
                InfoCommandHandler.handle(lower, appContext)
            }
            AppLauncherCommandHandler.canHandle(lower) -> {
                AppLauncherCommandHandler.handle(command, lower, appContext)
            }
            else -> {
                "I heard: $command"
            }
        }
    }

    private fun finishWithError(message: String) {
        if (hasCompleted) return
        hasCompleted = true
        Log.e("NativeAssistant", message)
        callback.onAssistantError(message)
        cleanupRecognizer()
        callback.onAssistantResponseSpoken()
    }

    private fun finishWithResponse(transcript: String?, response: String) {
        if (hasCompleted) return
        hasCompleted = true
        callback.onAssistantFinished(transcript, response)
        cleanupRecognizer()
        speak(response)
    }

    private fun cleanupRecognizer() {
        recognizer?.let {
            runCatching { it.cancel() }
            it.setRecognitionListener(null)
        }
        recognizer = null
    }

    private fun speak(text: String) {
        mainHandler.post {
            if (isTtsInitialized) {
                sharedTts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "kritha-native-response")
            } else {
                pendingSpeech = text
                prewarm(appContext)
            }
        }
    }
}
