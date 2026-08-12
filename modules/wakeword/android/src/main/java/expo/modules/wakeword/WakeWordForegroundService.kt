package expo.modules.wakeword

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

class WakeWordForegroundService : Service() {
    companion object {
        private const val TAG = "WakeWordService"
        private const val ONGOING_CHANNEL_ID = "wakeword_detection"
        private const val ONGOING_NOTIFICATION_ID = 4101
        private const val SAMPLE_RATE = 16_000
        private const val SAMPLE_COUNT = 16_000
        private const val DETECTION_THRESHOLD = 0.6f
        private const val DETECTION_COOLDOWN_MS = 4_000L

        @Volatile
        var isRunning = false
            private set

        @Volatile
        private var activeService: WakeWordForegroundService? = null

        fun onAssistantSessionFinished() {
            activeService?.let { service ->
                service.assistantActive.set(false)
                service.startListening()
            }
        }

        fun stopAssistantSession() {
            WakeWordListeningActivity.stopSessionIfActive()
            activeService?.let { service ->
                service.mainHandler.post {
                    service.assistantSession?.let {
                        it.shutdown()
                        service.assistantSession = null
                    }
                    if (service.assistantActive.compareAndSet(true, false)) {
                        service.startListening()
                    }
                }
            }
        }

        fun start(context: Context) {
            isRunning = true
            val intent = Intent(context, WakeWordForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            isRunning = false
            context.stopService(Intent(context, WakeWordForegroundService::class.java))
        }

        fun triggerAssistantSession(context: Context) {
            if (!isRunning) {
                start(context)
            }
            val handler = Handler(Looper.getMainLooper())
            fun attemptTrigger() {
                val service = activeService
                if (service != null) {
                    if (service.assistantActive.compareAndSet(false, true)) {
                        val wasListening = service.listening.getAndSet(false)
                        service.stopRecorder()
                        
                        if (!wasListening) {
                            if (service.isAppInForeground()) {
                                service.startNativeAssistantSession()
                            } else {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(service)) {
                                    Toast.makeText(service, "Enable 'Display over other apps' to use the assistant", Toast.LENGTH_LONG).show()
                                    val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${service.packageName}")).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    service.startActivity(i)
                                    service.assistantActive.set(false)
                                    service.startListening()
                                } else {
                                    val intent = Intent(service, WakeWordListeningActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    service.startActivity(intent)
                                }
                            }
                        }
                    }
                } else {
                    handler.postDelayed({ attemptTrigger() }, 100)
                }
            }
            handler.post { attemptTrigger() }
        }

        internal val activeSession: NativeAssistantSession?
            get() = activeService?.assistantSession
    }

    private val listening = AtomicBoolean(false)
    private val assistantActive = AtomicBoolean(false)
    private val recorderRef = AtomicReference<AudioRecord?>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var audioRecord: AudioRecord? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastDetectionAt = 0L
    internal var assistantSession: NativeAssistantSession? = null
    override fun onCreate() {
        super.onCreate()
        activeService = this
        NativeAssistantSession.prewarm(this)
        createNotificationChannels()
        startAsForeground(buildOngoingNotification("Listening for Hey Kritha"))
        acquireWakeLock()
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        if (!listening.get() && !assistantActive.get()) startListening()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        listening.set(false)
        assistantActive.set(false)
        stopRecorder()
        audioRecord = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        isRunning = false
        WakeWordListeningActivity.stopSessionIfActive()
        assistantSession?.shutdown()
        assistantSession = null
        super.onDestroy()
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                ONGOING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(ONGOING_NOTIFICATION_ID, notification)
        }
    }

    private fun startListening() {
        if (assistantActive.get()) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO permission is missing")
            stopSelf()
            return
        }
        if (!listening.compareAndSet(false, true)) return

        thread(name = "KrithaWakeWord", start = true) {
            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBufferSize <= 0) {
                Log.e(TAG, "Unsupported microphone configuration: $minBufferSize")
                listening.set(false)
                stopSelf()
                return@thread
            }

