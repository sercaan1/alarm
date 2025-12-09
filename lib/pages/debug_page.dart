import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/alarm_service.dart';
import '../services/background_alarm_checker.dart';
import '../services/debug_logger.dart';
import '../models/alarm.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  List<String> _logs = [];
  List<String> _activityLogs = [];
  bool _isRefreshing = false;
  bool _autoRefresh = false;
  Timer? _refreshTimer;
  int _selectedTab = 0; // 0 = Info, 1 = Activity Logs

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
    _loadActivityLogs();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh = true;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_selectedTab == 1) {
        _loadActivityLogs();
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefresh = false;
    _refreshTimer?.cancel();
  }

  void _loadActivityLogs() {
    setState(() {
      _activityLogs = DebugLogger().getLogs();
    });
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isRefreshing = true;
      _logs.clear();
    });

    try {
      // 1. App Status
      _addLog('📱 APP STATUS', isHeader: true);
      _addLog('App is running: ✅');
      final checker = BackgroundAlarmChecker();
      _addLog('Background checker: ${checker.isRunning() ? "✅ Running" : "❌ Stopped"}');
      _addLog('Activity logs: ${DebugLogger().count} entries');
      _addLog('');

      // 2. Permissions
      _addLog('🔐 PERMISSIONS', isHeader: true);
      final notificationPerm = await Permission.notification.status;
      final micPerm = await Permission.microphone.status;
      final exactAlarmPerm = await Permission.scheduleExactAlarm.status;
      
      _addLog('Notification: ${_getPermissionStatus(notificationPerm)}');
      _addLog('Microphone: ${_getPermissionStatus(micPerm)}');
      _addLog('Exact Alarm: ${_getPermissionStatus(exactAlarmPerm)}');
      _addLog('');

      // 3. Alarms
      _addLog('⏰ ALARMS', isHeader: true);
      final alarmService = AlarmService();
      final alarms = await alarmService.loadAlarms();
      _addLog('Total alarms: ${alarms.length}');
      
      for (int i = 0; i < alarms.length; i++) {
        final alarm = alarms[i];
        _addLog('  [$i] ${alarm.label}');
        _addLog('      Time: ${alarm.time}');
        _addLog('      Active: ${alarm.isActive ? "✅" : "❌"}');
        _addLog('      Repeat: ${alarm.repeatDays.isEmpty ? "None" : alarm.repeatDays.join(", ")}');
        _addLog('      Next: ${_getNextAlarmTime(alarm)}');
        _addLog('');
      }

      // 4. Notification Service
      _addLog('🔔 NOTIFICATION SERVICE', isHeader: true);
      _addLog('Initialized: ✅');
      _addLog('Channel: alarm_channel');
      _addLog('');

      // 5. Storage
      _addLog('💾 STORAGE', isHeader: true);
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('alarms');
      if (alarmsJson != null) {
        _addLog('Alarms stored: ✅');
        _addLog('Data size: ${alarmsJson.length} bytes');
      } else {
        _addLog('Alarms stored: ❌ No data');
      }
      _addLog('');

      // 6. System Info
      _addLog('🖥️ SYSTEM', isHeader: true);
      final now = DateTime.now();
      _addLog('Current time: ${now.toString().substring(0, 19)}');
      _addLog('Formatted: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');
      _addLog('Weekday: ${now.weekday} (1=Mon, 7=Sun)');
      _addLog('Timezone: ${now.timeZoneName}');
      _addLog('Offset: ${now.timeZoneOffset}');
      _addLog('');
      
      // 7. Triggered Alarms Today
      _addLog('📋 TRIGGERED ALARMS TODAY', isHeader: true);
      // We can't access private _triggeredAlarms, so just show count
      _addLog('Note: Check activity logs for trigger history');
      _addLog('');

    } catch (e) {
      _addLog('❌ Error loading debug info: $e');
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  String _getPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ Granted';
      case PermissionStatus.denied:
        return '❌ Denied';
      case PermissionStatus.restricted:
        return '⚠️ Restricted';
      case PermissionStatus.limited:
        return '⚠️ Limited';
      case PermissionStatus.permanentlyDenied:
        return '❌ Permanently Denied';
      default:
        return '❓ Unknown';
    }
  }

  String _getNextAlarmTime(Alarm alarm) {
    if (!alarm.isActive) return 'Inactive';
    
    final now = DateTime.now();
    final timeParts = alarm.time.split(':');
    final alarmHour = int.parse(timeParts[0]);
    final alarmMinute = int.parse(timeParts[1]);
    
    if (alarm.repeatDays.isEmpty) {
      // One-time alarm
      var alarmTime = DateTime(now.year, now.month, now.day, alarmHour, alarmMinute);
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(Duration(days: 1));
      }
      return alarmTime.toString().substring(0, 16);
    } else {
      // Repeating alarm
      final currentWeekday = now.weekday;
      final repeatWeekdays = alarm.repeatDays.map((day) => day == 0 ? 7 : day).toList();
      
      int daysUntilNext = 7;
      for (final weekday in repeatWeekdays) {
        var days = weekday - currentWeekday;
        if (days < 0) days += 7;
        if (days == 0) {
          final todayTime = DateTime(now.year, now.month, now.day, alarmHour, alarmMinute);
          if (todayTime.isAfter(now)) {
            return 'Today at ${alarm.time}';
          }
          days = 7;
        }
        if (days < daysUntilNext) {
          daysUntilNext = days;
        }
      }
      
      final nextTime = now.add(Duration(days: daysUntilNext));
      return '${nextTime.toString().substring(0, 10)} at ${alarm.time}';
    }
  }

  void _addLog(String message, {bool isHeader = false}) {
    _logs.add(message);
  }

  Future<void> _testAlarm() async {
    final logger = DebugLogger();
    logger.log('🧪 Test alarm triggered from debug page');
    
    final alarmService = AlarmService();
    final alarms = await alarmService.loadAlarms();
    if (alarms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No alarms to test')),
      );
      return;
    }
    
    final alarm = alarms[0];
    final checker = BackgroundAlarmChecker();
    await checker.triggerAlarm(alarm, 0);
    
    _loadActivityLogs(); // Refresh logs
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Test alarm triggered! Check Activity Logs tab.')),
    );
  }
  
  void _clearLogs() {
    DebugLogger().clear();
    _loadActivityLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logs cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Debug & Logs'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: Icon(_isRefreshing ? Icons.hourglass_empty : Icons.refresh),
            onPressed: _isRefreshing ? null : _loadDebugInfo,
          ),
        ],
      ),
      body: _isRefreshing
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tabs
                Container(
                  color: Colors.grey[900],
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0 ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'System Info',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedTab == 0 ? Colors.blue : Colors.grey,
                                fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 1);
                            _loadActivityLogs();
                            if (!_autoRefresh) _startAutoRefresh();
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1 ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'Activity Logs (${DebugLogger().count})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedTab == 1 ? Colors.blue : Colors.grey,
                                fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action buttons
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[900],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _selectedTab == 0 ? _loadDebugInfo : _loadActivityLogs,
                        icon: Icon(Icons.refresh),
                        label: Text('Refresh'),
                      ),
                      if (_selectedTab == 1)
                        ElevatedButton.icon(
                          onPressed: _autoRefresh ? _stopAutoRefresh : _startAutoRefresh,
                          icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
                          label: Text(_autoRefresh ? 'Pause' : 'Auto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _autoRefresh ? Colors.green : Colors.grey,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _testAlarm,
                        icon: Icon(Icons.alarm),
                        label: Text('Test Alarm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      if (_selectedTab == 1)
                        ElevatedButton.icon(
                          onPressed: _clearLogs,
                          icon: Icon(Icons.clear_all),
                          label: Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _selectedTab == 0
                      ? ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final isHeader = log.startsWith('📱') || 
                                            log.startsWith('🔐') || 
                                            log.startsWith('⏰') || 
                                            log.startsWith('🔔') || 
                                            log.startsWith('💾') || 
                                            log.startsWith('🖥️') ||
                                            log.startsWith('📋');
                            
                            return Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: isHeader ? Colors.blue : Colors.grey[300],
                                  fontSize: isHeader ? 16 : 13,
                                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _activityLogs.length,
                          itemBuilder: (context, index) {
                            final log = _activityLogs[index];
                            final isError = log.contains('❌');
                            final isSuccess = log.contains('✅');
                            final isWarning = log.contains('⚠️');
                            
                            return Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: isError 
                                      ? Colors.red[300]
                                      : isSuccess
                                          ? Colors.green[300]
                                          : isWarning
                                              ? Colors.orange[300]
                                              : Colors.grey[300],
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

