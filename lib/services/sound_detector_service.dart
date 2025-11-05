import 'package:flutter/services.dart';

class SoundDetectorService {
  static const platform = MethodChannel('com.example.alarm/water_detector');

  Function()? onWaterDetected;
  Function(String)? onLog; // 👈 YENİ: Log callback

  bool _isListening = false;
  bool get isListening => _isListening;

  SoundDetectorService() {
    platform.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onWaterDetected') {
      print('💧 Water detected from native!');
      _isListening = false;
      onWaterDetected?.call();
    } else if (call.method == 'onLog') {
      // 👈 YENİ: Native'den log geldi
      final log = call.arguments as String;
      onLog?.call(log);
    }
  }

  // Initialize the TensorFlow Lite model
  Future<bool> initialize() async {
    try {
      final bool result = await platform.invokeMethod('initialize');
      if (result) {
        print('✅ Water detector initialized');
      } else {
        print('❌ Failed to initialize water detector');
      }
      return result;
    } catch (e) {
      print('❌ Error initializing: $e');
      return false;
    }
  }

  // Start listening for water sounds
  Future<void> startListening() async {
    if (_isListening) {
      print('⚠️ Already listening');
      return;
    }

    try {
      await platform.invokeMethod('startListening');
      _isListening = true;
      print('🎤 Started listening for water sounds');
    } catch (e) {
      print('❌ Error starting listening: $e');
      _isListening = false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await platform.invokeMethod('stopListening');
      _isListening = false;
      print('🔇 Stopped listening');
    } catch (e) {
      print('❌ Error stopping listening: $e');
    }
  }

  // Dispose resources
  void dispose() {
    if (_isListening) {
      stopListening();
    }
  }
}