            val recorder = try {
                AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(minBufferSize, SAMPLE_COUNT * 2)
                )
            } catch (error: SecurityException) {
                Log.e(TAG, "Microphone access was rejected", error)
                listening.set(false)
                stopSelf()
                return@thread
            }

            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                recorder.release()
                listening.set(false)
                stopSelf()
                return@thread
            }

            audioRecord = recorder
            recorderRef.set(recorder)
            try {
                recorder.startRecording()
                val samples = ShortArray(SAMPLE_COUNT)

                while (listening.get() && !assistantActive.get()) {
                    var offset = 0
                    while (listening.get() && !assistantActive.get() && offset < samples.size) {
                        val read = recorder.read(samples, offset, samples.size - offset)
                        if (read <= 0) break
                        offset += read
                    }
                    if (offset != samples.size) continue

                    val confidence = runCatching { WakeWordNative.runInference(samples) }
                        .onFailure { Log.e(TAG, "Wake-word inference failed", it) }
                        .getOrNull()
                        ?.firstOrNull()
                        ?: continue

                    val now = SystemClock.elapsedRealtime()
                    if (confidence >= DETECTION_THRESHOLD && now - lastDetectionAt >= DETECTION_COOLDOWN_MS) {
                        lastDetectionAt = now
                        onWakeWordDetected(confidence)
                    }
                }
            } finally {
                runCatching { recorder.stop() }
                recorder.release()
                recorderRef.compareAndSet(recorder, null)
                if (audioRecord === recorder) audioRecord = null
                listening.set(false)
                if (assistantActive.get() && isRunning) {
                    mainHandler.post {
                        if (isAppInForeground()) {
                            startNativeAssistantSession()
                        } else {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this@WakeWordForegroundService)) {
                                Toast.makeText(this@WakeWordForegroundService, "Enable 'Display over other apps' to use the assistant", Toast.LENGTH_LONG).show()
                                val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(i)
                                assistantActive.set(false)
                                startListening()
                            } else {
                                val intent = Intent(this@WakeWordForegroundService, WakeWordListeningActivity::class.java).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                }
                                startActivity(intent)
                            }
                        }
                    }
                }
            }
        }
    }

    private fun onWakeWordDetected(confidence: Float) {
        Log.i(TAG, "Wake word detected with confidence $confidence")
        WakeWordEventHub.emit("hey_kritha", confidence)

        if (!assistantActive.compareAndSet(false, true)) return
        listening.set(false)
        stopRecorder()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                "Wake-word detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Kritha is listening for the wake word"
                setShowBadge(false)
            }
        )
    }

    private fun buildOngoingNotification(message: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        return notificationBuilder(ONGOING_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Kritha wake word is active")
            .setContentText(message)
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .build()
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "$packageName:wakeword"
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }



    private fun stopRecorder() {
        recorderRef.getAndSet(null)?.let { recorder ->
            runCatching { recorder.stop() }
            recorder.release()
        }
    }

    private fun isAppInForeground(): Boolean {
        val appProcessInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(appProcessInfo)
        val isForeground = appProcessInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        Log.d(TAG, "Process importance: ${appProcessInfo.importance}, isForeground: $isForeground")
        return isForeground
    }

    private fun startNativeAssistantSession() {
        assistantSession?.shutdown()
        assistantSession = NativeAssistantSession(
            this,
            object : NativeAssistantSession.Callback {
                override fun onAssistantListening() {
                    WakeWordEventHub.emitAssistant("listening")
                }

                override fun onAssistantProcessing(transcript: String) {
                    WakeWordEventHub.emitAssistant("processing", transcript = transcript)
                }

                override fun onAssistantFinished(transcript: String?, response: String) {
                    WakeWordEventHub.emitAssistant(
                        "finished",
                        transcript = transcript,
                        response = response
                    )
                }

                override fun onAssistantError(message: String) {
                    WakeWordEventHub.emitAssistant("error", error = message)
                }

                override fun onAssistantResponseSpoken() {
                    assistantSession?.shutdown()
                    assistantSession = null
                    assistantActive.set(false)
                    startListening()
                }
            }
        ).also { it.start() }
    }
}
