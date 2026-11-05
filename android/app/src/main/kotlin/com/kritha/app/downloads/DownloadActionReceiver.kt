package com.kritha.app.downloads

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class DownloadActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION = "com.kritha.app.downloads.ACTION"
        const val EXTRA_ID = "download.id"
        const val EXTRA_ACTION = "download.action"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        DownloadNotificationEvents.dispatch(id, action)
    }
}
