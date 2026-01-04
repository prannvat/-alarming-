import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persistent timer state stored in Hive
class TimerData {
  final String id;
  final String label;
  final DateTime? endTime;
  final Duration totalDuration;
  final bool isPaused;
  final Duration remainingWhenPaused;
  final String soundPath;
  final DateTime createdAt;

  TimerData({
    String? id,
    this.label = 'Timer',
    this.endTime,
    this.totalDuration = Duration.zero,
    this.isPaused = false,
    this.remainingWhenPaused = Duration.zero,
    this.soundPath = 'assets/sounds/alarm.mp3',
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'endTime': endTime?.millisecondsSinceEpoch,
    'totalDuration': totalDuration.inMilliseconds,
    'isPaused': isPaused,
    'remainingWhenPaused': remainingWhenPaused.inMilliseconds,
    'soundPath': soundPath,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory TimerData.fromJson(Map<String, dynamic> json) => TimerData(
    id: json['id'],
    label: json['label'] ?? 'Timer',
    endTime: json['endTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['endTime']) 
        : null,
    totalDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
    isPaused: json['isPaused'] ?? false,
    remainingWhenPaused: Duration(milliseconds: json['remainingWhenPaused'] ?? 0),
    soundPath: json['soundPath'] ?? 'assets/sounds/alarm.mp3',
    createdAt: json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
        : DateTime.now(),
  );

  bool get isActive => endTime != null || (isPaused && remainingWhenPaused.inSeconds > 0);
  
  Duration get remaining {
    if (isPaused) return remainingWhenPaused;
    if (endTime == null) return Duration.zero;
    final diff = endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
  
  int get alarmId => 999000 + (int.parse(id) % 1000);
  
  TimerData copyWith({
    String? label,
    DateTime? endTime,
    Duration? totalDuration,
    bool? isPaused,
    Duration? remainingWhenPaused,
    String? soundPath,
  }) {
    return TimerData(
      id: id,
      label: label ?? this.label,
      endTime: endTime,
      totalDuration: totalDuration ?? this.totalDuration,
      isPaused: isPaused ?? this.isPaused,
      remainingWhenPaused: remainingWhenPaused ?? this.remainingWhenPaused,
      soundPath: soundPath ?? this.soundPath,
      createdAt: createdAt,
    );
  }
}

/// Service that manages multiple timers using native alarm scheduling
class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  static const int _baseTimerAlarmId = 999000; // Base ID for timer alarms (999000-999999)
  static const String _timerBoxName = 'timers_data';
  
  Box? _box;
  final Map<String, Timer> _uiUpdateTimers = {};
  final _timersStateController = StreamController<List<TimerData>>.broadcast();
  
  Stream<List<TimerData>> get timersStream => _timersStateController.stream;
  
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_timerBoxName);
    }
    
    // Check for active timers and restore UI updates
    final timers = await getAllTimers();
    for (final timer in timers) {
      if (timer.isActive && !timer.isPaused) {
        _startUiUpdatesForTimer(timer.id);
      }
    }
  }

  /// Get all timers sorted by remaining time (closest to finishing first)
  Future<List<TimerData>> getAllTimers() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    final timersMap = _box!.get('timers', defaultValue: <String, dynamic>{});
    final timers = <TimerData>[];
    
    if (timersMap is Map) {
      for (final entry in timersMap.entries) {
        if (entry.value is Map) {
          final timer = TimerData.fromJson(Map<String, dynamic>.from(entry.value as Map));
          if (timer.isActive) {
            timers.add(timer);
          }
        }
      }
    }
    
