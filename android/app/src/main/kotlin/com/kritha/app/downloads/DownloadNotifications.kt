package com.kritha.app.downloads

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.kritha.app.MainActivity
import com.kritha.app.R

object DownloadNotifications {
    const val CHANNEL_ID = "kritha_downloads"
    const val SUMMARY_ID = 7001

    private val active = linkedSetOf<Int>()

    fun show(context: Context, args: Map<*, *>) {
        val notificationId = (args["notificationId"] as? Number)?.toInt() ?: return
        val id = args["id"] as? String ?: return
        val modelName = args["modelName"] as? String ?: "Model download"
        val fileName = args["fileName"] as? String ?: ""
        val received = (args["receivedBytes"] as? Number)?.toLong() ?: 0L
        val total = (args["totalBytes"] as? Number)?.toLong() ?: 0L
        val paused = args["paused"] as? Boolean ?: false

        ensureChannel(context)
        val isNew = active.add(notificationId)
        if (isNew) startService(context)

        val percent = if (total > 0) {
            ((received * 100) / total).toInt().coerceIn(0, 100)
        } else {
            -1
        }
        val text = buildString {
            append(fileName)
            append(if (percent >= 0) " • $percent%" else " • starting")
            if (paused) append(" • Paused")
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_kritha)
            .setContentTitle(modelName)
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setOngoing(!paused && percent < 100)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openApp(context, notificationId))

        if (percent >= 0) {
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, true)
        }

        val control = if (paused) "resume" else "pause"
        val label = if (paused) "Resume" else "Pause"
        builder.addAction(
            0,
            label,
            actionIntent(context, id, control, notificationId * 4 + (if (paused) 2 else 1)),
        )
        builder.addAction(0, "Cancel", actionIntent(context, id, "cancel", notificationId * 4 + 3))

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        } catch (_: SecurityException) {
            // Notification permission can be revoked while a download is running.
        }
    }

    fun cancel(context: Context, id: String, notificationId: Int?) {
        val resolved = notificationId ?: (id.hashCode() and 0x7fffffff)
        active.remove(resolved)
        NotificationManagerCompat.from(context).cancel(resolved)
        if (active.isEmpty()) stopService(context)
    }

    fun clearAll(context: Context) {
        val manager = NotificationManagerCompat.from(context)
        for (id in active) manager.cancel(id)
        active.clear()
        manager.cancel(SUMMARY_ID)
    }

    fun hasActive(): Boolean = active.isNotEmpty()

    fun summary(context: Context): Notification {
        ensureChannel(context)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_kritha)
            .setContentTitle("Downloading models")
            .setContentText("Kritha keeps downloading while minimized.")
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(0, 0, true)
            .build()
    }

    private fun startService(context: Context) {
        val intent = Intent(context, DownloadNotificationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopService(context: Context) {
        context.stopService(Intent(context, DownloadNotificationService::class.java))
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Model downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Progress for model downloads running in the background."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun openApp(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun actionIntent(
        context: Context,
        id: String,
        action: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, DownloadActionReceiver::class.java).apply {
            this.action = DownloadActionReceiver.ACTION
            putExtra(DownloadActionReceiver.EXTRA_ID, id)
            putExtra(DownloadActionReceiver.EXTRA_ACTION, action)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
