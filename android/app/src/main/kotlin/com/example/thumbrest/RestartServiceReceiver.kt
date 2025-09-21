package com.example.thumbrest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class RestartServiceReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RestartServiceReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.example.thumbrest.RESTART_SERVICE") {
            Log.d(TAG, "Received restart service broadcast")
            
            // Note: We can't directly restart the accessibility service from here
            // The user needs to manually re-enable it in accessibility settings
            // But we can log this event for debugging
            Log.w(TAG, "Accessibility service needs to be re-enabled by user")
        }
    }
}