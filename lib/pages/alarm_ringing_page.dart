// ============================================
// lib/pages/alarm_ringing_page.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/alarm.dart';
import '../services/sound_detector_service.dart';
import '../services/log_reader.dart';
import '../services/notification_service.dart';
import 'debug_log_page.dart';

class AlarmRingingPage extends StatefulWidget {
  final Alarm alarm;

  const AlarmRingingPage({super.key, required this.alarm});

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SoundDetectorService _soundDetector = SoundDetectorService();
  static const platform = MethodChannel('com.example.alarm/audio_stream');
  bool _isListeningForWater = false;
  Timer? _timeoutTimer;
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    _startAlarm();
    // Don't stop service immediately - let it play for a moment, then stop
    // This ensures sound plays even if page takes time to load
    Future.delayed(Duration(milliseconds: 500), () {
      NotificationService().stopAlarmService();
    });
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
          const SnackBar(
            content: Text('Water sound detected! ✓'),
            duration: Duration(seconds: 1),
          ),
        );
        // Navigate back immediately after showing snackbar
        Future.delayed(Duration(milliseconds: 500), () {
          _stopAlarm();
        });
      } else {
        _stopAlarm();
      }
    };
  }

  Future<void> _startAlarm() async {
    // Set player mode and max volume
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _audioPlayer.setVolume(1.0); // Max volume
    
    // Set audio stream type to ALARM (Android only)
    try {
      await platform.invokeMethod('setAudioStreamAlarm');
    } catch (e) {
      print('⚠️ Could not set audio stream type: $e');
    }
    
    await _audioPlayer.play(AssetSource('sounds/alarm_sound.mp3'));
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    print('🔊 Alarm started at max volume with ALARM stream');
  }

  Future<void> _stopAlarm() async {
    print('🛑 Stopping alarm and navigating back...');
    
    try {
      // Stop foreground service if running
      await NotificationService().stopAlarmService();
      
      // Stop audio and detector
      await _audioPlayer.stop();
      await _soundDetector.stopListening();

      // Navigate back to home page
      if (mounted) {
        // Use popUntil to go back to home page
        Navigator.of(context).popUntil((route) => route.isFirst);
        print('✅ Navigation completed - returned to home page');
      }
    } catch (e) {
      print('❌ Error stopping alarm: $e');
      // Fallback: just pop once
      if (mounted) {
        try {
          Navigator.of(context).pop();
          print('✅ Fallback navigation completed');
        } catch (e2) {
          print('❌ Error in fallback navigation: $e2');
        }
      }
    }
  }

  void _startListeningForWater() async {
    // Request microphone permission first
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission needed for water detection!'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Stop alarm sound completely (both page and service)
    await _audioPlayer.stop();
    await NotificationService().stopAlarmService();

    setState(() {
      _isListeningForWater = true;
    });

    _soundDetector.startListening();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isListeningForWater || !mounted) {
        timer.cancel();
        return;
      }

      final logs = await LogReader.getLogs();
      setState(() {
        _debugLogs = logs.split('\n').where((l) => l.isNotEmpty).toList();
      });
    });

    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isListeningForWater) {
        _onTimeout();
      }
    });
  }

  void _onTimeout() async {
    await _soundDetector.stopListening();

    setState(() {
      _isListeningForWater = false;
    });

    // Resume alarm sound
    await _audioPlayer.play(AssetSource('sounds/alarm_sound.mp3'));
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No water detected. Alarm restarted.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onManualStop() {
    _timeoutTimer?.cancel();
    _stopAlarm();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),

                  Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm,
                    size: 60,
                    color: Color(0xFFB71C1C),
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  widget.alarm.getFormattedTime(),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -2,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  widget.alarm.label,
                  style: TextStyle(fontSize: 24, color: Colors.grey[400]),
                ),

                const SizedBox(height: 60),

                if (!_isListeningForWater)
                  GestureDetector(
                    onTap: _startListeningForWater,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB71C1C).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
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
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: const Column(
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
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

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
                  child: const Text(
                    'View Debug Logs',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),

                  SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(16),
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
                      const SizedBox(width: 12),
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
