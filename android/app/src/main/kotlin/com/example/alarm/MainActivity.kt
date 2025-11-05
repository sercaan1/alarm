package com.example.alarm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.alarm/water_detector"
    private var waterDetector: WaterDetector? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    waterDetector = WaterDetector(this)
    
    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    
    channel.setMethodCallHandler { call, result ->
        when (call.method) {
            "initialize" -> {
                val success = waterDetector?.initialize() ?: false
                result.success(success)
            }
            "startListening" -> {
                waterDetector?.onWaterDetected = {
                    channel.invokeMethod("onWaterDetected", null)
                }
                waterDetector?.onLogMessage = { log ->  // 👈 YENİ
                    channel.invokeMethod("onLog", log)
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
}
    
    override fun onDestroy() {
        waterDetector?.dispose()
        super.onDestroy()
    }
}