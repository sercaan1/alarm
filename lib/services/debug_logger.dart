import 'dart:collection';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final Queue<String> _logs = Queue<String>();
  final int _maxLogs = 200; // Keep last 200 logs

  void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:MM:SS
    final logEntry = '[$timestamp] $message';
    
    _logs.add(logEntry);
    
    // Keep only last _maxLogs entries
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    
    // Also print to console
    print(logEntry);
  }

  List<String> getLogs() {
    return _logs.toList().reversed.toList(); // Most recent first
  }

  void clear() {
    _logs.clear();
  }

  int get count => _logs.length;
}

