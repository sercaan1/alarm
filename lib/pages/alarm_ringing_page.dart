// ============================================
// lib/pages/alarm_ringing_page.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/alarm.dart';
import '../services/sound_detector_service.dart';
import 'debug_log_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmRingingPage extends StatefulWidget {
  final Alarm alarm;

  const AlarmRingingPage({super.key, required this.alarm});

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SoundDetectorService _soundDetector = SoundDetectorService();
  bool _isListeningForWater = false;
  Timer? _timeoutTimer;
  List<String> _debugLogs = []; // 👈 Ekle

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    _startAlarm();
  }

  Future<void> _initializeDetector() async {
    await _soundDetector.initialize();

    _soundDetector.onLog = (log) {
      setState(() {
        _debugLogs.insert(0, log);
      });
    };

    _soundDetector.onWaterDetected = () {
      print('✅ Water detected! Stopping alarm...');
      _timeoutTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Water sound detected! ✓'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      _stopAlarm();
    };
  }

  Future<void> _startAlarm() async {
    await _audioPlayer.play(AssetSource('sounds/alarm_sound.mp3'));
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    print('🔊 Alarm started');
  }

  Future<void> _stopAlarm() async {
    await _audioPlayer.stop();
    await _soundDetector.stopListening();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _startListeningForWater() async {
    await _audioPlayer.pause();

    setState(() {
      _isListeningForWater = true;
    });

    _soundDetector.startListening();

    // SharedPreferences'ten log oku (her 500ms)
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (!_isListeningForWater || !mounted) {
        timer.cancel();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getString('logs') ?? '';

      if (logs.isNotEmpty) {
        setState(() {
          _debugLogs = logs.split('\n').take(50).toList();
        });
      }
    });

    _timeoutTimer = Timer(Duration(seconds: 10), () {
      // ... timeout
    });
  }

  void _onTimeout() async {
    await _soundDetector.stopListening();

    setState(() {
      _isListeningForWater = false;
    });

    // Alarm sesini tekrar başlat
    await _audioPlayer.resume();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No water detected. Alarm restarted.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onManualStop() {
    // Test için manuel kapatma
    _timeoutTimer?.cancel();
    _stopAlarm();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(),

                // Alarm icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(0xFFB71C1C).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.alarm, size: 60, color: Color(0xFFB71C1C)),
                ),

                SizedBox(height: 40),

                // Alarm time
                Text(
                  widget.alarm.getFormattedTime(),
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                  ),
                ),

                SizedBox(height: 16),

                // Alarm label
                Text(
                  widget.alarm.label,
                  style: TextStyle(fontSize: 24, color: Colors.grey[400]),
                ),

                SizedBox(height: 60),

                // Main button: I Hear Water
                if (!_isListeningForWater)
                  GestureDetector(
                    onTap: _startListeningForWater,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFB71C1C).withOpacity(0.4),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.water_drop, size: 48, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'I Hear Water',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Turn on the faucet and wait',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Listening for Water...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Turn on the faucet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20),

                // Test: Manual close button
                TextButton(
                  onPressed: _onManualStop,
                  child: Text(
                    'Test: Manual Stop',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DebugLogPage(logs: _debugLogs),
                      ),
                    );
                  },
                  child: Text(
                    'View Debug Logs',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),

                Spacer(),

                // Info text
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To stop the alarm, go to the bathroom and turn on the faucet.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _audioPlayer.dispose();
    _soundDetector.dispose();
    super.dispose();
  }
}
