package com.example.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Alarm notification fired!")
        
        // Extract alarm info from intent
        val alarmId = intent.getIntExtra("alarm_id", -1)
        val alarmLabel = intent.getStringExtra("alarm_label") ?: "Alarm"
        
        // Start foreground service to play alarm
        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START_ALARM
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmForegroundService.EXTRA_ALARM_LABEL, alarmLabel)
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        Log.d("AlarmReceiver", "Started foreground service for alarm: $alarmLabel")
    }
}

