import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/alarm.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  // Expose notifications for background checker
  FlutterLocalNotificationsPlugin get notifications => _notifications;
  static const MethodChannel _alarmServiceChannel =
      MethodChannel('com.example.alarm/alarm_service');
  bool _initialized = false;

  // Initialize notifications
  Future<bool> initialize() async {
    if (_initialized) {
      print('ℹ️ NotificationService already initialized, requesting permissions again...');
      await _requestAndroidPermissions();
      return true;
    }

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings (for future use)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Create a custom notification tap handler that starts the service
    final bool? initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Notification response received: ${response.actionId}, payload: ${response.payload}');
        _onNotificationTapped(response);
        // Don't start service here - background checker or MainActivity will handle it
      },
    );

    if (initialized == true) {
      _initialized = true;
      
      // Request Android 13+ notification permission
      await _requestAndroidPermissions();
      
      return true;
    }

    return false;
  }

  Future<void> _requestAndroidPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final notificationPermission = await androidImplementation.requestNotificationsPermission();
      print('📱 Notification permission: $notificationPermission');
      
      final exactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
      print('⏰ Exact alarm permission: $exactAlarmPermission');
      
      if (exactAlarmPermission == false) {
        print('⚠️ WARNING: Exact alarm permission denied! Alarms may not work.');
        print('⚠️ Go to Settings → Apps → Alarm → Special app access → Alarms & reminders');
      }
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped! Payload: ${response.payload}');
    if (response.payload != null) {
      final alarmId = int.tryParse(response.payload!);
      if (alarmId != null) {
        print('🔔 Calling onAlarmTapped for alarm ID: $alarmId');
        onAlarmTapped?.call(alarmId);
      }
    }
  }

  // Schedule an alarm notification
  Future<void> scheduleAlarm(Alarm alarm, int alarmId) async {
    print('📅 Scheduling alarm ID $alarmId: ${alarm.label} at ${alarm.time}');
    
    if (!alarm.isActive) {
      print('⏸️ Alarm is inactive, cancelling');
      await cancelAlarm(alarmId);
      return;
    }

    await initialize();

    final timeParts = alarm.time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    print('⏰ Alarm time: $hour:$minute');

    // Android notification details - will trigger foreground service
    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Notifications',
      channelDescription: 'Notifications for alarm clock',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // Service will handle sound
      enableVibration: true,
      fullScreenIntent: true, // Show full screen when alarm rings
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (alarm.repeatDays.isEmpty) {
      // One-time alarm
      final now = DateTime.now();
      var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);

      // If time has passed today, schedule for tomorrow
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      final scheduledTime = tz.TZDateTime.from(alarmTime, tz.local);
      print('✅ Scheduling notification for: $scheduledTime');
      print('📱 Payload will be: $alarmId');
      
      await _notifications.zonedSchedule(
        alarmId,
        alarm.label,
        'Time to wake up!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: alarmId.toString(), // Pass alarm ID as payload
      );
      
      print('✅ Notification scheduled successfully!');
    } else {
      // Repeating alarm - schedule for each selected day
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1=Monday, 7=Sunday

      // Convert repeatDays (0=Sunday) to weekday format (1=Monday)
      final weekdays = alarm.repeatDays.map((day) {
        // Convert: 0=Sun -> 7, 1=Mon -> 1, 2=Tue -> 2, ..., 6=Sat -> 6
        return day == 0 ? 7 : day;
      }).toList();

      for (final weekday in weekdays) {
        var daysUntilNext = weekday - currentWeekday;
        if (daysUntilNext < 0) {
          daysUntilNext += 7;
        }
        // If same day but time passed, schedule for next week
        if (daysUntilNext == 0) {
          final todayTime = DateTime(now.year, now.month, now.day, hour, minute);
          if (todayTime.isBefore(now)) {
            daysUntilNext = 7;
          }
        }

        final alarmTime = now.add(Duration(days: daysUntilNext));
        final scheduledTime = DateTime(
          alarmTime.year,
          alarmTime.month,
          alarmTime.day,
          hour,
          minute,
        );

        // Use unique ID for each day: alarmId * 10 + weekday
        final notificationId = alarmId * 10 + weekday;

        await _notifications.zonedSchedule(
          notificationId,
          alarm.label,
          'Time to wake up!',
          tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: alarmId.toString(),
        );
      }
    }
  }

  // Cancel an alarm notification
  Future<void> cancelAlarm(int alarmId) async {
    // Cancel one-time alarm
    await _notifications.cancel(alarmId);

    // Cancel all repeating alarms (for each weekday 1-7)
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _notifications.cancel(alarmId * 10 + weekday);
    }
  }

  // Cancel all alarms
  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }

  // Start alarm service from notification (public for background checker)
  Future<void> startAlarmServiceFromNotification(int alarmId) async {
    try {
      // Load alarm label from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('alarms');
      String alarmLabel = 'Alarm';
      
      if (alarmsJson != null) {
        try {
          final alarms = jsonDecode(alarmsJson) as List;
          if (alarmId < alarms.length) {
            alarmLabel = alarms[alarmId]['label'] ?? 'Alarm';
          }
        } catch (e) {
          print('Error parsing alarm label: $e');
        }
      }
      
      print('🔊 Starting alarm service for: $alarmLabel');
      await _alarmServiceChannel.invokeMethod('startAlarm', {
        'alarmId': alarmId,
        'alarmLabel': alarmLabel,
      });
    } catch (e) {
      print('❌ Error starting alarm service: $e');
    }
  }

  // Stop alarm service
  Future<void> stopAlarmService() async {
    try {
      await _alarmServiceChannel.invokeMethod('stopAlarm');
    } catch (e) {
      print('Error stopping alarm service: $e');
    }
  }

  // Test notification - fire immediately
  Future<void> testNotificationImmediate() async {
    await initialize();
    
    print('🧪 Showing immediate test notification...');
    
    await _notifications.show(
      9998,
      '🧪 Immediate Test',
      'If you see this, notification channel works!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: 'immediate_test',
    );
    
    print('✅ Immediate notification shown');
  }

  // Test notification - fire in X seconds
  Future<void> testNotification(int secondsFromNow) async {
    await initialize();
    
    // First test immediate notification
    await testNotificationImmediate();
    
    // Then test scheduled
    final now = DateTime.now();
    final testTime = now.add(Duration(seconds: secondsFromNow));
    
    print('🧪 Testing scheduled notification - should fire in $secondsFromNow seconds');
    print('🧪 Scheduled time: $testTime');
    print('🧪 Current time: $now');
    
    try {
      await _notifications.zonedSchedule(
        9999,
        '🧪 Scheduled Test',
        'If you see this in $secondsFromNow seconds, scheduling works!',
        tz.TZDateTime.from(testTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarm Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'scheduled_test',
      );
      
      print('✅ Scheduled notification created successfully');
    } catch (e) {
      print('❌ ERROR scheduling notification: $e');
      // Try without exact mode
      try {
        await _notifications.zonedSchedule(
          9999,
          '🧪 Scheduled Test (fallback)',
          'If you see this, scheduling works!',
          tz.TZDateTime.from(testTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'alarm_channel',
              'Alarm Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exact,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'scheduled_test',
        );
        print('✅ Scheduled notification (fallback mode)');
      } catch (e2) {
        print('❌ ERROR with fallback: $e2');
      }
    }
  }

  // Set notification tap handler callback
  Function(int alarmId)? onAlarmTapped;
}

