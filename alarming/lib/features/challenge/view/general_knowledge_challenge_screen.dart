import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../services/general_knowledge_challenge.dart';

class GeneralKnowledgeChallengeScreen extends StatefulWidget {
  final String difficulty;
  final String alarmId;

  const GeneralKnowledgeChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  State<GeneralKnowledgeChallengeScreen> createState() => _GeneralKnowledgeChallengeScreenState();
}

class _GeneralKnowledgeChallengeScreenState extends State<GeneralKnowledgeChallengeScreen> {
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
    final nativeAlarmId = int.parse(widget.alarmId.substring(0, 9));
    await Alarm.stop(nativeAlarmId);
    AlarmManagerService().dismissCurrentAlarm();

    final completionTime = DateTime.now().difference(_startTime);
    final points = _calculatePoints(completionTime);

    if (mounted) {
      context.pushReplacement(
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
      backgroundColor: const Color(0xFF0F172A), // Deep Blue/Slate
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${elapsedTime}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_currentQuestionIndex + 1}/${_questions.length}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Question Card
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        currentQuestion.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Options
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(currentQuestion.options.length, (index) {
                    final isSelected = _selectedOptionIndex == index;
                    final isCorrect = index == currentQuestion.correctIndex;
                    
                    Color backgroundColor = Colors.white.withOpacity(0.05);
                    Color borderColor = Colors.white.withOpacity(0.1);
                    
                    if (_hasAnswered) {
                      if (isSelected) {
                        backgroundColor = isCorrect 
                            ? AppTheme.success.withOpacity(0.2)
                            : AppTheme.error.withOpacity(0.2);
                        borderColor = isCorrect ? AppTheme.success : AppTheme.error;
                      } else if (isCorrect) {
                        // Show correct answer if user picked wrong
                        backgroundColor = AppTheme.success.withOpacity(0.2);
                        borderColor = AppTheme.success;
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
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    currentQuestion.options[index],
                                    style: const TextStyle(
                                      color: Colors.white,
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
}
