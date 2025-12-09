import 'package:flutter/material.dart';
import 'dart:async';
import 'pages/home_page.dart';
import 'pages/alarm_ringing_page.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/background_alarm_checker.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Set notification tap handler callback
  notificationService.onAlarmTapped = (int alarmId) async {
    print('🔔 onAlarmTapped called with alarmId: $alarmId');
    try {
      final alarmService = AlarmService();
      final alarms = await alarmService.loadAlarms();
      print('📋 Loaded ${alarms.length} alarms');
      if (alarmId < alarms.length) {
        final alarm = alarms[alarmId];
        print('✅ Opening AlarmRingingPage for: ${alarm.label}');

        // Wait for app/widget tree to be ready
        await Future.delayed(Duration(milliseconds: 300));

        // Try to navigate - if navigator isn't ready, MainActivity will handle it
        final navigator = navigatorKey.currentState;
        if (navigator != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => AlarmRingingPage(alarm: alarm),
              settings: RouteSettings(name: '/alarm_ringing'),
            ),
          );
          print('✅ Navigation successful');
        } else {
          print('⚠️ Navigator not ready - MainActivity should handle opening');
        }
      } else {
        print('❌ Alarm ID $alarmId out of range (max: ${alarms.length - 1})');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling notification tap: $e');
      print('Stack trace: $stackTrace');
    }
  };

  // Start background alarm checker
  final backgroundChecker = BackgroundAlarmChecker();
  backgroundChecker.start();

  // Ensure it keeps running - restart if needed
  Timer.periodic(Duration(minutes: 1), (timer) {
    if (!backgroundChecker.isRunning()) {
      print('⚠️ Background checker stopped, restarting...');
      backgroundChecker.start();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Alarm',
      theme: ThemeData.dark(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
