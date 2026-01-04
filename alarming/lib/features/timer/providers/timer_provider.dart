import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_service.dart';

class TimerState {
  final String id;
  final String label;
  final Duration duration;
  final Duration remaining;
  final bool isRunning;
  final bool isStarted;
  final bool isPaused;
  final String soundPath;

  TimerState({
    required this.id,
    this.label = 'Timer',
    this.duration = Duration.zero,
    this.remaining = Duration.zero,
    this.isRunning = false,
    this.isStarted = false,
    this.isPaused = false,
    this.soundPath = 'assets/sounds/alarm.mp3',
  });

  factory TimerState.fromTimerData(TimerData data) {
    return TimerState(
      id: data.id,
      label: data.label,
      duration: data.totalDuration,
      remaining: data.remaining,
      isRunning: !data.isPaused && data.remaining.inSeconds > 0,
      isStarted: true,
      isPaused: data.isPaused,
      soundPath: data.soundPath,
    );
  }

  TimerState copyWith({
    String? id,
    String? label,
    Duration? duration,
    Duration? remaining,
    bool? isRunning,
    bool? isStarted,
    bool? isPaused,
    String? soundPath,
  }) {
    return TimerState(
      id: id ?? this.id,
      label: label ?? this.label,
      duration: duration ?? this.duration,
      remaining: remaining ?? this.remaining,
      isRunning: isRunning ?? this.isRunning,
      isStarted: isStarted ?? this.isStarted,
      isPaused: isPaused ?? this.isPaused,
      soundPath: soundPath ?? this.soundPath,
    );
  }
}

/// Notifier that manages all timers
class TimersNotifier extends StateNotifier<List<TimerState>> {
  final TimerService _timerService = TimerService();
  StreamSubscription? _timerSubscription;

  TimersNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _timerService.init();
    
    // Restore all timers from service
    final timers = await _timerService.getAllTimers();
    state = timers.map((data) => TimerState.fromTimerData(data)).toList();
    
    // Listen for updates
    _timerSubscription = _timerService.timersStream.listen((timerDataList) {
      state = timerDataList.map((data) => TimerState.fromTimerData(data)).toList();
    });
  }

  Future<String> startTimer({
    required Duration duration,
    String label = 'Timer',
    String soundPath = 'assets/sounds/alarm.mp3',
  }) async {
    print('📞 PROVIDER START TIMER CALLED - Label: $label');
    if (duration.inSeconds == 0) {
      print('❌ Duration is 0, returning');
      throw Exception('Duration cannot be zero');
    }
    
    print('🚀 Starting new timer - calling service.startTimer()');
    final timerId = await _timerService.startTimer(
      duration: duration,
      label: label,
      soundPath: soundPath,
    );
    print('✅ Service.startTimer() completed with ID: $timerId');
    return timerId;
  }

  Future<void> resumeTimer(String timerId) async {
    print('▶️ Resuming timer $timerId');
    await _timerService.resumeTimer(timerId);
  }

  Future<void> pauseTimer(String timerId) async {
    print('⏸️ Pausing timer $timerId');
    await _timerService.pauseTimer(timerId);
  }

  Future<void> cancelTimer(String timerId) async {
    print('🛑 Canceling timer $timerId');
    await _timerService.cancelTimer(timerId);
  }
  
  Future<void> stopTimerAlarm(String timerId) async {
    print('🔇 Stopping alarm for timer $timerId');
    await _timerService.stopTimerAlarm(timerId);
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }
}

final timersProvider = StateNotifierProvider<TimersNotifier, List<TimerState>>((ref) {
  return TimersNotifier();
});
