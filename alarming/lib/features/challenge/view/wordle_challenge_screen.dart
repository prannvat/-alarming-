import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../services/wordle_challenge.dart';

class WordleChallengeScreen extends StatefulWidget {
  final String difficulty;
  final String alarmId;

  const WordleChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  State<WordleChallengeScreen> createState() => _WordleChallengeScreenState();
}

class _WordleChallengeScreenState extends State<WordleChallengeScreen> {
  late WordleChallenge _challenge;
  late DateTime _startTime;
  final List<String> _guesses = [];
  String _currentGuess = '';
  bool _isGameOver = false;
  bool _hasWon = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _challenge = WordleChallenge(difficulty: widget.difficulty);
  }

  void _addLetter(String letter) {
    if (_currentGuess.length < _challenge.wordLength && !_isGameOver) {
      setState(() {
        _currentGuess += letter.toUpperCase();
        _errorMessage = null;
      });
    }
  }

  void _removeLetter() {
    if (_currentGuess.isNotEmpty && !_isGameOver) {
      setState(() {
        _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _submitGuess() {
    if (_currentGuess.length != _challenge.wordLength) {
      setState(() {
        _errorMessage = 'Word must be ${_challenge.wordLength} letters';
      });
      return;
    }

    if (!_challenge.isValidWord(_currentGuess)) {
      setState(() {
        _errorMessage = 'Not a valid word';
      });
      return;
    }

    setState(() {
      _guesses.add(_currentGuess);
      _errorMessage = null;

      if (_currentGuess == _challenge.targetWord) {
        _hasWon = true;
        _isGameOver = true;
        _completeChallenge();
      } else if (_guesses.length >= _challenge.maxAttempts) {
        _isGameOver = true;
        // Still complete but with penalty
        _completeChallenge();
      }

      _currentGuess = '';
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
      backgroundColor: const Color(0xFF121213),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '📝 ',
                    style: TextStyle(fontSize: 28),
                  ),
                  Text(
                    'WORDLE',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 8),

            // Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - (_challenge.wordLength - 1) * 6) / _challenge.wordLength;
                    final itemHeight = itemWidth; // Square cells
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_challenge.maxAttempts, (rowIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_challenge.wordLength, (colIndex) {
                              String letter = '';
                              Color bgColor = const Color(0xFF121213);
                              Color borderColor = const Color(0xFF3A3A3C);

                              if (rowIndex < _guesses.length) {
                                letter = _guesses[rowIndex][colIndex];
                                bgColor = _getLetterColor(letter, colIndex, rowIndex);
                                borderColor = bgColor;
                              } else if (rowIndex == _guesses.length && colIndex < _currentGuess.length) {
                                letter = _currentGuess[colIndex];
                                borderColor = const Color(0xFF565758);
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
                                      fontSize: itemHeight.clamp(30.0, 60.0) * 0.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildKeyboard(),
            ),

            const SizedBox(height: 16),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              final isSpecial = key == 'ENTER' || key == '⌫';
              
              return Expanded(
                flex: isSpecial ? 3 : 2,
                child: GestureDetector(
                  onTap: () {
                    if (key == 'ENTER') {
                      _submitGuess();
                    } else if (key == '⌫') {
                      _removeLetter();
                    } else {
                      _addLetter(key);
                    }
                  },
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSpecial ? const Color(0xFF818384) : _getKeyboardLetterColor(key),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: isSpecial && key == '⌫' 
                        ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 20)
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
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
