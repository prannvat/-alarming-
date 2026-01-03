import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import '../models/alarm_model.dart';
import '../../../core/services/notification_service.dart';

class AlarmRepository {
  static const String _boxName = 'alarms';
  Box<AlarmModel>? _box;
  final NotificationService _notificationService = NotificationService();

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<AlarmModel>(_boxName);
    } else {
      _box = Hive.box<AlarmModel>(_boxName);
    }
  }

  /// Convert string alarm ID to int for the native alarm package
  int _getNativeAlarmId(String alarmId) {
    return int.parse(alarmId.substring(0, 9));
  }

  /// Schedule a native alarm that rings even when phone is locked
  Future<void> _scheduleNativeAlarm(AlarmModel alarm) async {
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

    // Determine the audio path
    String audioPath = 'assets/sounds/alarm.mp3';
    
    if (alarm.soundPath != null && alarm.soundPath!.isNotEmpty) {
      if (alarm.soundPath!.startsWith('assets/')) {
        // Asset path - use as is
        audioPath = alarm.soundPath!;
      } else {
        // Custom file path - extract relative path from Documents directory
        // iOS expects: 'custom_sounds/filename.mp3' (relative to Documents)
        // Full path: /var/.../Documents/custom_sounds/filename.mp3
        final fullPath = alarm.soundPath!;
        if (fullPath.contains('/Documents/')) {
          // Extract everything after '/Documents/'
          final relativePath = fullPath.split('/Documents/').last;
          audioPath = relativePath;
          print('🔊 Custom sound relative path: $relativePath');
        } else {
          // Fallback: just use the filename
          audioPath = fullPath.split('/').last;
        }
      }
    }

    print('🔊 Native alarm audio: $audioPath');

    final alarmSettings = AlarmSettings(
      id: _getNativeAlarmId(alarm.id),
      dateTime: nextTrigger,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: alarm.vibrationEnabled,
      volume: 1.0, // Max volume
      fadeDuration: 0, // Start at full volume immediately
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: alarm.label.isEmpty ? '⏰ Alarm' : '⏰ ${alarm.label}',
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

  /// Cancel a native alarm
  Future<void> _cancelNativeAlarm(String alarmId) async {
    await Alarm.stop(_getNativeAlarmId(alarmId));
    print('🔇 Native alarm cancelled: $alarmId');
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    await init();
    return _box!.values.toList();
  }
  
  // Alias for getAllAlarms for compatibility
  Future<List<AlarmModel>> getAlarms() async {
    return getAllAlarms();
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    await init();
    print('📦 Saving alarm to Hive: ${alarm.id}');
    await _box!.put(alarm.id, alarm);
    print('📦 Alarm saved to Hive successfully');
    
    // Schedule NATIVE alarm if alarm is enabled (this is the one that works when locked!)
    if (alarm.isEnabled) {
      try {
        print('🔔 Scheduling NATIVE alarm for ${alarm.id}');
        await _scheduleNativeAlarm(alarm);
        
        // Also schedule notification as backup
        await _notificationService.scheduleAlarm(alarm);
        print('🔔 Alarm scheduled successfully');
      } catch (e) {
        print('❌ Failed to schedule alarm: $e');
      }
    }
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    await init();
    await _box!.put(alarm.id, alarm);
    
    // Update alarm scheduling
    if (alarm.isEnabled) {
      try {
        // Cancel existing and reschedule
        await _cancelNativeAlarm(alarm.id);
        await _scheduleNativeAlarm(alarm);
        await _notificationService.scheduleAlarm(alarm);
      } catch (e) {
        print('Failed to update alarm: $e');
      }
    } else {
      try {
        await _cancelNativeAlarm(alarm.id);
        await _notificationService.cancelAlarm(alarm.id);
      } catch (e) {
        print('Failed to cancel alarm: $e');
      }
    }
  }

  Future<void> deleteAlarm(String id) async {
    await init();
    await _box!.delete(id);
    
    // Cancel alarms
    try {
      await _cancelNativeAlarm(id);
      await _notificationService.cancelAlarm(id);
    } catch (e) {
      print('Failed to cancel alarm: $e');
    }
  }

  Future<AlarmModel?> getAlarm(String id) async {
    await init();
    return _box!.get(id);
  }

  Stream<List<AlarmModel>> watchAlarms() async* {
    await init();
    yield _box!.values.toList();
    
    yield* _box!.watch().map((event) => _box!.values.toList());
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  return AlarmRepository();
});

final alarmsProvider = StreamProvider<List<AlarmModel>>((ref) {
  final repository = ref.watch(alarmRepositoryProvider);
  return repository.watchAlarms();
});
