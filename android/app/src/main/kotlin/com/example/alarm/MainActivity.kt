package com.example.alarm

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val DETECTOR_CHANNEL = "com.example.alarm/water_detector"
    private val LOG_CHANNEL = "com.example.alarm/water_logs"
    private val ALARM_SERVICE_CHANNEL = "com.example.alarm/alarm_service"
    private val AUDIO_STREAM_CHANNEL = "com.example.alarm/audio_stream"
    private var waterDetector: WaterDetector? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if launched from notification
        // Try to get alarm_id from intent extras first
        var alarmId = intent.getIntExtra("alarm_id", -1)
        var alarmLabel = intent.getStringExtra("alarm_label")
        
        // If not in extras, check if we can determine from notification payload
        // (This happens when notification fires and opens MainActivity)
        if (alarmId == -1 && intent.hasExtra("notification_payload")) {
            val payload = intent.getStringExtra("notification_payload")
            alarmId = payload?.toIntOrNull() ?: -1
        }
        
        // If we have an alarm ID, load the alarm and start service
        if (alarmId != -1) {
            if (alarmLabel == null) {
                // Load alarm label from SharedPreferences
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val alarmsJson = prefs.getString("flutter.alarms", null)
                if (alarmsJson != null) {
                    try {
                        val alarms = org.json.JSONArray(alarmsJson)
                        if (alarmId < alarms.length()) {
                            val alarmObj = alarms.getJSONObject(alarmId)
                            alarmLabel = alarmObj.optString("label", "Alarm")
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error parsing alarms: ${e.message}")
                    }
                }
            }
            
            Log.d("MainActivity", "Launched from notification, starting alarm service for: $alarmLabel")
            startAlarmService(alarmId, alarmLabel ?: "Alarm")
        } else {
            // If no alarm ID, check if we should start service based on current time
            // (This handles the case where notification fires but intent doesn't have alarm_id)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val alarmsJson = prefs.getString("flutter.alarms", null)
            if (alarmsJson != null) {
                try {
                    val alarms = org.json.JSONArray(alarmsJson)
                    val now = java.util.Calendar.getInstance()
                    val currentHour = now.get(java.util.Calendar.HOUR_OF_DAY)
                    val currentMinute = now.get(java.util.Calendar.MINUTE)
                    
                    // Find alarm that matches current time
                    for (i in 0 until alarms.length()) {
                        val alarmObj = alarms.getJSONObject(i)
                        val isActive = alarmObj.optBoolean("isActive", true)
                        if (!isActive) continue
                        
                        val timeStr = alarmObj.optString("time", "")
                        val timeParts = timeStr.split(":")
                        if (timeParts.size == 2) {
                            val alarmHour = timeParts[0].toIntOrNull()
                            val alarmMinute = timeParts[1].toIntOrNull()
                            if (alarmHour == currentHour && alarmMinute == currentMinute) {
                                val label = alarmObj.optString("label", "Alarm")
                                Log.d("MainActivity", "Found matching alarm, starting service")
                                startAlarmService(i, label)
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error finding alarm: ${e.message}")
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        val alarmId = intent.getIntExtra("alarm_id", -1)
        if (alarmId != -1) {
            val alarmLabel = intent.getStringExtra("alarm_label") ?: "Alarm"
            startAlarmService(alarmId, alarmLabel)
        }
    }

    private fun startAlarmService(alarmId: Int, alarmLabel: String) {
        val serviceIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START_ALARM
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmForegroundService.EXTRA_ALARM_LABEL, alarmLabel)
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        waterDetector = WaterDetector(this)

        // 1️⃣ Ses algılama kanalı
        val detectorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DETECTOR_CHANNEL)
        detectorChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val success = waterDetector?.initialize() ?: false
                    result.success(success)
                }
                "startListening" -> {
                    waterDetector?.onWaterDetected = {
                        detectorChannel.invokeMethod("onWaterDetected", null)
                    }
                    waterDetector?.onLogMessage = { log ->
                        detectorChannel.invokeMethod("onLog", log)
                    }
                    waterDetector?.startListening()
                    result.success(true)
                }
                "stopListening" -> {
                    waterDetector?.stopListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 2️⃣ Log okuma kanalı
        val logChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL)
        logChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLogs" -> {
                    val logs = waterDetector?.readLogs() ?: "No logs yet."
                    result.success(logs)
                }
                else -> result.notImplemented()
            }
        }

        // 3️⃣ Alarm Service kanalı
        val alarmServiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_SERVICE_CHANNEL)
        alarmServiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: -1
                    val alarmLabel = call.argument<String>("alarmLabel") ?: "Alarm"
                    startAlarmService(alarmId, alarmLabel)
                    result.success(true)
                }
                "stopAlarm" -> {
                    val serviceIntent = Intent(this, AlarmForegroundService::class.java).apply {
                        action = AlarmForegroundService.ACTION_STOP_ALARM
                    }
                    stopService(serviceIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 4️⃣ Audio Stream kanalı - Set alarm stream type for AudioPlayer
        val audioStreamChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_STREAM_CHANNEL)
        audioStreamChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAudioStreamAlarm" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        // Set alarm stream volume to max
                        val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM)
                        audioManager.setStreamVolume(android.media.AudioManager.STREAM_ALARM, maxVolume, 0)
                        Log.d("MainActivity", "Set alarm stream volume to max: $maxVolume")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error setting audio stream: ${e.message}")
                        result.error("ERROR", "Failed to set audio stream", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        waterDetector?.dispose()
        super.onDestroy()
    }
}
