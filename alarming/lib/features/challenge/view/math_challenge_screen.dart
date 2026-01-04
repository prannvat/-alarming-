import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../../alarm/providers/alarm_provider.dart';
import '../services/math_challenge.dart';

class MathChallengeScreen extends ConsumerStatefulWidget {
  final String difficulty;
  final String alarmId;

  const MathChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  ConsumerState<MathChallengeScreen> createState() => _MathChallengeScreenState();
}

class _MathChallengeScreenState extends ConsumerState<MathChallengeScreen> {
  late List<MathQuestion> _questions;
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  String _userAnswer = '';
  late DateTime _startTime;
  bool _isAnswerWrong = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    final challenge = MathChallenge(difficulty: widget.difficulty);
    _questions = challenge.generateQuestions(count: 3);
  }

  void _submitAnswer() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final userAnswerInt = int.tryParse(_userAnswer);

    if (userAnswerInt == null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isAnswerWrong = true;
      });
      return;
    }

    if (userAnswerInt == currentQuestion.answer) {
      // Correct answer
      HapticFeedback.mediumImpact();
      setState(() {
        _correctAnswers++;
        _isAnswerWrong = false;
        
        if (_currentQuestionIndex < _questions.length - 1) {
          _currentQuestionIndex++;
          _userAnswer = '';
        } else {
          _completeChallenge();
        }
      });
    } else {
      // Wrong answer
      HapticFeedback.heavyImpact();
      setState(() {
        _isAnswerWrong = true;
      });
    }
  }

  void _completeChallenge() async {
    // Stop the alarm sound when challenge is completed
    AlarmManagerService().dismissCurrentAlarm();
    
    // Stop native alarm and disable if non-repeating
    try {
      final repository = ref.read(alarmRepositoryProvider);
      final alarm = await repository.getAlarm(widget.alarmId);
      
      if (alarm != null) {
        final nativeAlarmId = int.parse(alarm.id.substring(0, 9));
        await Alarm.stop(nativeAlarmId);
        print('🔇 Stopped native alarm after challenge: $nativeAlarmId');
        
        // If alarm is not repeating, disable it
        final isRepeating = alarm.repeatDays.any((day) => day);
        print('🔍 Alarm repeating: $isRepeating (repeatDays: ${alarm.repeatDays})');
        
        if (!isRepeating) {
          print('🔕 One-time alarm completed challenge, disabling...');
          await repository.updateAlarm(alarm.copyWith(isEnabled: false));
        } else {
          print('🔁 Repeating alarm completed challenge, will ring again on next scheduled day');
        }
      }
    } catch (e) {
      print('Error stopping alarm: $e');
    }
    
    final completionTime = DateTime.now().difference(_startTime);
    final points = _calculatePoints(completionTime);

    // Navigate to completion screen
    if (mounted) {
      context.go(
        '/challenge/complete',
        extra: {
          'completionTime': completionTime.inSeconds,
          'points': points,
          'difficulty': widget.difficulty,
        },
      );
    }
  }

  int _calculatePoints(Duration completionTime) {
    const basePoints = 100;
    final timePenalty = (completionTime.inSeconds * 0.5).round();
    
    final difficultyMultiplier = widget.difficulty == 'easy'
        ? 1.0
        : widget.difficulty == 'hard'
            ? 2.0
            : 1.5;

    final score = (basePoints - timePenalty) * difficultyMultiplier;
    return score.round().clamp(10, 300);
  }

  void _addDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _userAnswer += digit;
      _isAnswerWrong = false;
    });
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _userAnswer = '';
      _isAnswerWrong = false;
    });
  }

  void _backspace() {
    if (_userAnswer.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _userAnswer = _userAnswer.substring(0, _userAnswer.length - 1);
        _isAnswerWrong = false;
      });
    }
  }

  void _toggleNegative() {
    setState(() {
      if (_userAnswer.startsWith('-')) {
        _userAnswer = _userAnswer.substring(1);
      } else if (_userAnswer.isNotEmpty) {
        _userAnswer = '-$_userAnswer';
      }
    });
  }

  String _formatQuestion(String question) {
    return question
        .replaceAll('*', '×')
        .replaceAll('/', '÷')
        .replaceAll('+', ' + ')
        .replaceAll('-', ' - ')
        .replaceAll('  ', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];
    final elapsedTime = DateTime.now().difference(_startTime).inSeconds;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${elapsedTime}s',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Question Area
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Solve to dismiss',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_formatQuestion(currentQuestion.question)} = ?',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 70,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isAnswerWrong
                          ? AppTheme.error.withOpacity(0.1)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isAnswerWrong ? AppTheme.error : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _userAnswer.isEmpty ? '?' : _userAnswer,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _isAnswerWrong ? AppTheme.error : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentQuestionIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: index <= _currentQuestionIndex
                          ? AppTheme.primary
                          : AppTheme.surface,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Number Pad
              Expanded(
                flex: 5,
                child: _buildNumberPad(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildNumberButton('1'),
              _buildNumberButton('2'),
              _buildNumberButton('3'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildNumberButton('4'),
              _buildNumberButton('5'),
              _buildNumberButton('6'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildNumberButton('7'),
              _buildNumberButton('8'),
              _buildNumberButton('9'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildActionButton('±', _toggleNegative),
              _buildNumberButton('0'),
              _buildActionButton('⌫', _backspace),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton('Clear', _clear, isPrimary: false),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildActionButton('Submit', _submitAnswer, isPrimary: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(40), // Circular/Oval buttons
          child: InkWell(
            onTap: () => _addDigit(number),
            borderRadius: BorderRadius.circular(40),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap, {bool isPrimary = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: isPrimary ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(40),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(40),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isPrimary ? 20 : 24,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w400,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
