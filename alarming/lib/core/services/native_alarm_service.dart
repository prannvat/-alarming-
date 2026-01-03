import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import '../../features/alarm/models/alarm_model.dart';

/// Service that uses the native alarm package to ring alarms
/// even when the app is in background or phone is locked.
class NativeAlarmService {
  static final NativeAlarmService _instance = NativeAlarmService._internal();
  factory NativeAlarmService() => _instance;
  NativeAlarmService._internal();

  bool _initialized = false;
  
  // Stream to notify when alarm rings
  final StreamController<AlarmModel> _alarmRingController = 
      StreamController<AlarmModel>.broadcast();
  
  Stream<AlarmModel> get onAlarmRing => _alarmRingController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await Alarm.init();
    
    // Listen for alarm ringing events
    Alarm.ringStream.stream.listen((alarmSettings) {
      print('🔔 NATIVE ALARM RINGING: ${alarmSettings.id}');
      // The alarm package handles playing the sound automatically
    });
    
    _initialized = true;
    print('✅ Native Alarm Service initialized');
  }

  /// Schedule a native alarm that will ring even when phone is locked
  Future<void> scheduleAlarm(AlarmModel alarm) async {
    await initialize();
    
    final nextTrigger = alarm.nextTriggerTime;
    if (nextTrigger == null) {
      print('❌ No trigger time for alarm ${alarm.id}');
      return;
    }
    
    // If the alarm time is in the past, don't schedule
    if (nextTrigger.isBefore(DateTime.now())) {
      print('⚠️ Alarm time is in the past, skipping: ${alarm.id}');
      return;
    }

    final alarmSettings = AlarmSettings(
      id: _getAlarmId(alarm.id),
      dateTime: nextTrigger,
      assetAudioPath: 'assets/sounds/alarm.mp3',
      loopAudio: true,
      vibrate: alarm.vibrationEnabled,
      volume: 1.0, // Max volume
      fadeDuration: 0, // Start at full volume immediately
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: alarm.label.isEmpty ? 'Alarm' : alarm.label,
        body: alarm.isChallenge 
            ? 'Complete the challenge to dismiss'
            : 'Tap to dismiss',
        stopButton: alarm.isChallenge ? null : 'Stop',
        icon: 'notification_icon',
      ),
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    
    if (success) {
      print('✅ Native alarm scheduled: ${alarm.id} at $nextTrigger');
    } else {
      print('❌ Failed to schedule native alarm: ${alarm.id}');
    }
  }

  /// Cancel a scheduled alarm
  Future<void> cancelAlarm(String alarmId) async {
    await initialize();
    await Alarm.stop(_getAlarmId(alarmId));
    print('🔇 Native alarm cancelled: $alarmId');
  }

  /// Stop a currently ringing alarm
  Future<void> stopRingingAlarm(String alarmId) async {
    await Alarm.stop(_getAlarmId(alarmId));
    print('🔇 Stopped ringing alarm: $alarmId');
  }

  /// Check if an alarm is currently ringing
  Future<bool> isRinging(String alarmId) async {
    return await Alarm.isRinging(_getAlarmId(alarmId));
  }

  /// Get all scheduled alarms
  Future<List<AlarmSettings>> getScheduledAlarms() async {
    return await Alarm.getAlarms();
  }

  /// Convert string alarm ID to int for the alarm package
  int _getAlarmId(String alarmId) {
    // Use first 9 digits of the timestamp-based ID
    return int.parse(alarmId.substring(0, 9));
  }

  void dispose() {
    _alarmRingController.close();
  }
}
