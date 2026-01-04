import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../../alarm/providers/alarm_provider.dart';
import '../services/general_knowledge_challenge.dart';

class GeneralKnowledgeChallengeScreen extends ConsumerStatefulWidget {
  final String difficulty;
  final String alarmId;

  const GeneralKnowledgeChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  ConsumerState<GeneralKnowledgeChallengeScreen> createState() => _GeneralKnowledgeChallengeScreenState();
}

class _GeneralKnowledgeChallengeScreenState extends ConsumerState<GeneralKnowledgeChallengeScreen> {
  late List<GeneralKnowledgeQuestion> _questions;
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  late DateTime _startTime;
  bool _hasAnswered = false;
  int? _selectedOptionIndex;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    final challenge = GeneralKnowledgeChallenge(difficulty: widget.difficulty);
    _questions = challenge.generateQuestions(count: 3);
  }

  void _handleAnswer(int optionIndex) {
    if (_hasAnswered) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = optionIndex == currentQuestion.correctIndex;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _hasAnswered = true;
      _selectedOptionIndex = optionIndex;
      _isCorrect = isCorrect;
      if (isCorrect) _correctAnswers++;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        if (_currentQuestionIndex < _questions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
            _hasAnswered = false;
            _selectedOptionIndex = null;
          });
        } else {
          _completeChallenge();
        }
      }
    });
  }

  void _completeChallenge() async {
    // Stop the alarm
    if (widget.alarmId != 'debug_alarm') {
      try {
        final nativeAlarmId = int.parse(widget.alarmId.substring(0, 9));
        await Alarm.stop(nativeAlarmId);
      } catch (e) {
        debugPrint('Error stopping native alarm: $e');
      }
    }
    AlarmManagerService().dismissCurrentAlarm();

    // Auto-disable non-repeating alarms
    try {
      final alarmRepository = ref.read(alarmRepositoryProvider);
      final alarm = await alarmRepository.getAlarm(widget.alarmId);
      
      if (alarm != null) {
        final isRepeating = alarm.repeatDays.any((day) => day);
        if (!isRepeating && alarm.isEnabled) {
          await alarmRepository.updateAlarm(alarm.copyWith(isEnabled: false));
          debugPrint('Auto-disabled non-repeating alarm after general knowledge challenge');
        }
      }
    } catch (e) {
      debugPrint('Error auto-disabling alarm: $e');
    }

    final completionTime = DateTime.now().difference(_startTime);
    final points = _calculatePoints(completionTime);

    if (mounted) {
      context.go(
        '/challenge/complete',
        extra: {
          'completionTime': completionTime.inSeconds,
          'points': points,
          'difficulty': widget.difficulty,
          'challengeType': 'quiz',
        },
      );
    }
  }

  int _calculatePoints(Duration completionTime) {
    const basePoints = 150;
    final timePenalty = (completionTime.inSeconds * 0.5).round();
    final accuracyBonus = _correctAnswers * 50;

    final difficultyMultiplier = widget.difficulty == 'easy'
        ? 1.0
        : widget.difficulty == 'hard'
            ? 2.0
            : 1.5;

    final score = (basePoints - timePenalty + accuracyBonus) * difficultyMultiplier;
    return score.round().clamp(10, 500);
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];
    final elapsedTime = DateTime.now().difference(_startTime).inSeconds;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_rounded, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'QUIZ',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Stats Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(Icons.timer_outlined, '${elapsedTime}s'),
                    _buildStat(Icons.quiz_outlined, '${_currentQuestionIndex + 1}/${_questions.length}'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Question Card
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.textSecondary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        currentQuestion.question,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Options
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(currentQuestion.options.length, (index) {
                    final isSelected = _selectedOptionIndex == index;
                    final isCorrect = index == currentQuestion.correctIndex;
                    
                    Color backgroundColor = AppTheme.surface;
                    Color borderColor = AppTheme.textSecondary.withOpacity(0.1);
                    Color textColor = AppTheme.textPrimary;
                    
                    if (_hasAnswered) {
                      if (isSelected) {
                        backgroundColor = isCorrect 
                            ? AppTheme.success.withOpacity(0.2)
                            : AppTheme.error.withOpacity(0.2);
                        borderColor = isCorrect ? AppTheme.success : AppTheme.error;
                        textColor = isCorrect ? AppTheme.success : AppTheme.error;
                      } else if (isCorrect) {
                        // Show correct answer if user picked wrong
                        backgroundColor = AppTheme.success.withOpacity(0.2);
                        borderColor = AppTheme.success;
                        textColor = AppTheme.success;
                      }
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _handleAnswer(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.background,
                                    border: Border.all(
                                      color: isSelected || (_hasAnswered && isCorrect) 
                                          ? borderColor 
                                          : AppTheme.textSecondary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D
                                      style: TextStyle(
                                        color: isSelected || (_hasAnswered && isCorrect) 
                                            ? textColor 
                                            : AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    currentQuestion.options[index],
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_hasAnswered && (isSelected || isCorrect))
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect ? AppTheme.success : AppTheme.error,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
