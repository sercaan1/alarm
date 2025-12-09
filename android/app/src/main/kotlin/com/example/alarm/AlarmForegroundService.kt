package com.example.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.IOException

class AlarmForegroundService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var waterDetector: WaterDetector? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var alarmId: Int = -1
    private var alarmLabel: String = "Alarm"

    companion object {
        private const val TAG = "AlarmForegroundService"
        private const val CHANNEL_ID = "alarm_service_channel"
        private const val NOTIFICATION_ID = 1001
        
        const val ACTION_START_ALARM = "com.example.alarm.START_ALARM"
        const val ACTION_STOP_ALARM = "com.example.alarm.STOP_ALARM"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_LABEL = "alarm_label"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Acquire wake lock to keep device awake
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "AlarmApp::WakeLock"
        )
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes max
        
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ALARM -> {
                alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
                alarmLabel = intent.getStringExtra(EXTRA_ALARM_LABEL) ?: "Alarm"
                startAlarm()
            }
            ACTION_STOP_ALARM -> {
                stopAlarm()
            }
        }
        return START_STICKY // Restart if killed
    }

    private fun startAlarm() {
        Log.d(TAG, "Starting alarm: $alarmLabel")
        
        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Initialize water detector
        waterDetector = WaterDetector(this)
        waterDetector?.initialize()
        
        waterDetector?.onWaterDetected = {
            Log.d(TAG, "Water detected! Stopping alarm")
            stopAlarm()
        }
        
        // Start listening for water
        waterDetector?.startListening()
        
        // Play alarm sound
        playAlarmSound()
    }

    private fun playAlarmSound() {
        try {
            // Try to load from Flutter assets
            val assetManager = assets
            // Flutter assets are in flutter_assets/ directory
            val afd = assetManager.openFd("flutter_assets/assets/sounds/alarm_sound.mp3")
            
            mediaPlayer = MediaPlayer().apply {
                // Set to alarm stream type - this plays at max volume regardless of app volume
                setAudioStreamType(android.media.AudioManager.STREAM_ALARM)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                setOnPreparedListener {
                    it.start()
                    it.isLooping = true
                    it.setVolume(1.0f, 1.0f) // Max volume
                    Log.d(TAG, "Alarm sound started with STREAM_ALARM")
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    false
                }
                prepareAsync()
            }
            afd.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error loading alarm sound: ${e.message}")
            // Fallback: try alternative paths
            try {
                val afd2 = assets.openFd("assets/sounds/alarm_sound.mp3")
                mediaPlayer = MediaPlayer().apply {
                    setAudioStreamType(android.media.AudioManager.STREAM_ALARM)
                    setDataSource(afd2.fileDescriptor, afd2.startOffset, afd2.length)
                    setOnPreparedListener {
                        it.start()
                        it.isLooping = true
                        it.setVolume(1.0f, 1.0f)
                        Log.d(TAG, "Alarm sound started (fallback path) with STREAM_ALARM")
                    }
                    prepareAsync()
                }
                afd2.close()
            } catch (e2: Exception) {
                Log.e(TAG, "Error with fallback sound: ${e2.message}")
                // Last resort: use system default alarm sound
                try {
                    val ringtoneUri = android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
                    mediaPlayer = MediaPlayer().apply {
                        setAudioStreamType(android.media.AudioManager.STREAM_ALARM)
                        setDataSource(this@AlarmForegroundService, ringtoneUri)
                        setOnPreparedListener {
                            it.start()
                            it.isLooping = true
                            it.setVolume(1.0f, 1.0f)
                            Log.d(TAG, "Using system alarm sound with STREAM_ALARM")
                        }
                        prepareAsync()
                    }
                } catch (e3: Exception) {
                    Log.e(TAG, "All sound loading methods failed: ${e3.message}")
                }
            }
        }
    }

    private fun stopAlarm() {
        Log.d(TAG, "Stopping alarm")
        
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        
        waterDetector?.stopListening()
        waterDetector?.dispose()
        waterDetector = null
        
        wakeLock?.release()
        wakeLock = null
        
        stopForeground(true)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Plays alarm sound and detects water"
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("alarm_id", alarmId)
            putExtra("alarm_label", alarmLabel)
            putExtra("from_notification", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            alarmId, // Use alarmId as request code to make it unique
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val stopIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            alarmId + 1000, // Unique request code for stop
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔔 $alarmLabel")
            .setContentText("Alarm is ringing! Turn on faucet to stop.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm()
        Log.d(TAG, "Service destroyed")
    }
}

