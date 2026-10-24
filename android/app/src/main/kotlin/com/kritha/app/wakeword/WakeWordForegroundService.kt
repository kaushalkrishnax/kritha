package com.kritha.app.wakeword

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
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.kritha.app.MainActivity
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

class WakeWordForegroundService : Service() {
    companion object {
        private const val TAG = "KrithaWakeWord"
        private const val CHANNEL_ID = "kritha_wake_word"
        private const val NOTIFICATION_ID = 4210
        private const val ACTION_STOP = "com.kritha.app.wakeword.STOP"
        private const val ACTION_TOGGLE = "com.kritha.app.wakeword.TOGGLE"
        private const val SAMPLE_RATE = 16_000
        private const val WINDOW_SAMPLES = 16_000
        private const val SLICE_SAMPLES = 4_000
        private const val DETECTION_THRESHOLD = 0.65f
        private const val DETECTION_COOLDOWN_MS = 4_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, WakeWordForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WakeWordForegroundService::class.java))
        }
    }

    private val listening = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)
    private val recorder = AtomicReference<AudioRecord?>(null)
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastDetectionAt = 0L

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForegroundCompat(buildNotification())
        acquireWakeLock()
        startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TOGGLE -> {
                if (paused.get()) {
                    paused.set(false)
                    startListening()
                } else {
                    paused.set(true)
                    stopListening()
                }
                refreshNotification()
            }
            else -> if (!paused.get()) startListening()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        paused.set(true)
        stopListening()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startListening() {
        if (paused.get() || !WakeWordNative.available) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Microphone permission is not granted; stopping wake-word service")
            stopSelf()
            return
        }
        if (!listening.compareAndSet(false, true)) return

        thread(name = "KrithaWakeWord", isDaemon = true) {
            val audioRecord = createAudioRecord()
            if (audioRecord == null) {
                listening.set(false)
                return@thread
            }
            recorder.set(audioRecord)
            try {
                audioRecord.startRecording()
                runDetectionLoop(audioRecord)
            } catch (error: Throwable) {
                Log.e(TAG, "Wake-word recording loop failed", error)
            } finally {
                recorder.compareAndSet(audioRecord, null)
                runCatching { audioRecord.stop() }
                audioRecord.release()
                listening.set(false)
            }
        }
    }

    private fun runDetectionLoop(audioRecord: AudioRecord) {
        val window = ShortArray(WINDOW_SAMPLES)
        val slice = ShortArray(SLICE_SAMPLES)
        while (listening.get()) {
            var offset = 0
            while (offset < SLICE_SAMPLES && listening.get()) {
                val read = audioRecord.read(slice, offset, SLICE_SAMPLES - offset)
                if (read <= 0) return
                offset += read
            }
            if (offset < SLICE_SAMPLES) return

            System.arraycopy(window, SLICE_SAMPLES, window, 0, WINDOW_SAMPLES - SLICE_SAMPLES)
            System.arraycopy(slice, 0, window, WINDOW_SAMPLES - SLICE_SAMPLES, SLICE_SAMPLES)

            val confidence = runCatching { WakeWordNative.runInference(window)?.firstOrNull() }
                .onFailure { Log.e(TAG, "Wake-word inference failed", it) }
                .getOrNull() ?: continue

            val now = SystemClock.elapsedRealtime()
            if (confidence >= DETECTION_THRESHOLD && now - lastDetectionAt >= DETECTION_COOLDOWN_MS) {
                lastDetectionAt = now
                onWakeWordDetected(confidence)
            }
        }
    }

    private fun onWakeWordDetected(confidence: Float) {
        Log.i(TAG, "Wake word detected with confidence=$confidence")
        WakeWordEvents.emitDetected(confidence)
        if (isAppInForeground()) return

        listening.set(false)
        recorder.get()?.let { runCatching { it.stop() } }
        runCatching {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra(MainActivity.EXTRA_WAKE_WORD_CONFIDENCE, confidence)
                },
            )
        }.onFailure { Log.e(TAG, "Could not open Kritha after wake-word detection", it) }
    }

    private fun createAudioRecord(): AudioRecord? {
        val minimum = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minimum <= 0) {
            Log.e(TAG, "Unsupported microphone sample format: $minimum")
            return null
        }
        return runCatching {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minimum, WINDOW_SAMPLES * 2),
            ).takeIf { it.state == AudioRecord.STATE_INITIALIZED }
        }.onFailure { Log.e(TAG, "Could not initialize AudioRecord", it) }.getOrNull()
    }

    private fun stopListening() {
        listening.set(false)
        recorder.get()?.let { runCatching { it.stop() } }
    }

    private fun isAppInForeground(): Boolean {
        val process = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(process)
        return process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Wake-word listening", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while Hey Kritha wake-word listening is enabled"
                setShowBadge(false)
            },
        )
    }

    private fun buildNotification(): Notification {
        val openApp = packageManager.getLaunchIntentForPackage(packageName)?.let { intent ->
            PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val toggle = PendingIntent.getService(
            this,
            1,
            Intent(this, WakeWordForegroundService::class.java).setAction(ACTION_TOGGLE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            2,
            Intent(this, WakeWordForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(if (paused.get()) "Kritha wake word paused" else "Kritha is listening")
            .setContentText(if (paused.get()) "Tap Resume to continue" else "Listening for Hey Kritha")
            .setContentIntent(openApp)
            .setOngoing(true)
            .addAction(0, if (paused.get()) "Resume" else "Pause", toggle)
            .addAction(0, "Stop", stop)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun refreshNotification() {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification())
    }

    private fun acquireWakeLock() {
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:wakeword")
            .apply { setReferenceCounted(false); acquire(8 * 60 * 60 * 1000L) }
    }
}
