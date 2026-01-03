import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/alarm/models/alarm_model.dart';
import 'alarm_sound_service.dart';

class AlarmManagerService {
  static final AlarmManagerService _instance = AlarmManagerService._internal();
  factory AlarmManagerService() => _instance;
  AlarmManagerService._internal();

  Timer? _checkTimer;
  String? _currentRingingAlarmId;
  final StreamController<AlarmModel> _alarmTriggerController = 
      StreamController<AlarmModel>.broadcast();

  Stream<AlarmModel> get onAlarmTrigger => _alarmTriggerController.stream;

  void startMonitoring() {
    print('🔔 Starting alarm monitoring...');
    
    // Check every second if any alarm should trigger
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkAlarms();
    });
    
    // Also do an immediate check
    _checkAlarms();
  }

  void stopMonitoring() {
    print('🔔 Stopping alarm monitoring...');
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _checkAlarms() async {
    try {
      final box = await Hive.openBox<AlarmModel>('alarms');
      final now = DateTime.now();
      
      for (var alarm in box.values) {
        if (!alarm.isEnabled) continue;
        if (_currentRingingAlarmId == alarm.id) continue; // Already ringing
        
        final nextTrigger = alarm.nextTriggerTime;
        if (nextTrigger == null) continue;
        
        // Check if alarm should trigger (within 1 second window)
        final diff = nextTrigger.difference(now).inSeconds;
        
        // Log every 10 seconds to show we're monitoring
        if (diff > 0 && diff % 10 == 0) {
          print('⏰ Alarm ${alarm.label.isEmpty ? alarm.timeString : alarm.label} will ring in ${diff}s (at ${nextTrigger})');
        }
        
        if (diff <= 0 && diff > -2) {
          print('🔔 ALARM TRIGGERED: ${alarm.id} at ${now}');
          _triggerAlarm(alarm);
        }
      }
    } catch (e) {
      print('❌ Error checking alarms: $e');
    }
  }

  Future<void> _triggerAlarm(AlarmModel alarm) async {
    _currentRingingAlarmId = alarm.id;
    
    // NOTE: The native alarm package (Alarm) handles audio playback
    // We don't need to play audio here anymore - it would cause duplicate sound
    print('🔊 Alarm triggered: ${alarm.label} - native alarm package handles audio');
    
    // Emit the alarm trigger event (for showing the dismiss screen)
    _alarmTriggerController.add(alarm);
  }

  void dismissCurrentAlarm() async {
    if (_currentRingingAlarmId != null) {
      print('🔇 Dismissing alarm: $_currentRingingAlarmId');
      await AlarmSoundService().stopAlarm();
      _currentRingingAlarmId = null;
    }
  }

  String? get currentRingingAlarmId => _currentRingingAlarmId;
  
  void dispose() {
    stopMonitoring();
    _alarmTriggerController.close();
  }
}
