import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/notification_permission_handler.dart';
import '../../../core/services/daily_challenge_service.dart';
import '../../../core/services/custom_sound_service.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import 'sound_picker_screen.dart';

class CreateAlarmScreen extends ConsumerStatefulWidget {
  const CreateAlarmScreen({super.key});

  @override
  ConsumerState<CreateAlarmScreen> createState() => _CreateAlarmScreenState();
}

class _CreateAlarmScreenState extends ConsumerState<CreateAlarmScreen> {
  late DateTime _selectedTime;
  DateTime? _selectedDate; // If null, it's "Today" or "Tomorrow" based on time
  final TextEditingController _labelController = TextEditingController();
  List<bool> _repeatDays = List.filled(7, false);
  bool _isChallenge = false;
  String? _selectedSoundPath; // null means default sound
  String _soundDisplayName = 'Default';

  @override
  void initState() {
    super.initState();
    // Initialize with current time but 0 seconds/milliseconds
    final now = DateTime.now();
    _selectedTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _saveAlarm() async {
    print('🔔 Creating alarm...');
    
    // Request notification permissions first
    final hasPermission = await NotificationPermissionHandler.ensurePermissions(context);
    
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm created, but notifications are disabled. Enable them in Settings.'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }

    // Validation: One Challenge Per Day
    if (_isChallenge) {
      final repository = ref.read(alarmRepositoryProvider);
      final alarms = await repository.getAllAlarms();
      
      for (final existingAlarm in alarms) {
        if (!existingAlarm.isEnabled || !existingAlarm.isChallenge) continue;
        
        bool conflict = false;
        
        // Case 1: New alarm is specific date
        if (_selectedDate != null) {
           // Check if existing alarm triggers on this date (for specific date alarms or next-24h alarms)
           final trigger = existingAlarm.nextTriggerTime;
           if (trigger != null && 
               trigger.year == _selectedDate!.year && 
               trigger.month == _selectedDate!.month && 
               trigger.day == _selectedDate!.day) {
             conflict = true;
           }
           
           // Check if existing repeating alarm covers this weekday
           if (existingAlarm.repeatDays.any((d) => d)) {
              final weekday = _selectedDate!.weekday - 1;
              if (existingAlarm.repeatDays[weekday]) conflict = true;
           }
        } 
        // Case 2: New alarm is repeating
        else if (_repeatDays.any((d) => d)) {
           for (int i = 0; i < 7; i++) {
             if (_repeatDays[i] && existingAlarm.repeatDays[i]) conflict = true;
           }
           if (existingAlarm.specificDate != null) {
              final weekday = existingAlarm.specificDate!.weekday - 1;
              if (_repeatDays[weekday]) conflict = true;
           }
        }
        // Case 3: New alarm is "Once" (Next 24h)
        else {
           final now = DateTime.now();
           var trigger = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
           if (trigger.isBefore(now)) trigger = trigger.add(const Duration(days: 1));
           
           final existingTrigger = existingAlarm.nextTriggerTime;
           if (existingTrigger != null && 
               existingTrigger.year == trigger.year && 
               existingTrigger.month == trigger.month && 
               existingTrigger.day == trigger.day) {
             conflict = true;
           }
        }
        
        if (conflict) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You already have a challenge alarm for this day. Only one allowed per day.'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          return;
        }
      }
    }
    
    final alarm = AlarmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      label: _labelController.text,
      repeatDays: _selectedDate != null ? List.filled(7, false) : _repeatDays,
      isChallenge: _isChallenge,
      challengeType: _isChallenge ? DailyChallengeService().getTodaysChallengeType() : null,
      difficulty: 'medium',
      specificDate: _selectedDate,
      soundPath: _selectedSoundPath,
    );

    final repository = ref.read(alarmRepositoryProvider);
    await repository.addAlarm(alarm);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm set for ${alarm.timeString}'),
          backgroundColor: AppTheme.success,
        ),
      );
      context.pop();
    }
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: const Color(0xFF2C2C2E),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: _selectedDate ?? DateTime.now(),
            mode: CupertinoDatePickerMode.date,
            use24hFormat: true,
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _selectedDate = newDate;
                // Clear repeat days if specific date is selected
                _repeatDays = List.filled(7, false);
              });
            },
          ),
        ),
      ),
    );
  }

  String _getDateLabel() {
    if (_selectedDate != null) {
      return DateFormat('EEE, MMM d, y').format(_selectedDate!);
    }
    // If no specific date, it's either "Today" or "Tomorrow" based on time
    final now = DateTime.now();
    final todayTrigger = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    if (todayTrigger.isBefore(now)) {
      return 'Tomorrow';
    }
    return 'Today';
  }

  void _showSoundPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SoundPickerScreen(
          currentSoundPath: _selectedSoundPath,
        ),
      ),
    );

    if (result != null && mounted) {
      final soundService = CustomSoundService();
      final displayName = await soundService.getSoundName(result);
      
      setState(() {
        _selectedSoundPath = result;
        _soundDisplayName = displayName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 17,
            ),
          ),
        ),
        title: const Text(
          'Add Alarm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // Cupertino Time Picker
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _selectedTime,
                onDateTimeChanged: (DateTime newTime) {
                  setState(() {
                    _selectedTime = newTime;
                  });
                },
                use24hFormat: false,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Options Group
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Date Selection
                GestureDetector(
                  onTap: _showDatePicker,
                  child: _buildOptionRow(
                    label: 'Date',
                    child: Row(
                      children: [
                        Text(
                          _getDateLabel(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 16),

                // Label
                _buildOptionRow(
                  label: 'Label',
                  child: Expanded(
                    child: TextField(
                      controller: _labelController,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 17),
                      decoration: const InputDecoration(
                        hintText: 'Alarm',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 16),

                // Sound
                GestureDetector(
                  onTap: _showSoundPicker,
                  child: _buildOptionRow(
                    label: 'Sound',
                    child: Row(
                      children: [
                        Text(
                          _soundDisplayName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 16),
                
                // Repeat (Only if specific date is NOT selected)
                if (_selectedDate == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Repeat',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRepeatDays(),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 16),
                ],

                // Challenge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Challenge',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                      Switch(
                        value: _isChallenge,
                        onChanged: (value) {
                          setState(() {
                            _isChallenge = value;
                          });
                        },
                        activeColor: AppTheme.secondary,
                        activeTrackColor: AppTheme.secondary,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFF39393D),
                      ),
                    ],
                  ),
                ),
                
                if (_isChallenge) ...[
                  const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          DailyChallengeService().getChallengeIcon(
                            DailyChallengeService().getTodaysChallengeType()
                          ),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Challenge",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                DailyChallengeService().getChallengeDisplayName(
                                  DailyChallengeService().getTodaysChallengeType()
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRepeatDays() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _repeatDays[index] = !_repeatDays[index];
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _repeatDays[index]
                  ? AppTheme.primary
                  : const Color(0xFF3A3A3C),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                dayNames[index][0],
                style: TextStyle(
                  color: _repeatDays[index]
                      ? Colors.white
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
