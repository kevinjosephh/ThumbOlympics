// Create BootReceiver.kt
package com.thumbolympics.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.NotificationChannel
import androidx.core.app.NotificationCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            // Show notification reminding user to re-enable accessibility
            showReEnableNotification(context)
        }
    }
    
    private fun showReEnableNotification(context: Context?) {
        context?.let {
            val notificationManager = it.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "thumbolympics_boot",
                    "ThumbOlympics Boot",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
                notificationManager.createNotificationChannel(channel)
            }
            
            val notification = NotificationCompat.Builder(it, "thumbolympics_boot")
                .setContentTitle("ThumbOlympics")
                .setContentText("Please re-enable accessibility service after restart")
                .setSmallIcon(android.R.drawable.ic_menu_preferences)
                .setAutoCancel(true)
                .build()
                
            notificationManager.notify(999, notification)
        }
    }
}