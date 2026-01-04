import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import '../../../core/services/alarm_sound_service.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';

class AlarmDismissScreen extends ConsumerStatefulWidget {
  final String alarmId;
  final VoidCallback? onDismiss;

  const AlarmDismissScreen({
    super.key,
    required this.alarmId,
    this.onDismiss,
  });

  @override
  ConsumerState<AlarmDismissScreen> createState() => _AlarmDismissScreenState();
}

class _AlarmDismissScreenState extends ConsumerState<AlarmDismissScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  AlarmModel? _alarm;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAlarm();
  }

  Future<void> _loadAlarm() async {
    final repository = ref.read(alarmRepositoryProvider);
    final alarm = await repository.getAlarm(widget.alarmId);
    if (mounted) {
      setState(() {
        _alarm = alarm;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    // Stop the native alarm (the one that rings when phone is locked)
    if (_alarm != null) {
      final nativeAlarmId = int.parse(_alarm!.id.substring(0, 9));
      await Alarm.stop(nativeAlarmId);
      print('🔇 Stopped native alarm: $nativeAlarmId');
      
      // If alarm is not repeating (no days selected), disable it
      final isRepeating = _alarm!.repeatDays.any((day) => day);
      print('🔍 Alarm repeating: $isRepeating (repeatDays: ${_alarm!.repeatDays})');
      
      if (!isRepeating) {
        print('🔕 One-time alarm dismissed, disabling...');
        final repository = ref.read(alarmRepositoryProvider);
        await repository.updateAlarm(_alarm!.copyWith(isEnabled: false));
      } else {
        print('🔁 Repeating alarm dismissed, will ring again on next scheduled day');
      }
    }
    
    // Also stop via manager service (for in-app audio)
    AlarmManagerService().dismissCurrentAlarm();
    widget.onDismiss?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _snooze() async {
    // Stop the current native alarm
    if (_alarm != null) {
      final nativeAlarmId = int.parse(_alarm!.id.substring(0, 9));
      await Alarm.stop(nativeAlarmId);
      print('🔇 Stopped native alarm for snooze: $nativeAlarmId');
    }
    
    // Stop via manager service
    AlarmManagerService().dismissCurrentAlarm();
    
    // Schedule snooze (5 minutes from now)
    // For now, just dismiss - we'll add proper snooze later
    print('🔔 Snoozing alarm for 5 minutes...');
    
    widget.onDismiss?.call();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm snoozed for 5 minutes'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  void _startChallenge() {
    // Navigate to challenge
    // The alarm sound continues to play until challenge is completed
    if (_alarm != null) {
      context.push('/challenge/math', extra: {
        'difficulty': _alarm!.difficulty ?? 'medium',
        'alarmId': _alarm!.id,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                Text(
                  _alarm?.label.isNotEmpty == true ? _alarm!.label : 'Alarm',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  TimeOfDay.now().format(context),
                  style: const TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            
            Column(
              children: [
                // Snooze Button (Only if NOT challenge)
                if (_alarm?.isChallenge != true)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _snooze,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3A3C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Snooze',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Dismiss/Stop/Start Challenge Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _alarm?.isChallenge == true
                      ? SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _startChallenge,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondary, // Purple for challenge
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Start Challenge',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _dismiss,
                          child: const Text(
                            'Stop',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary, // Orange
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
