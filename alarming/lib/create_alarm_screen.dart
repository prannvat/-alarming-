import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/notification_permission_handler.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';

class CreateAlarmScreen extends ConsumerStatefulWidget {
  const CreateAlarmScreen({super.key});

  @override
  ConsumerState<CreateAlarmScreen> createState() => _CreateAlarmScreenState();
}

class _CreateAlarmScreenState extends ConsumerState<CreateAlarmScreen> {
  late TimeOfDay _selectedTime;
  final TextEditingController _labelController = TextEditingController();
  List<bool> _repeatDays = List.filled(7, false);
  bool _isChallenge = false;
  String _challengeType = 'math';
  String _difficulty = 'medium';

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.surface,
              dialBackgroundColor: AppTheme.background,
              hourMinuteColor: AppTheme.primary.withOpacity(0.2),
              hourMinuteTextColor: AppTheme.textPrimary,
              dayPeriodColor: AppTheme.primary.withOpacity(0.2),
              dayPeriodTextColor: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _saveAlarm() {
    final alarm = AlarmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      label: _labelController.text,
      repeatDays: _repeatDays,
      isChallenge: _isChallenge,
      challengeType: _isChallenge ? _challengeType : null,
      difficulty: _difficulty,
    );

    final repository = ref.read(alarmRepositoryProvider);
    repository.addAlarm(alarm);

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Alarm'),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Time Picker
          GestureDetector(
            onTap: _selectTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  _selectedTime.format(context),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 72,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Label
          TextField(
            controller: _labelController,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: 'Label',
              hintText: 'Wake up',
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Repeat Days
          Text(
            'Repeat',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildRepeatDays(),

          const SizedBox(height: 32),

          // Challenge Toggle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isChallenge
                    ? AppTheme.secondary.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.games,
                          color: _isChallenge ? AppTheme.secondary : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Challenge Alarm',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    Switch(
                      value: _isChallenge,
                      onChanged: (value) {
                        setState(() {
                          _isChallenge = value;
                        });
                      },
                      activeColor: AppTheme.secondary,
                    ),
                  ],
                ),
                if (_isChallenge) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Challenge Type',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('Math', 'math'),
                      _buildChip('Wordle', 'wordle'),
                      _buildChip('Memory', 'memory'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Difficulty',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDifficultyChip('Easy', 'easy'),
                      _buildDifficultyChip('Medium', 'medium'),
                      _buildDifficultyChip('Hard', 'hard'),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _repeatDays[index]
                  ? AppTheme.primary
                  : AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                dayNames[index][0],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _repeatDays[index]
                      ? Colors.white
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _challengeType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _challengeType = value;
          });
        }
      },
      backgroundColor: AppTheme.background,
      selectedColor: AppTheme.secondary.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.secondary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildDifficultyChip(String label, String value) {
    final isSelected = _difficulty == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _difficulty = value;
          });
        }
      },
      backgroundColor: AppTheme.background,
      selectedColor: AppTheme.primary.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
