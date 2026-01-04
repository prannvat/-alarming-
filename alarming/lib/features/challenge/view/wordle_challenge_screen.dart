import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../../alarm/providers/alarm_provider.dart';
import '../services/wordle_challenge.dart';
import '../services/wordle_dictionary.dart';
import '../services/dictionary_service.dart';

class WordleChallengeScreen extends ConsumerStatefulWidget {
  final String difficulty;
  final String alarmId;

  const WordleChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  ConsumerState<WordleChallengeScreen> createState() => _WordleChallengeScreenState();
}

class _WordleChallengeScreenState extends ConsumerState<WordleChallengeScreen> {
  late WordleChallenge _challenge;
  late DateTime _startTime;
  final List<String> _guesses = [];
  String _currentGuess = '';
  bool _isGameOver = false;
  bool _hasWon = false;
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _challenge = WordleChallenge(difficulty: widget.difficulty);
  }

  void _addLetter(String letter) {
    if (_currentGuess.length < _challenge.wordLength && !_isGameOver && !_isValidating) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentGuess += letter.toUpperCase();
        _errorMessage = null;
      });
    }
  }

  void _removeLetter() {
    if (_currentGuess.isNotEmpty && !_isGameOver && !_isValidating) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitGuess() async {
    if (_isValidating) return;

    if (_currentGuess.length != _challenge.wordLength) {
      HapticFeedback.mediumImpact();
      setState(() {
        _errorMessage = 'Word must be ${_challenge.wordLength} letters';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    // Check against the API dictionary
    final isValid = await DictionaryService.validateWord(_currentGuess);

    if (!mounted) return;

    setState(() {
      _isValidating = false;
    });

    if (!isValid && !_challenge.isValidWord(_currentGuess)) {
      HapticFeedback.mediumImpact();
      setState(() {
        _errorMessage = 'Not a valid word';
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _guesses.add(_currentGuess);
      _errorMessage = null;

      if (_currentGuess == _challenge.targetWord) {
        _hasWon = true;
        _isGameOver = true;
        HapticFeedback.heavyImpact();
        _completeChallenge();
      } else if (_guesses.length >= _challenge.maxAttempts) {
        _isGameOver = true;
        HapticFeedback.heavyImpact();
        // Still complete but with penalty
        _completeChallenge();
      }

      _currentGuess = '';
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
          debugPrint('Auto-disabled non-repeating alarm after wordle challenge');
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
          'challengeType': 'wordle',
        },
      );
    }
  }

  int _calculatePoints(Duration completionTime) {
    int basePoints = _hasWon ? 150 : 50;
    final timePenalty = (completionTime.inSeconds * 0.3).round();
    final attemptBonus = _hasWon ? ((_challenge.maxAttempts - _guesses.length) * 20) : 0;

    final difficultyMultiplier = widget.difficulty == 'easy'
        ? 1.0
        : widget.difficulty == 'hard'
            ? 2.0
            : 1.5;

    final score = (basePoints - timePenalty + attemptBonus) * difficultyMultiplier;
    return score.round().clamp(10, 400);
  }

  Color _getLetterColor(String letter, int position, int guessIndex) {
    if (guessIndex >= _guesses.length) return AppTheme.surface;

    final guess = _guesses[guessIndex];
    final target = _challenge.targetWord;

    if (guess[position] == target[position]) {
      return const Color(0xFF538D4E); // Green - correct position
    } else if (target.contains(guess[position])) {
      return const Color(0xFFB59F3B); // Yellow - wrong position
    } else {
      return const Color(0xFF3A3A3C); // Gray - not in word
    }
  }

  Color _getKeyboardLetterColor(String letter) {
    for (final guess in _guesses) {
      for (int i = 0; i < guess.length; i++) {
        if (guess[i] == letter) {
          if (_challenge.targetWord[i] == letter) {
            return const Color(0xFF538D4E);
          } else if (_challenge.targetWord.contains(letter)) {
            return const Color(0xFFB59F3B);
          } else {
            return const Color(0xFF3A3A3C);
          }
        }
      }
    }
    return const Color(0xFF818384);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view_rounded, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'WORDLE',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppTheme.surface, height: 1),
            const SizedBox(height: 16),

            // Error message
            AnimatedOpacity(
              opacity: _errorMessage != null || _isValidating ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
                ),
                child: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : Text(
                        _errorMessage ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - (_challenge.wordLength - 1) * 6) / _challenge.wordLength;
                    final itemHeight = itemWidth; // Square cells
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(_challenge.maxAttempts, (rowIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_challenge.wordLength, (colIndex) {
                              String letter = '';
                              Color bgColor = Colors.transparent;
                              Color borderColor = const Color(0xFF3A3A3C);
                              Color textColor = Colors.white;

                              if (rowIndex < _guesses.length) {
                                letter = _guesses[rowIndex][colIndex];
                                bgColor = _getLetterColor(letter, colIndex, rowIndex);
                                borderColor = bgColor;
                              } else if (rowIndex == _guesses.length && colIndex < _currentGuess.length) {
                                letter = _currentGuess[colIndex];
                                borderColor = const Color(0xFF565758);
                                // Pop animation effect could be added here with a separate widget
                              }

                              return Container(
                                width: itemWidth.clamp(30.0, 60.0),
                                height: itemHeight.clamp(30.0, 60.0),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  border: Border.all(color: borderColor, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: itemHeight.clamp(30.0, 60.0) * 0.6,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),

            // Keyboard
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: _buildKeyboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    const rows = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              final isSpecial = key == 'ENTER' || key == '⌫';
              final color = isSpecial ? const Color(0xFF818384) : _getKeyboardLetterColor(key);
              
              return Expanded(
                flex: isSpecial ? 3 : 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () {
                        if (key == 'ENTER') {
                          _submitGuess();
                        } else if (key == '⌫') {
                          _removeLetter();
                        } else {
                          _addLetter(key);
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 56,
                        child: Center(
                          child: isSpecial && key == '⌫' 
                            ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 22)
                            : Text(
                                key,
                                style: TextStyle(
                                  fontSize: isSpecial ? 12 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
