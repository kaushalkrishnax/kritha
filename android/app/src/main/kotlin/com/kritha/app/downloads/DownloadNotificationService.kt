package com.kritha.app.downloads

import android.app.Service
import android.content.Intent
import android.os.IBinder

class DownloadNotificationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!DownloadNotifications.hasActive()) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(DownloadNotifications.SUMMARY_ID, DownloadNotifications.summary(this))
        return START_STICKY
    }

    override fun onDestroy() {
        DownloadNotifications.clearAll(this)
        super.onDestroy()
    }
}
