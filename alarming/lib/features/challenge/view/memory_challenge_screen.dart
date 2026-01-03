import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';

class MemoryChallengeScreen extends StatefulWidget {
  final String difficulty;
  final String alarmId;

  const MemoryChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  State<MemoryChallengeScreen> createState() => _MemoryChallengeScreenState();
}

class _MemoryChallengeScreenState extends State<MemoryChallengeScreen> {
  late DateTime _startTime;
  late int _gridSize;
  late int _pairsCount;
  late List<String> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;
  int? _firstCardIndex;
  int _moves = 0;
  int _matchedPairs = 0;
  bool _isProcessing = false;

  static const List<String> emojis = [
    '🍎', '🍊', '🍋', '🍇', '🍓', '🍒', '🥝', '🍑',
    '🌟', '🌙', '⭐', '🌈', '🔥', '💧', '🌸', '🌺',
    '🎮', '🎯', '🎲', '🎪', '🎨', '🎭', '🎬', '🎤',
    '🚀', '✈️', '🚗', '🚂', '⛵', '🏠', '🏰', '🗼',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initializeGame();
  }

  void _initializeGame() {
    switch (widget.difficulty) {
      case 'easy':
        _gridSize = 3;
        _pairsCount = 4;
        break;
      case 'hard':
        _gridSize = 4;
        _pairsCount = 8;
        break;
      default: // medium
        _gridSize = 4;
        _pairsCount = 6;
    }

    // Create pairs of emojis
    final selectedEmojis = emojis.sublist(0, _pairsCount);
    _cards = [...selectedEmojis, ...selectedEmojis];
    _cards.shuffle(Random());

    // Pad to fill grid if needed
    while (_cards.length < _gridSize * _gridSize) {
      _cards.add('');
    }

    _revealed = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_revealed[index]) return;
    if (_matched[index]) return;
    if (_cards[index].isEmpty) return;

    setState(() {
      _revealed[index] = true;
    });

    if (_firstCardIndex == null) {
      _firstCardIndex = index;
    } else {
      _moves++;
      _checkMatch(index);
    }
  }

  void _checkMatch(int secondIndex) async {
    final firstIndex = _firstCardIndex!;
    _firstCardIndex = null;

    if (_cards[firstIndex] == _cards[secondIndex]) {
      // Match found!
      setState(() {
        _matched[firstIndex] = true;
        _matched[secondIndex] = true;
        _matchedPairs++;
      });

      if (_matchedPairs >= _pairsCount) {
        _completeChallenge();
      }
    } else {
      // No match - hide cards after delay
      _isProcessing = true;
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _revealed[firstIndex] = false;
          _revealed[secondIndex] = false;
          _isProcessing = false;
        });
      }
    }
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
          'challengeType': 'memory',
        },
      );
    }
  }

  int _calculatePoints(Duration completionTime) {
    const basePoints = 200;
    final timePenalty = (completionTime.inSeconds * 0.5).round();
    final movePenalty = (_moves - _pairsCount) * 5; // Optimal moves = pairs count

    final difficultyMultiplier = widget.difficulty == 'easy'
        ? 1.0
        : widget.difficulty == 'hard'
            ? 2.0
            : 1.5;

    final score = (basePoints - timePenalty - movePenalty) * difficultyMultiplier;
    return score.round().clamp(10, 500);
  }

  @override
  Widget build(BuildContext context) {
    final elapsedTime = DateTime.now().difference(_startTime).inSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
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
                    const Text(
                      '🧠 ',
                      style: TextStyle(fontSize: 28),
                    ),
                    Text(
                      'MEMORY',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
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
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('⏱️', '${elapsedTime}s'),
                    _buildStat('👆', '$_moves'),
                    _buildStat('✅', '$_matchedPairs/$_pairsCount'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Game Grid
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate optimal grid size
                      final size = min(constraints.maxWidth, constraints.maxHeight);
                      
                      return SizedBox(
                        width: size,
                        height: size,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridSize,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _cards.length,
                          itemBuilder: (context, index) {
                            if (_cards[index].isEmpty) {
                              return const SizedBox();
                            }
                            return _buildCard(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Hint text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Find all matching pairs to dismiss the alarm!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String icon, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final isRevealed = _revealed[index] || _matched[index];
    final isMatched = _matched[index];

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isRevealed
              ? LinearGradient(
                  colors: isMatched
                      ? [const Color(0xFF00C853), const Color(0xFF009624)]
                      : [const Color(0xFF6C63FF), const Color(0xFF4834D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF0F3460),
                    const Color(0xFF16213E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isMatched
                  ? const Color(0xFF00C853).withOpacity(0.3)
                  : const Color(0xFF6C63FF).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRevealed
                ? Text(
                    _cards[index],
                    key: ValueKey('revealed_$index'),
                    style: const TextStyle(fontSize: 36),
                  )
                : Icon(
                    Icons.question_mark_rounded,
                    key: ValueKey('hidden_$index'),
                    color: Colors.white.withOpacity(0.5),
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }
}
