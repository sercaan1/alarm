// ============================================
// android/app/src/main/kotlin/com/example/alarm/WaterDetector.kt
// IMPROVED VERSION - Cumulative Detection + Negative Filter
// ============================================
package com.example.alarm

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.*
import org.tensorflow.lite.task.audio.classifier.AudioClassifier
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date

class WaterDetector(private val context: Context) {
    private var audioClassifier: AudioClassifier? = null
    private var audioRecord: AudioRecord? = null
    private var isListening = false
    private var detectionJob: Job? = null
    private val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    
    companion object {
        private const val TAG = "WaterDetector"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_FLOAT
        
        // 💧 Water-related labels (expanded from your logs)
        private val WATER_LABELS = listOf(
            "Water",
            "Water tap, faucet",
            "Sink (filling or washing)",  // ⭐ Most common in your logs!
            "Toilet flush",
            "Fill (with liquid)",
            "Liquid",
            "Drip",
            "Steam",
            "Pour",
            "Spray",
            "Tap",
            "Faucet",
            "Running water",
            "Stream",
            "Hiss"  // Often appears with water
        )
        
        // 🚫 Sounds to IGNORE (definite non-water)
        private val IGNORE_LABELS = listOf(
            "Snoring",
            "Breathing",
            "Speech",
            "Music",
            "Silence",
            "Tools",
            "Drill",
            "Power tool",
            "Chainsaw",
            "Sewing machine",
            "Blender",
            "Fart",
            "Animal",
            "Pig",
            "Grunt"
        )
        
        // 🎯 Simple and fast detection
        private const val WATER_THRESHOLD = 0.12f  // Lower = faster detection
    }
    
    var onWaterDetected: (() -> Unit)? = null
    var onLogMessage: ((String) -> Unit)? = null
    
    fun initialize(): Boolean {
        return try {
            Log.d(TAG, "🔍 Trying: flutter_assets/assets/yamnet.tflite")
            
            audioClassifier = AudioClassifier.createFromFile(
                context, 
                "flutter_assets/assets/yamnet.tflite"
            )
            
            Log.d(TAG, "✅ Model loaded!")
            prefs.edit().putString("logs", "").apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error: ${e.message}")
            Log.e(TAG, "Stack: ${e.stackTraceToString()}")
            
            try {
                Log.d(TAG, "🔍 Trying: assets/yamnet.tflite")
                audioClassifier = AudioClassifier.createFromFile(context, "assets/yamnet.tflite")
                Log.d(TAG, "✅ Model loaded from assets/")
                prefs.edit().putString("logs", "").apply()
                true
            } catch (e2: Exception) {
                Log.e(TAG, "❌ All paths failed")
                false
            }
        }
    }
    