    // Sort by remaining time (closest to finishing first)
    timers.sort((a, b) => a.remaining.compareTo(b.remaining));
    return timers;
  }
  
  /// Get a specific timer by ID
  Future<TimerData?> getTimer(String id) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    final timersMap = _box!.get('timers', defaultValue: <String, dynamic>{});
    if (timersMap is Map && timersMap.containsKey(id)) {
      return TimerData.fromJson(Map<String, dynamic>.from(timersMap[id] as Map));
    }
    return null;
  }

  /// Save a timer to storage and broadcast updates
  Future<void> _saveTimer(TimerData data) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    
    // Get existing timers map
    final timersMap = _box!.get('timers', defaultValue: <String, dynamic>{}) as Map;
    final timers = Map<String, dynamic>.from(timersMap);
    
    // Update or add this timer
    timers[data.id] = data.toJson();
    
    // Save back to storage
    await _box!.put('timers', timers);
    print('💾 Timer ${data.id} saved');
    
    await _broadcastTimers();
  }

  /// Broadcast all timers to listeners
  Future<void> _broadcastTimers() async {
    final timers = await getAllTimers();
    _timersStateController.add(timers);
  }

  /// Delete a timer from storage
  Future<void> _deleteTimer(String id) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    
    // Get existing timers map
    final timersMap = _box!.get('timers', defaultValue: <String, dynamic>{}) as Map;
    final timers = Map<String, dynamic>.from(timersMap);
    
    // Remove this timer
    timers.remove(id);
    
    // Save back to storage
    await _box!.put('timers', timers);
    
    final uiTimer = _uiUpdateTimers[id];
    if (uiTimer != null) {
      uiTimer.cancel();
      _uiUpdateTimers.remove(id);
    }
    print('🗑️ Timer $id deleted');
    
    await _broadcastTimers();
  }

  /// Start a new timer with the given duration and label
  Future<String> startTimer({
    required Duration duration,
    String label = 'Timer',
    String soundPath = 'assets/sounds/alarm.mp3',
  }) async {
    print('🔘 TIMER START CALLED - Duration: ${duration.inSeconds}s, Label: $label, Sound: $soundPath');
    
    // Create new timer data with unique ID
    final timerData = TimerData(
      endTime: DateTime.now().add(duration),
      totalDuration: duration,
      isPaused: false,
      soundPath: soundPath,
      label: label,
    );
    
    final endTime = timerData.endTime!;
    print('⏰ Scheduling alarm for $endTime with ID ${timerData.alarmId}');
    
    // Schedule the native alarm for when timer ends
    final alarmSettings = AlarmSettings(
      id: timerData.alarmId,
      dateTime: endTime,
      assetAudioPath: soundPath,
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 0,
      warningNotificationOnKill: false,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: '⏱️ ${timerData.label} Complete!',
        body: 'Your timer has finished',
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
    );

    print('⏰ Calling Alarm.set() for timer ${timerData.id}...');
    final success = await Alarm.set(alarmSettings: alarmSettings);
    print('⏰ Alarm.set() returned: $success');
    
    if (success) {
      print('✅ Timer alarm scheduled for $endTime');
      
      await _saveTimer(timerData);
      _startUiUpdatesForTimer(timerData.id);
      await _showOngoingNotification(timerData);
      
      return timerData.id;
    } else {
      print('❌ Failed to schedule timer alarm');
      throw Exception('Failed to schedule timer alarm');
    }
  }

  /// Resume a paused timer
  Future<void> resumeTimer(String timerId) async {
    final data = await getTimer(timerId);
    if (data == null || !data.isPaused || data.remainingWhenPaused.inSeconds <= 0) {
      return;
    }
    
    final newEndTime = DateTime.now().add(data.remainingWhenPaused);
    
    // Schedule the native alarm
    final alarmSettings = AlarmSettings(
      id: data.alarmId,
      dateTime: newEndTime,
      assetAudioPath: data.soundPath,
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 0,
      warningNotificationOnKill: false,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: '⏱️ ${data.label} Complete!',
        body: 'Your timer has finished',
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
    );

    print('⏰ Calling Alarm.set() for timer $timerId...');
    final success = await Alarm.set(alarmSettings: alarmSettings);
    print('⏰ Alarm.set() returned: $success');
    
    if (success) {
      print('✅ Timer resumed, alarm scheduled for $newEndTime');
      
      final newData = data.copyWith(
        endTime: newEndTime,
        isPaused: false,
      );
      
      await _saveTimer(newData);
      _startUiUpdatesForTimer(timerId);
      await _showOngoingNotification(newData);
    }
  }

  /// Pause the timer
  Future<void> pauseTimer(String timerId) async {
    final data = await getTimer(timerId);
    if (data == null || data.endTime == null || data.isPaused) return;
    
    // Cancel the native alarm
    await Alarm.stop(data.alarmId);
    print('⏸️ Timer $timerId paused');
    
    // Save remaining time
    final remaining = data.remaining;
    
    final newData = data.copyWith(
      endTime: null,
      isPaused: true,
      remainingWhenPaused: remaining,
    );
    
    await _saveTimer(newData);
    _stopUiUpdatesForTimer(timerId);
    await _updatePausedNotification(newData);
  }

  /// Cancel the timer completely
  Future<void> cancelTimer(String timerId) async {
    print('🧹 cancelTimer: Starting for timer $timerId');
    
    final data = await getTimer(timerId);
    if (data == null) {
      print('🧹 cancelTimer: Timer $timerId not found');
      return;
    }
    
    if (data.isActive) {
      print('🧹 cancelTimer: Stopping alarm ${data.alarmId}');
      await Alarm.stop(data.alarmId);
      print('🧹 cancelTimer: Alarm stopped');
    } else {
      print('🧹 cancelTimer: No active alarm to stop');
    }
    
    print('🧹 cancelTimer: Canceling notification');
    await _cancelNotification(data.alarmId);
    print('🧹 cancelTimer: Notification canceled');
    
    print('🧹 cancelTimer: Stopping UI updates');
    _stopUiUpdatesForTimer(timerId);
    print('🧹 cancelTimer: UI updates stopped');
    
    print('🧹 cancelTimer: Deleting timer');
    await _deleteTimer(timerId);
    print('🛑 Timer $timerId cancelled');
  }

  /// Stop the timer alarm sound (called when timer completes and user dismisses)
  Future<void> stopTimerAlarm(String timerId) async {
    final data = await getTimer(timerId);
    if (data == null) {
      print('⚠️ Timer $timerId not found, checking if alarm is still ringing');
      // Try to find and stop any alarm in the timer range that might be ringing
      for (int i = 0; i < 1000; i++) {
        final alarmId = 999000 + i;
        final isRinging = await Alarm.isRinging(alarmId);
        if (isRinging) {
          print('🔇 Found ringing alarm $alarmId, stopping it');
          await Alarm.stop(alarmId);
        }
      }
      return;
    }
    
    print('🔇 Stopping alarm ${data.alarmId} for timer $timerId');
    await Alarm.stop(data.alarmId);
    await _cancelNotification(data.alarmId);
    _stopUiUpdatesForTimer(timerId);
    await _deleteTimer(timerId);
    print('🔇 Timer $timerId alarm stopped');
  }

  void _startUiUpdatesForTimer(String timerId) {
    _uiUpdateTimers[timerId]?.cancel();
    _uiUpdateTimers[timerId] = Timer.periodic(const Duration(seconds: 1), (_) async {
      final data = await getTimer(timerId);
      if (data == null) {
        _stopUiUpdatesForTimer(timerId);
        return;
      }
      if (data.remaining.inSeconds <= 0 && !data.isPaused) {
        _stopUiUpdatesForTimer(timerId);
      }
      await _broadcastTimers();
    });
  }

  void _stopUiUpdatesForTimer(String timerId) {
    _uiUpdateTimers[timerId]?.cancel();
    _uiUpdateTimers.remove(timerId);
  }

  Future<void> _showOngoingNotification(TimerData data) async {
    final remaining = data.remaining;
    final timeString = _formatDuration(remaining);
    
    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer',
      channelDescription: 'Active timer notifications',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.progress,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
    );
    
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _notifications.show(
      data.alarmId,
      '⏱️ ${data.label}',
      'Time remaining: $timeString',
      details,
    );
  }

  Future<void> _updatePausedNotification(TimerData data) async {
    final timeString = _formatDuration(data.remainingWhenPaused);
    
    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer',
      channelDescription: 'Active timer notifications',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
    );
    
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _notifications.show(
      data.alarmId,
      '⏸️ ${data.label} Paused',
      'Remaining: $timeString',
      details,
    );
  }

  Future<void> _cancelNotification(int alarmId) async {
    await _notifications.cancel(alarmId);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "$hours:$minutes:$seconds";
    return "$minutes:$seconds";
  }

  void dispose() {
    for (var timer in _uiUpdateTimers.values) {
      timer.cancel();
    }
    _uiUpdateTimers.clear();
    _timersStateController.close();
  }
}

/// Provider for the timer service
final timerServiceProvider = Provider<TimerService>((ref) {
  return TimerService();
});
