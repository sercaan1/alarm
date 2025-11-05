class Alarm {
  String time; // "10:37"
  String label;
  bool isActive;
  List<int> repeatDays; // 0=Sunday, 1=Monday, ..., 6=Saturday
  bool is24HourFormat; // false = AM/PM

  Alarm({
    required this.time,
    required this.label,
    this.isActive = true,
    this.repeatDays = const [],
    this.is24HourFormat = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'label': label,
      'isActive': isActive,
      'repeatDays': repeatDays,
      'is24HourFormat': is24HourFormat,
    };
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      time: json['time'],
      label: json['label'] ?? 'Alarm',
      isActive: json['isActive'] ?? true,
      repeatDays: List<int>.from(json['repeatDays'] ?? []),
      is24HourFormat: json['is24HourFormat'] ?? false,
    );
  }

  String getTimeUntilAlarm() {
    final now = DateTime.now();
    final timeParts = time.split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(Duration(days: 1));
    }

    final difference = alarmTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return 'Ring in ${hours}h ${minutes}min';
  }

  String getRepeatText() {
    if (repeatDays.isEmpty) return 'Ring once';
    if (repeatDays.length == 7) return 'Every day';

    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    if (repeatDays.length == 5 &&
        repeatDays.contains(1) &&
        repeatDays.contains(2) &&
        repeatDays.contains(3) &&
        repeatDays.contains(4) &&
        repeatDays.contains(5)) {
      return 'Mon to Fri';
    }

    if (repeatDays.length == 2 &&
        repeatDays.contains(0) &&
        repeatDays.contains(6)) {
      return 'Weekends';
    }

    if (_isConsecutive()) {
      final sorted = [...repeatDays]..sort();
      return '${dayNames[sorted.first]} to ${dayNames[sorted.last]}';
    }

    final sorted = [...repeatDays]..sort();
    return sorted.map((d) => dayNames[d]).join(', ');
  }

  bool _isConsecutive() {
    if (repeatDays.length < 2) return false;
    final sorted = [...repeatDays]..sort();
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] - sorted[i] != 1) return false;
    }
    return true;
  }

  String getFormattedTime() {
    if (is24HourFormat) return time;

    final timeParts = time.split(':');
    int hour = int.parse(timeParts[0]);
    final minute = timeParts[1];

    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $period';
  }
}