    fun startListening() {
        if (isListening) {
            Log.w(TAG, "Already listening")
            return
        }
        
        if (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) 
            != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "❌ Microphone permission not granted!")
            saveLog("❌ Microphone permission denied")
            return
        }
        
        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT
            )
            
            if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
                Log.e(TAG, "❌ Invalid buffer size: $bufferSize")
                saveLog("❌ Invalid buffer size")
                return
            }
            
            Log.d(TAG, "📏 Buffer size: $bufferSize")
            
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )
            
            val state = audioRecord?.state
            if (state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "❌ AudioRecord not initialized, state: $state")
                saveLog("❌ AudioRecord not initialized")
                return
            }
            
            audioRecord?.startRecording()
            isListening = true
            
            Log.d(TAG, "🎤 Started listening for water sounds")
            saveLog("🎤 Started listening...")
            
            detectionJob = CoroutineScope(Dispatchers.IO).launch {
                detectWaterSound()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting recording: ${e.message}")
            saveLog("❌ Error: ${e.message}")
            isListening = false
        }
    }
    
    fun stopListening() {
        if (!isListening) return
        
        isListening = false
        detectionJob?.cancel()
        
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        
        Log.d(TAG, "🔇 Stopped listening")
        saveLog("🔇 Stopped")
    }
    
    private suspend fun detectWaterSound() {
        val tensorAudio = audioClassifier?.createInputTensorAudio()
        
        while (isListening && tensorAudio != null) {
            try {
                tensorAudio.load(audioRecord)
                val results = audioClassifier?.classify(tensorAudio)
                
                results?.let { classifications ->
                    val allCategories = classifications.flatMap { it.categories }
                    val topSounds = allCategories
                        .sortedByDescending { it.score }
                        .take(5)
                    
                    val timestamp = SimpleDateFormat("HH:mm:ss", Locale.US).format(Date())
                    
                    // Log top 5 sounds
                    val logMessage = "[$timestamp] " + topSounds.joinToString(" | ") { 
                        "${it.label}: %.2f".format(it.score) 
                    }
                    Log.d(TAG, logMessage)
                    saveLog(logMessage)
                    
                    // 🎯 SIMPLE DETECTION: Check for water, ignore bad sounds
                    val waterDetection = analyzeForWater(allCategories, timestamp)
                    
                    if (waterDetection != null) {
                        val detectionLog = "[$timestamp] ✅ WATER DETECTED: ${waterDetection.label} (${waterDetection.score})"
                        Log.d(TAG, detectionLog)
                        saveLog(detectionLog)
                        
                        withContext(Dispatchers.Main) {
                            onWaterDetected?.invoke()
                        }
                        
                        stopListening()
                        return
                    }
                }
                
                delay(500)
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error: ${e.message}")
                saveLog("❌ Detection error: ${e.message}")
            }
        }
    }
    
    /**
     * 🎯 NEW: Analyze sounds for water with negative filtering
     * Returns the water category if detected, null otherwise
     */
    private fun analyzeForWater(categories: List<org.tensorflow.lite.support.label.Category>, timestamp: String): org.tensorflow.lite.support.label.Category? {
        // 🚫 First: Check if there are any IGNORE sounds with high confidence
        val hasIgnoredSound = categories.any { category ->
            IGNORE_LABELS.any { ignored -> 
                category.label.contains(ignored, ignoreCase = true) && category.score > 0.25f
            }
        }
        
        if (hasIgnoredSound) {
            // Log why we're ignoring
            val ignoredSound = categories.first { category ->
                IGNORE_LABELS.any { ignored -> 
                    category.label.contains(ignored, ignoreCase = true) && category.score > 0.25f
                }
            }
            Log.d(TAG, "[$timestamp] 🚫 Ignoring due to: ${ignoredSound.label} (${ignoredSound.score})")
            return null
        }
        
        // 💧 Then: Look for water sounds
        for (category in categories) {
            if (isWaterLabel(category.label) && category.score > WATER_THRESHOLD) {
                return category
            }
        }
        
        return null
    }
    
    private fun saveLog(log: String) {
        try {
            val key = "flutter.logs"
            val currentLogs = prefs.getString(key, "") ?: ""
            val newLogs = "$log\n$currentLogs"
            prefs.edit().putString(key, newLogs.take(10000)).apply()

            // Dosyaya da yaz
            saveLogToFile(log)
        } catch (e: Exception) {
            Log.e(TAG, "Error saving log: ${e.message}")
        }
    }
    
    private fun isWaterLabel(label: String): Boolean {
        return WATER_LABELS.any { waterLabel ->
            label.contains(waterLabel, ignoreCase = true)
        }
    }

    private fun saveLogToFile(log: String) {
        try {
            val logDir = File(context.filesDir, "logs")
            if (!logDir.exists()) logDir.mkdirs()

            val logFile = File(logDir, "water_logs.txt")

            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val line = "[$timestamp] $log\n"

            logFile.appendText(line)
        } catch (e: Exception) {
            Log.e(TAG, "Error writing log file: ${e.message}")
        }
    }

    fun readLogs(): String {
        return try {
            val logDir = File(context.filesDir, "logs")
            val logFile = File(logDir, "water_logs.txt")
            if (logFile.exists()) {
                logFile.readText()
            } else {
                "No logs file found."
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading log file: ${e.message}")
            "Error reading logs: ${e.message}"
        }
    }
    
    fun dispose() {
        stopListening()
        audioClassifier?.close()
        audioClassifier = null
        Log.d(TAG, "🗑️ Resources disposed")
    }
}