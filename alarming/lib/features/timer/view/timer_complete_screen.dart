import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alarm/alarm.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/timer_provider.dart';
import '../services/timer_service.dart';

class TimerCompleteScreen extends ConsumerStatefulWidget {
  final int alarmId;
  
  const TimerCompleteScreen({super.key, required this.alarmId});

  @override
  ConsumerState<TimerCompleteScreen> createState() => _TimerCompleteScreenState();
}

class _TimerCompleteScreenState extends ConsumerState<TimerCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Vibrate on start
    HapticFeedback.heavyImpact();
    
    // Pulse animation for the stop button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _stopTimer() async {
    HapticFeedback.mediumImpact();
    
    try {
      // Get timer service instance directly
      final timerService = ref.read(timerServiceProvider);
      
      // Get all timers from service
      final timers = await timerService.getAllTimers();
      print('🔍 Looking for timer with alarmId ${widget.alarmId} in ${timers.length} timers');
      
      // Find the timer with matching alarmId
      final matchingTimer = timers.where((t) {
        final calculatedAlarmId = 999000 + (int.parse(t.id) % 1000);
        print('  Timer ${t.id} has alarmId $calculatedAlarmId');
        return calculatedAlarmId == widget.alarmId;
      }).firstOrNull;
      
      if (matchingTimer == null) {
        print('⚠️ Timer not found in storage, using fallback to stop alarm ${widget.alarmId}');
        // Fallback: directly stop the alarm
        await Alarm.stop(widget.alarmId);
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      
      print('🔇 Found matching timer: ${matchingTimer.id} for alarm ${widget.alarmId}');
      await ref.read(timersProvider.notifier).stopTimerAlarm(matchingTimer.id);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      print('❌ Error stopping timer: $e');
      print('Stack: $stack');
      // Emergency fallback: just stop the alarm
      try {
        await Alarm.stop(widget.alarmId);
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                AppTheme.primary.withOpacity(0.15),
                AppTheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Timer icon with glow
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.timer,
                    size: 100,
                    color: AppTheme.primary,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                const Text(
                  "TIME'S UP!",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Your timer has finished',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textPrimary.withOpacity(0.7),
                  ),
                ),
                
                const Spacer(),
                
                // Stop Button
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: GestureDetector(
                      onTap: _stopTimer,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.stop,
                                size: 48,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'STOP',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
