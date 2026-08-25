package expo.modules.kritha.wakeword

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
    private val listening       = AtomicBoolean(false)
    private val assistantActive = AtomicBoolean(false)
    private val recorderRef     = AtomicReference<AudioRecord?>()

    @Volatile private var isListeningPaused = false
    @Volatile private var isListeningPausedForStt = false
    @Volatile private var lastDetectionAt   = 0L

    private var wakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG                  = "WakeWordService"
        private const val CHANNEL_ID           = "wakeword_detection"
        private const val NOTIFICATION_ID      = 4101
        private const val SAMPLE_RATE          = 16_000
        private const val SAMPLE_COUNT         = 16_000
        private const val SLICE_SIZE           = 4_000 
        private const val DETECTION_THRESHOLD  = 0.65f
        private const val DETECTION_COOLDOWN   = 4_000L
        private const val ACTION_FORCE_EXIT    = "expo.modules.kritha.ACTION_FORCE_EXIT"
        private const val ACTION_TOGGLE        = "expo.modules.kritha.ACTION_TOGGLE_LISTENING"
        private const val TRIGGER_RETRY_DELAY  = 100L

        @Volatile var isRunning = false
            private set

        @Volatile private var instance: WakeWordForegroundService? = null

        fun onAssistantSessionFinished() {
            instance?.apply {
                assistantActive.set(false)
                startListening()
            }
        }

        fun stopAssistantSession() {
            WakeWordListeningActivity.stopSessionIfActive()
            instance?.mainHandler?.post {
                instance?.apply {
                    if (assistantActive.compareAndSet(true, false)) {
                        startListening()
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

        /**
         * Programmatically triggers the assistant session (e.g. from JS).
         * Retries until the service instance is available (max ~2 seconds).
         */
        fun triggerAssistantSession(context: Context, retryCount: Int = 0) {
            if (!isRunning) start(context)
            val handler = Handler(Looper.getMainLooper())
            handler.post {
                val svc = instance
                when {
                    svc != null -> {
                        if (WakeWordListeningActivity.isInstanceActive) {
                            WakeWordListeningActivity.onWakeWordDetected(origin = "MANUAL_DICTATION")
                            return@post
                        }
                        if (svc.assistantActive.compareAndSet(false, true)) {
                            svc.listening.set(false)
                            svc.stopRecorder()
                        }
                        svc.launchAssistantActivity()
                    }
                    retryCount < 20 -> handler.postDelayed(
                        { triggerAssistantSession(context, retryCount + 1) },
                        TRIGGER_RETRY_DELAY
                    )
                    else -> Log.e(TAG, "Service never became available after ${retryCount * TRIGGER_RETRY_DELAY}ms")
                }
            }
        }

        fun pauseListening() {
            instance?.apply {
                isListeningPaused = true
                listening.set(false)
                stopRecorder()
            }
        }

        fun pauseForStt() {
            instance?.apply {
                isListeningPausedForStt = true
                listening.set(false)
                stopRecorder()
            }
        }

        fun resumeFromStt() {
            instance?.apply {
                isListeningPausedForStt = false
                if (!isListeningPaused) {
                    startListening()
                }
            }
        }

        fun resumeListening() {
            instance?.apply {
                isListeningPaused = false
                if (!isListeningPausedForStt) {
                    startListening()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        expo.modules.kritha.TtsManager.prewarm(this)
        createNotificationChannel()
        startForegroundCompat(buildNotification())
        acquireWakeLock()
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_FORCE_EXIT -> {
                Log.i(TAG, "Force exit via notification")
                stop(this)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TOGGLE -> {
                if (isListeningPaused) {
                    Log.i(TAG, "Resuming listening")
                    resumeListening()
                } else {
                    Log.i(TAG, "Pausing listening")
                    pauseListening()
                }
                refreshNotification()
                return START_STICKY
            }
        }
        
        if (!listening.get() && !assistantActive.get() && !isListeningPaused) {
            startListening()
        }
        refreshNotification()
        return START_STICKY
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        isRunning = false
        listening.set(false)
        assistantActive.set(false)
        stopRecorder()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        WakeWordListeningActivity.stopSessionIfActive()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startListening() {
        if (isListeningPaused || isListeningPausedForStt) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO permission missing — stopping service")
            stopSelf()
            return
        }
        if (!listening.compareAndSet(false, true)) return 

        thread(name = "KrithaWakeWord", isDaemon = true) {
            val recorder = createAudioRecord() ?: run {
                listening.set(false)
                return@thread
            }

            recorderRef.set(recorder)
            expo.modules.kritha.MicrophoneManager.setWakeWordOwner()
            try {
                recorder.startRecording()
                runDetectionLoop(recorder)
            } finally {
                runCatching { recorder.stop() }
                recorder.release()
                recorderRef.compareAndSet(recorder, null)
                listening.set(false)
                expo.modules.kritha.MicrophoneManager.releaseWakeWordOwner()
                Log.d(TAG, "Detection thread exited")
            }
        }
    }

    private fun runDetectionLoop(recorder: AudioRecord) {
        val ringBuffer  = ShortArray(SAMPLE_COUNT)
        val sliceBuffer = ShortArray(SLICE_SIZE)

        while (listening.get()) {
            var offset = 0
            while (offset < SLICE_SIZE && listening.get()) {
                val read = recorder.read(sliceBuffer, offset, SLICE_SIZE - offset)
                if (read <= 0) return
                offset += read
            }
            if (offset < SLICE_SIZE) return

            System.arraycopy(ringBuffer, SLICE_SIZE, ringBuffer, 0, SAMPLE_COUNT - SLICE_SIZE)
            System.arraycopy(sliceBuffer, 0, ringBuffer, SAMPLE_COUNT - SLICE_SIZE, SLICE_SIZE)

            val confidence = runCatching { WakeWordNative.runInference(ringBuffer) }
                .onFailure { Log.e(TAG, "Wake-word inference error", it) }
                .getOrNull()?.firstOrNull() ?: continue

            val now = SystemClock.elapsedRealtime()
            if (confidence >= DETECTION_THRESHOLD && now - lastDetectionAt >= DETECTION_COOLDOWN) {
                lastDetectionAt = now
                onDetected(confidence)
            }
        }
    }

    private fun onDetected(confidence: Float) {
        Log.i(TAG, "Wake word detected (confidence=$confidence)")

        if (WakeWordListeningActivity.isInstanceActive) {
            listening.set(false)
            stopRecorder()
            WakeWordListeningActivity.onWakeWordDetected()
            WakeWordEventHub.emitWakeWord("hey_kritha", confidence)
            return
        }

        if (isAppInForeground()) {
            WakeWordEventHub.emitWakeWord("hey_kritha", confidence)
            return
        }

        if (assistantActive.compareAndSet(false, true)) {
            listening.set(false)
            stopRecorder()
            launchAssistantActivity()
        }
    }

    private fun launchAssistantActivity() {
        val needsOverlayPermission = !isAppInForeground() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)
        if (needsOverlayPermission) {
            Toast.makeText(this, "Enable 'Display over other apps' to use the assistant", Toast.LENGTH_LONG).show()
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            assistantActive.set(false)
            startListening()
            return
        }
        startActivity(Intent(this, WakeWordListeningActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or 
                Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
        })
    }

    // AudioRecord helpers

    private fun createAudioRecord(): AudioRecord? {
        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) {
            Log.e(TAG, "Unsupported audio config (minBufSize=$minBuf)")
            stopSelf()
            return null
        }
        return try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf, SAMPLE_COUNT * 2)
            ).takeIf { it.state == AudioRecord.STATE_INITIALIZED }
                ?: run { Log.e(TAG, "AudioRecord failed to initialise"); null }
        } catch (e: SecurityException) {
            Log.e(TAG, "Microphone access denied", e)
            null
        }
    }

    private fun stopRecorder() {
        recorderRef.getAndSet(null)?.let {
            runCatching { it.stop() }
            it.release()
        }
    }

    // Notification helpers

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun refreshNotification() {
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val paused = isListeningPaused
        val title  = if (paused) "Kritha Assistant (Paused)" else "Kritha is listening"
        val text   = if (paused) "Tap to resume wake word detection" else "Listening for \"Hey Kritha\""

        val launchPi = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val togglePi = PendingIntent.getService(this, 1,
            Intent(this, WakeWordForegroundService::class.java).apply { action = ACTION_TOGGLE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val exitPi = PendingIntent.getService(this, 2,
            Intent(this, WakeWordForegroundService::class.java).apply { action = ACTION_FORCE_EXIT },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        val appIcon = applicationInfo.icon.takeIf { it != 0 } ?: 0

        builder
            .setSmallIcon(appIcon)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(launchPi)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)

        val toggleLabel = if (paused) "Resume" else "Pause"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val emptyIcon = android.graphics.drawable.Icon.createWithResource(this, android.R.color.transparent)
            builder.addAction(Notification.Action.Builder(emptyIcon, toggleLabel, togglePi).build())
            builder.addAction(Notification.Action.Builder(emptyIcon, "Exit", exitPi).build())
        } else {
            builder.addAction(0, toggleLabel, togglePi)
            builder.addAction(0, "Exit", exitPi)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Wake-word detection", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shows while Kritha is listening for the wake word"
                    setShowBadge(false)
                }
            )
    }

    // Misc helpers

    private fun acquireWakeLock() {
        wakeLock = (getSystemService(PowerManager::class.java))
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:wakeword")
            .apply { setReferenceCounted(false); acquire() }
    }

    private fun isAppInForeground(): Boolean {
        val info = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(info)
        return info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    }
}
