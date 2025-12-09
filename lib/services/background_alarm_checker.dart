import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alarm_service.dart';
import 'notification_service.dart';
import 'debug_logger.dart';
import '../models/alarm.dart';
import '../main.dart';
import '../pages/alarm_ringing_page.dart';

class BackgroundAlarmChecker {
  static final BackgroundAlarmChecker _instance = BackgroundAlarmChecker._internal();
  factory BackgroundAlarmChecker() => _instance;
  BackgroundAlarmChecker._internal();

  Timer? _checkTimer;
  final AlarmService _alarmService = AlarmService();
  final NotificationService _notificationService = NotificationService();
  Set<String> _triggeredAlarms = {}; // Track which alarms already fired today
  
  bool isRunning() => _checkTimer != null && _checkTimer!.isActive;

  void start() {
    // Always restart to ensure it's running
    _checkTimer?.cancel();
    
    final logger = DebugLogger();
    logger.log('🔄 Starting background alarm checker...');
    print('🔄 Starting background alarm checker...');
    
    // Check immediately
    _checkAlarms();
    
    // Check every 10 seconds for more reliability
    _checkTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkAlarms();
    });
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    print('⏹️ Background alarm checker stopped');
  }

  Future<void> _checkAlarms() async {
    final logger = DebugLogger();
    try {
      final alarms = await _alarmService.loadAlarms();
      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final todayKey = '${now.year}-${now.month}-${now.day}';
      
      // Log check activity
      logger.log('🔍 Checking ${alarms.length} alarms at $currentTime:${now.second.toString().padLeft(2, '0')}');
      
      int activeCount = 0;
      for (int i = 0; i < alarms.length; i++) {
        final alarm = alarms[i];
        
        // Skip if inactive
        if (!alarm.isActive) continue;
        activeCount++;
        
        // Check if alarm time matches current time (within current minute)
        if (alarm.time == currentTime) {
          final alarmKey = '$todayKey-$i-${alarm.time}';
          
          // Check if this alarm already fired today
          if (!_triggeredAlarms.contains(alarmKey)) {
            // For repeating alarms, verify today is a repeat day
            if (alarm.repeatDays.isNotEmpty) {
              final currentWeekday = now.weekday; // 1=Monday, 7=Sunday
              final alarmWeekday = currentWeekday == 7 ? 0 : currentWeekday; // Convert to 0=Sunday format
              
              if (!alarm.repeatDays.contains(alarmWeekday)) {
                logger.log('⏭️ Alarm [$i] ${alarm.label} skipped - not a repeat day');
                continue; // Not a repeat day, skip
              }
            }
            
            logger.log('🔔 Alarm time reached! [$i] ${alarm.label} at ${alarm.time}');
            print('🔔 Alarm time reached! ${alarm.label} at ${alarm.time}');
            _triggeredAlarms.add(alarmKey);
            await triggerAlarm(alarm, i);
          } else {
            logger.log('⏭️ Alarm [$i] ${alarm.label} already triggered today');
          }
        }
      }
      
      if (activeCount > 0) {
        logger.log('✅ Checked $activeCount active alarms, ${_triggeredAlarms.length} triggered today');
      }
      
      // Clean up old triggered alarms (older than today)
      final beforeCleanup = _triggeredAlarms.length;
      _triggeredAlarms.removeWhere((key) => !key.startsWith(todayKey));
      if (beforeCleanup != _triggeredAlarms.length) {
        logger.log('🧹 Cleaned up ${beforeCleanup - _triggeredAlarms.length} old triggered alarms');
      }
      
    } catch (e, stackTrace) {
      logger.log('❌ Error checking alarms: $e');
      print('❌ Error checking alarms: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Make _triggerAlarm public for testing
  Future<void> triggerAlarm(Alarm alarm, int alarmId) async {
    final logger = DebugLogger();
    logger.log('🚀 Triggering alarm [$alarmId]: ${alarm.label} at ${alarm.time}');
    print('🔔 Triggering alarm: ${alarm.label} at ${alarm.time}');
    
    try {
      // Start foreground service FIRST to play alarm sound automatically
      logger.log('📱 Starting foreground service...');
      await _notificationService.startAlarmServiceFromNotification(alarmId);
      logger.log('✅ Foreground service started');
      
      // Show notification
      logger.log('📢 Showing notification...');
      await _notificationService.notifications.show(
        alarmId + 10000, // Use different ID to avoid conflicts
        '🔔 ${alarm.label}',
        'Time to wake up!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarm Notifications',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
        ),
        payload: alarmId.toString(),
      );
      logger.log('✅ Notification shown');
      
      // Navigate to alarm page if app is running (for UI)
      if (navigatorKey.currentState != null) {
        logger.log('📱 Navigating to alarm page...');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AlarmRingingPage(alarm: alarm),
          ),
        );
        logger.log('✅ Navigation completed');
      } else {
        logger.log('⚠️ Navigator not available - app may be in background');
      }
      
      logger.log('✅ Alarm trigger completed successfully');
    } catch (e, stackTrace) {
      logger.log('❌ Error triggering alarm: $e');
      print('❌ Error triggering alarm: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void resetToday() {
    // Reset triggered alarms (useful for testing)
    _triggeredAlarms.clear();
  }
}

