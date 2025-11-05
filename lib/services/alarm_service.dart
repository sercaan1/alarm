import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/alarm.dart';

class AlarmService {
  static const String _alarmsKey = 'alarms';

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
  }

  Future<void> addAlarm(Alarm alarm, List<Alarm> currentAlarms) async {
    currentAlarms.add(alarm);
    await saveAlarms(currentAlarms);
  }

  Future<void> deleteAlarms(
    List<int> indices,
    List<Alarm> currentAlarms,
  ) async {
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));
    for (var index in sortedIndices) {
      currentAlarms.removeAt(index);
    }
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
