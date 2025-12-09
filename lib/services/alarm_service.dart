import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/alarm.dart';
import 'notification_service.dart';

class AlarmService {
  static const String _alarmsKey = 'alarms';
  final NotificationService _notificationService = NotificationService();

  Future<List<Alarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString(_alarmsKey);

    if (alarmsJson != null) {
      final List<dynamic> decoded = jsonDecode(alarmsJson);
      return decoded.map((json) => Alarm.fromJson(json)).toList();
    }

    return [];
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_alarmsKey, alarmsJson);
    
    // Schedule all alarms after saving
    await scheduleAllAlarms(alarms);
  }

  // Schedule all alarms
  Future<void> scheduleAllAlarms(List<Alarm> alarms) async {
    // Cancel all existing notifications first
    await _notificationService.cancelAllAlarms();
    
    // Schedule each alarm
    for (int i = 0; i < alarms.length; i++) {
      await _notificationService.scheduleAlarm(alarms[i], i);
    }
  }

  Future<void> addAlarm(Alarm alarm, List<Alarm> currentAlarms) async {
    currentAlarms.add(alarm);
    await saveAlarms(currentAlarms);
  }

  Future<void> deleteAlarms(
    List<int> indices,
    List<Alarm> currentAlarms,
  ) async {
    // Cancel notifications for alarms being deleted
    for (var index in indices) {
      await _notificationService.cancelAlarm(index);
    }
    
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));
    for (var index in sortedIndices) {
      currentAlarms.removeAt(index);
    }
    
    // Re-schedule remaining alarms with new indices
    await saveAlarms(currentAlarms);
  }

  Future<void> updateAlarm(
    int index,
    Alarm alarm,
    List<Alarm> currentAlarms,
  ) async {
    currentAlarms[index] = alarm;
    await saveAlarms(currentAlarms);
  }
}
