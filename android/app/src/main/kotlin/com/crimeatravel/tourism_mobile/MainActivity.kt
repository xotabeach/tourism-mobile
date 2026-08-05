package com.crimeatravel.tourism_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePushNotificationChannel()
    }

    private fun ensurePushNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID,
            "CrimeaTrip",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Системные уведомления CrimeaTrip"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val PUSH_CHANNEL_ID = "crimeatrip_push"
    }
}
