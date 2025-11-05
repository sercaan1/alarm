import 'package:flutter/material.dart';
import '../models/alarm.dart';

class AddAlarmPage extends StatefulWidget {
  final Function(Alarm) onAlarmAdded;
  final Alarm? existingAlarm; // 👈 YENİ: Düzenleme için
  final int? alarmIndex; // 👈 YENİ: Hangi alarm güncelleniyor

  const AddAlarmPage({
    super.key,
    required this.onAlarmAdded,
    this.existingAlarm,
    this.alarmIndex,
  });

  @override
  State<AddAlarmPage> createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  late TimeOfDay selectedTime;
  late TextEditingController labelController;
  late Set<int> selectedDays;
  late bool vibrateEnabled;

  @override
  void initState() {
    super.initState();

    // 👈 YENİ: Eğer düzenleme modundaysa, mevcut değerleri yükle
    if (widget.existingAlarm != null) {
      final alarm = widget.existingAlarm!;
      final timeParts = alarm.time.split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      labelController = TextEditingController(text: alarm.label);
      selectedDays = Set.from(alarm.repeatDays);
      vibrateEnabled = true;
    } else {
      // Yeni alarm için default değerler
      selectedTime = TimeOfDay.now();
      labelController = TextEditingController(text: 'Alarm');
      selectedDays = {};
      vibrateEnabled = true;
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFFB71C1C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (selectedDays.contains(day)) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    });
  }

  void _saveAlarm() {
    final timeString =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    final alarm = Alarm(
      time: timeString,
      label: labelController.text.isEmpty ? 'Alarm' : labelController.text,
      isActive:
          widget.existingAlarm?.isActive ?? true, // 👈 YENİ: Mevcut durumu koru
      repeatDays: selectedDays.toList(),
      is24HourFormat: false,
    );

    widget.onAlarmAdded(alarm);
    Navigator.pop(context);
  }

  String _formatTime() {
    int hour = selectedTime.hour;
    final minute = selectedTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final isEditMode = widget.existingAlarm != null; // 👈 YENİ

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEditMode ? 'Edit alarm' : 'New alarm'), // 👈 YENİ
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Color(0xFFB71C1C)),
            onPressed: _saveAlarm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),

            GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text(
                      'Alarm will ring in ${_calculateTimeUntil()}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _formatTime(),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
            Divider(color: Colors.grey[800], height: 1),

            ListTile(
              title: Text('Repeat', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                _getRepeatSummary(),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: _showRepeatDialog,
            ),

            Divider(color: Colors.grey[800], height: 1),

            ListTile(
              title: Text('Alarm name', style: TextStyle(fontSize: 16)),
              subtitle: TextField(
                controller: labelController,
                style: TextStyle(color: Colors.grey[400]),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Alarm',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),

            Divider(color: Colors.grey[800], height: 1),

            ListTile(
              title: Text('Ringtone', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                'Water Sound',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () {},
            ),

            Divider(color: Colors.grey[800], height: 1),

            SwitchListTile(
              title: Text('Vibrate', style: TextStyle(fontSize: 16)),
              value: vibrateEnabled,
              activeColor: Color(0xFFB71C1C),
              onChanged: (value) {
                setState(() {
                  vibrateEnabled = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _calculateTimeUntil() {
    final now = DateTime.now();
    var alarmTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(Duration(days: 1));
    }

    final difference = alarmTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours == 0) {
      return '$minutes min.';
    } else if (hours < 24) {
      return '${hours}h ${minutes}min.';
    } else {
      final days = hours ~/ 24;
      return '$days day.';
    }
  }

  String _getRepeatSummary() {
    if (selectedDays.isEmpty) return 'Ring once';
    if (selectedDays.length == 7) return 'Every day';

    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sorted = selectedDays.toList()..sort();
    return sorted.map((d) => dayNames[d]).join(', ');
  }

  void _showRepeatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      builder: (context) => RepeatSelectionSheet(
        selectedDays: selectedDays,
        onDaysChanged: (days) {
          setState(() {
            selectedDays = days;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }
}

// RepeatSelectionSheet aynı kalıyor...
class RepeatSelectionSheet extends StatefulWidget {
  final Set<int> selectedDays;
  final Function(Set<int>) onDaysChanged;

  const RepeatSelectionSheet({
    super.key,
    required this.selectedDays,
    required this.onDaysChanged,
  });

  @override
  State<RepeatSelectionSheet> createState() => _RepeatSelectionSheetState();
}

class _RepeatSelectionSheetState extends State<RepeatSelectionSheet> {
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = Set.from(widget.selectedDays);
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
    widget.onDaysChanged(_selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = [
      'Every Sunday',
      'Every Monday',
      'Every Tuesday',
      'Every Wednesday',
      'Every Thursday',
      'Every Friday',
      'Every Saturday',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          backgroundColor: Colors.grey[850],
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Repeat'),
        ),
        ...List.generate(7, (index) {
          return CheckboxListTile(
            title: Text(dayNames[index]),
            value: _selectedDays.contains(index),
            activeColor: Color(0xFFB71C1C),
            onChanged: (value) => _toggleDay(index),
          );
        }),
      ],
    );
  }
}
