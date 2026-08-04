package expo.modules.wakeword

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class KrithaNotificationListener : NotificationListenerService() {
    companion object {
        @Volatile
        var instance: KrithaNotificationListener? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i("KrithaNotification", "Service created and instance registered")
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
        Log.i("KrithaNotification", "Service destroyed")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.i("KrithaNotification", "Notification listener connected")
    }

    override fun onListenerDisconnected() {
        if (instance === this) {
            instance = null
        }
        super.onListenerDisconnected()
        Log.i("KrithaNotification", "Notification listener disconnected")
    }
}
