import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_sound_service.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../services/math_challenge.dart';

class MathChallengeScreen extends StatefulWidget {
  final String difficulty;
  final String alarmId;

  const MathChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  State<MathChallengeScreen> createState() => _MathChallengeScreenState();
}

class _MathChallengeScreenState extends State<MathChallengeScreen> {
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
      setState(() {
        _isAnswerWrong = true;
      });
      return;
    }

    if (userAnswerInt == currentQuestion.answer) {
      // Correct answer
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
      setState(() {
        _isAnswerWrong = true;
      });
    }
  }

  void _completeChallenge() async {
    // Stop the alarm sound when challenge is completed
    AlarmManagerService().dismissCurrentAlarm();
    
    final completionTime = DateTime.now().difference(_startTime);
    final points = _calculatePoints(completionTime);

    // Navigate to completion screen
    if (mounted) {
      context.pushReplacement(
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
    setState(() {
      _userAnswer += digit;
      _isAnswerWrong = false;
    });
  }

  void _clear() {
    setState(() {
      _userAnswer = '';
      _isAnswerWrong = false;
    });
  }

  void _backspace() {
    if (_userAnswer.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];
    final elapsedTime = DateTime.now().difference(_startTime).inSeconds;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${elapsedTime}s',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Question
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.surface, AppTheme.surface.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isAnswerWrong
                          ? AppTheme.error
                          : AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isAnswerWrong 
                            ? AppTheme.error.withOpacity(0.2) 
                            : AppTheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Solve to dismiss',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${currentQuestion.question} = ?',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: _isAnswerWrong
                              ? AppTheme.error.withOpacity(0.1)
                              : Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isAnswerWrong ? AppTheme.error : Colors.transparent,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _userAnswer.isEmpty ? '?' : _userAnswer,
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 48,
                              color: _isAnswerWrong ? AppTheme.error : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentQuestionIndex ? 24 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: index <= _currentQuestionIndex
                          ? AppTheme.primary
                          : AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Number Pad
              _buildNumberPad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        Row(
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        Row(
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        Row(
          children: [
            _buildActionButton('±', _toggleNegative),
            _buildNumberButton('0'),
            _buildActionButton('⌫', _backspace),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Clear', _clear, isPrimary: false),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildActionButton('Submit', _submitAnswer, isPrimary: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.3,
        child: GestureDetector(
          onTap: () => _addDigit(number),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60, // Fixed height for bottom actions
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: isPrimary 
              ? const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFFFFB340)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isPrimary 
                  ? AppTheme.primary.withOpacity(0.3) 
                  : Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isPrimary ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
