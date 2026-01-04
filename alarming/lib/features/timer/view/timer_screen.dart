import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/timer_provider.dart';
import '../../alarm/view/sound_picker_screen.dart';

class TimerScreen extends ConsumerStatefulWidget {
  final String? timerId;
  
  const TimerScreen({super.key, this.timerId});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  String _selectedSound = 'assets/sounds/alarm.mp3';
  Duration _selectedDuration = const Duration(minutes: 5);
  final TextEditingController _labelController = TextEditingController(text: 'Timer');

  final List<Map<String, String>> _availableSounds = [
    {'name': 'Classic Alarm', 'path': 'assets/sounds/alarm.mp3'},
    {'name': 'Gentle Chime', 'path': 'assets/sounds/gentle_chime.mp3'},
    {'name': 'Digital Beep', 'path': 'assets/sounds/digital_beep.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.timerId != null) {
      // Find the timer in the list and initialize with its values
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final timers = ref.read(timersProvider);
        final timer = timers.where((t) => t.id == widget.timerId).firstOrNull;
        if (timer != null) {
          setState(() {
            _selectedSound = timer.soundPath;
            _selectedDuration = timer.duration;
            _labelController.text = timer.label;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  TimerState? get _currentTimer {
    if (widget.timerId == null) return null;
    final timers = ref.watch(timersProvider);
    return timers.where((t) => t.id == widget.timerId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final timersNotifier = ref.read(timersProvider.notifier);
    final currentTimer = _currentTimer;
    final isEditing = currentTimer != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? currentTimer.label : 'New Timer',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: isEditing
                  ? _buildCountdown(currentTimer)
                  : _buildNewTimerForm(timersNotifier),
            ),
            if (!isEditing) _buildSoundSelector(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildButtons(isEditing ? currentTimer : null, timersNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GestureDetector(
        onTap: _showSoundPicker,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.music_note, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timer Sound',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _availableSounds.firstWhere(
                        (s) => s['path'] == _selectedSound,
                        orElse: () => _availableSounds.first,
                      )['name']!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoundPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SoundPickerScreen(
          currentSoundPath: _selectedSound,
        ),
      ),
    );
    
    if (result != null && result is String) {
      setState(() => _selectedSound = result);
    }
  }

  Widget _buildNewTimerForm(TimersNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Label input
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              controller: _labelController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Timer Name',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.surface),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ),
          ),
          // Duration picker
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                pickerTextStyle: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                ),
              ),
            ),
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hms,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (Duration newDuration) {
                setState(() => _selectedDuration = newDuration);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown(TimerState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 280,
                height: 280,
                child: CircularProgressIndicator(
                  value: state.remaining.inSeconds / (state.duration.inSeconds == 0 ? 1 : state.duration.inSeconds),
                  strokeWidth: 12,
                  backgroundColor: AppTheme.surface,
                  color: state.isPaused ? AppTheme.textSecondary : AppTheme.primary,
                ),
              ),
              Column(
                children: [
                  Text(
                    _formatDuration(state.remaining),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 56,
                      fontWeight: FontWeight.w200,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (state.isPaused)
                    const Text(
                      'PAUSED',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(TimerState? state, TimersNotifier notifier) {
    // If state is null, this is a new timer
    if (state == null) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () async {
            print('🔘🔘🔘 START BUTTON PRESSED! 🔘🔘🔘');
            try {
              if (_selectedDuration.inSeconds == 0) {
                print('⚙️ Duration is 0, cannot start');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please set a timer duration')),
                );
                return;
              }
              print('📞 Calling notifier.startTimer()...');
              await notifier.startTimer(
                duration: _selectedDuration,
                label: _labelController.text.trim().isEmpty ? 'Timer' : _labelController.text.trim(),
                soundPath: _selectedSound,
              );
              print('✅✅✅ notifier.startTimer() COMPLETED ✅✅✅');
              if (mounted) context.pop();
            } catch (e, stack) {
              print('❌❌❌ ERROR IN BUTTON: $e');
              print('Stack: $stack');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            foregroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Start Timer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Editing existing timer
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                await notifier.cancelTimer(state.id);
                if (mounted) context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (state.isRunning) {
                  await notifier.pauseTimer(state.id);
                } else {
                  await notifier.resumeTimer(state.id);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                state.isRunning ? 'Pause' : 'Resume',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
