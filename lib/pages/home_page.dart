import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/background_alarm_checker.dart';
import 'add_alarm_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'alarm_ringing_page.dart';
import 'debug_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final AlarmService _alarmService = AlarmService();
  List<Alarm> alarms = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isSelectionMode = false;
  Set<int> selectedIndices = {};
  bool showDeleteDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlarms();
    // Ensure background checker is running when app is active
    BackgroundAlarmChecker().start();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Restart checker when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - restarting background checker');
      BackgroundAlarmChecker().start();
    }
  }

  Future<void> _loadAlarms() async {
    final loadedAlarms = await _alarmService.loadAlarms();
    setState(() {
      alarms = loadedAlarms;
    });
    // Schedule all alarms after loading
    print('📋 HomePage: Loading ${loadedAlarms.length} alarms, scheduling...');
    await _alarmService.scheduleAllAlarms(alarms);
    print('✅ HomePage: All alarms scheduled');
  }

  void _addNewAlarm(Alarm alarm) async {
    setState(() {
      alarms.add(alarm);
    });
    print('➕ Adding new alarm: ${alarm.label} at ${alarm.time}');
    await _alarmService.saveAlarms(alarms);
    print('✅ Alarm added and scheduled');
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
    });
  }

  void _showDeleteConfirmation() {
    setState(() {
      showDeleteDialog = true;
    });
  }

  void _deleteSelected() {
    setState(() {
      final sortedIndices = selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (var index in sortedIndices) {
        alarms.removeAt(index);
      }
      selectedIndices.clear();
      isSelectionMode = false;
      showDeleteDialog = false;
    });
    _alarmService.saveAlarms(alarms);
  }

  void _cancelDelete() {
    setState(() {
      showDeleteDialog = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      selectedIndices.clear();
      isSelectionMode = false;
      showDeleteDialog = false;
    });
  }

  void _toggleAlarmActive(int index, bool value) async {
    setState(() {
      alarms[index].isActive = value;
    });
    print('🔄 Toggling alarm $index to ${value ? "active" : "inactive"}');
    await _alarmService.saveAlarms(alarms);
    print('✅ Alarm toggled and rescheduled');
  }

  void _openAddAlarmPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAlarmPage(onAlarmAdded: _addNewAlarm),
      ),
    );
  }

  void _editAlarm(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAlarmPage(
          existingAlarm: alarms[index], // 👈 Mevcut alarm
          alarmIndex: index, // 👈 Index
          onAlarmAdded: (alarm) async {
            setState(() {
              alarms[index] = alarm; // 👈 Güncelle
            });
            print('✏️ Editing alarm $index: ${alarm.label} at ${alarm.time}');
            await _alarmService.saveAlarms(alarms);
            print('✅ Alarm updated and rescheduled');
          },
        ),
      ),
    );
  }

  void _testAlarmSound() {
    // Test alarm
    final testAlarm = Alarm(time: '10:30', label: 'Test Alarm', isActive: true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmRingingPage(alarm: testAlarm),
      ),
    );
  }

  void _testNotification() async {
    final notificationService = NotificationService();
    await notificationService.testNotification(5);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🧪 Test notification scheduled for 5 seconds')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (showDeleteDialog) {
          _cancelDelete();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isSelectionMode ? '${selectedIndices.length} selected' : 'Alarm',
          ),
          leading: isSelectionMode
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                )
              : null,
        ),
        body: alarms.isEmpty
            ? Center(
                child: Text(
                  'No alarms yet\nTap + to add one',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : Stack(
                children: [
                  ListView.builder(
                    itemCount: alarms.length,
                    padding: EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final alarm = alarms[index];
                      final isSelected = selectedIndices.contains(index);

                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            isSelectionMode = true;
                            selectedIndices.add(index);
                          });
                        },
                        onTap: isSelectionMode
                            ? () => _toggleSelection(index)
                            : () => _editAlarm(index),
                        child: Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: isSelected
                              ? Color(0xFFB71C1C).withOpacity(0.2)
                              : null,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alarm.getFormattedTime(),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w300,
                                          color: alarm.isActive
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${alarm.getRepeatText()}, ${alarm.getTimeUntilAlarm()}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: alarm.isActive
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelectionMode)
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) =>
                                        _toggleSelection(index),
                                    activeColor: Color(0xFFB71C1C),
                                  )
                                else
                                  Switch(
                                    value: alarm.isActive,
                                    onChanged: (value) =>
                                        _toggleAlarmActive(index, value),
                                    activeColor: Color(0xFFB71C1C),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (isSelectionMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.grey[900],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: selectedIndices.isEmpty
                                ? null
                                : _showDeleteConfirmation,
                            icon: Icon(
                              Icons.delete,
                              color: selectedIndices.isEmpty
                                  ? Colors.grey
                                  : Color(0xFFB71C1C),
                            ),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: selectedIndices.isEmpty
                                    ? Colors.grey
                                    : Color(0xFFB71C1C),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showDeleteDialog)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _deleteSelected,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFFB71C1C),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: Colors.grey[700]),
                              InkWell(
                                onTap: _cancelDelete,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Debug button 👇
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DebugPage()),
                );
              },
              backgroundColor: Colors.purple,
              heroTag: 'debug',
              child: Icon(Icons.bug_report),
            ),
            SizedBox(height: 10),
            // Test notification button 👇
            FloatingActionButton(
              onPressed: _testNotification,
              backgroundColor: Colors.green,
              heroTag: 'test_notif',
              child: Icon(Icons.notifications),
            ),
            SizedBox(height: 10),
            // Test alarm sound button 👇
            FloatingActionButton(
              onPressed: _testAlarmSound,
              backgroundColor: Colors.blue,
              heroTag: 'test', // Birden fazla FAB için gerekli
              child: Icon(Icons.volume_up),
            ),
            SizedBox(height: 10),

            // Mevcut + butonu 👇
            if (!isSelectionMode)
              FloatingActionButton(
                onPressed: _openAddAlarmPage,
                backgroundColor: Color(0xFFB71C1C),
                heroTag: 'add',
                child: Icon(Icons.add),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
}
