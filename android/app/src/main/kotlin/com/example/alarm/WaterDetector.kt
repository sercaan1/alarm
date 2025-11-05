// ============================================
// android/app/src/main/kotlin/com/example/alarm/WaterDetector.kt
// ============================================
package com.example.alarm

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import org.tensorflow.lite.task.audio.classifier.AudioClassifier
import kotlinx.coroutines.*

class WaterDetector(private val context: Context) {
    private var audioClassifier: AudioClassifier? = null
    private var audioRecord: AudioRecord? = null
    private var isListening = false
    private var detectionJob: Job? = null
    
    companion object {
        private const val TAG = "WaterDetector"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_FLOAT
        
        private val WATER_LABELS = listOf(
            "water",
            "Water tap, faucet",
            "Tap",
            "Faucet",
            "Running water",
            "Stream",
            "Pour",
            "Liquid",
            "Sink (filling or washing)",
            "Spray",
            "Hiss",
            "Steam"
        )
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
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error: ${e.message}")
            Log.e(TAG, "Stack: ${e.stackTraceToString()}")
            
            try {
                Log.d(TAG, "🔍 Trying: assets/yamnet.tflite")
                audioClassifier = AudioClassifier.createFromFile(context, "assets/yamnet.tflite")
                Log.d(TAG, "✅ Model loaded from assets/")
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
                return
            }
            
            audioRecord?.startRecording()
            isListening = true
            
            Log.d(TAG, "🎤 Started listening for water sounds")
            
            detectionJob = CoroutineScope(Dispatchers.IO).launch {
                detectWaterSound()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting recording: ${e.message}")
            Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
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
    }

    private val prefs: SharedPreferences = context.getSharedPreferences("alarm_logs", Context.MODE_PRIVATE)
    
    private suspend fun detectWaterSound() {
        val tensorAudio = audioClassifier?.createInputTensorAudio()
        
        while (isListening && tensorAudio != null) {
            try {
                tensorAudio.load(audioRecord)
                val results = audioClassifier?.classify(tensorAudio)
                
                results?.let { classifications ->
                    val topSounds = classifications.flatMap { it.categories }
                        .sortedByDescending { it.score }
                        .take(5)
                    
                    val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US)
                        .format(java.util.Date())
                    
                    val logMessage = "[$timestamp] " + topSounds.joinToString(" | ") { 
                        "${it.label}: %.2f".format(it.score) 
                    }
                    
                    // SharedPreferences'e yaz
                    saveLog(logMessage)
                    
                    // Su sesi kontrolü
                    for (category in classifications.flatMap { it.categories }) {
                        if (isWaterLabel(category.label) && category.score > 0.2f) {
                            val detectionLog = "[$timestamp] 💧 WATER: ${category.label} (${category.score})"
                            saveLog(detectionLog)
                            
                            withContext(Dispatchers.Main) {
                                onWaterDetected?.invoke()
                            }
                            
                            stopListening()
                            return
                        }
                    }
                }
                
                delay(500)
                
            } catch (e: Exception) {
                Log.e(TAG, "Detection error: ${e.message}")
            }
        }
    }
    
    private fun saveLog(log: String) {
        try {
            val currentLogs = prefs.getString("logs", "") ?: ""
            val newLogs = "$log\n$currentLogs"
            prefs.edit().putString("logs", newLogs.take(10000)).apply() // Max 10KB
        } catch (e: Exception) {
            Log.e(TAG, "Error saving log: ${e.message}")
        }
    }
    
    private fun isWaterLabel(label: String): Boolean {
        return WATER_LABELS.any { waterLabel ->
            label.contains(waterLabel, ignoreCase = true)
        }
    }
    
    fun dispose() {
        stopListening()
        audioClassifier?.close()
        audioClassifier = null
        Log.d(TAG, "🗑️ Resources disposed")
    }
}