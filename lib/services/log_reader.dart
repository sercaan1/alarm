import 'package:flutter/services.dart';

class LogReader {
  static const platform = MethodChannel('com.example.alarm/water_logs');

  static Future<String> getLogs() async {
    try {
      final logs = await platform.invokeMethod<String>('getLogs');
      return logs ?? 'No logs found.';
    } on PlatformException catch (e) {
      return 'Error reading logs: ${e.message}';
    }
  }
}
