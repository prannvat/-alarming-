import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/alarm_manager_service.dart';
import '../../alarm/providers/alarm_provider.dart';

class MemoryChallengeScreen extends ConsumerStatefulWidget {
  final String difficulty;
  final String alarmId;

  const MemoryChallengeScreen({
    super.key,
    required this.difficulty,
    required this.alarmId,
  });

  @override
  ConsumerState<MemoryChallengeScreen> createState() => _MemoryChallengeScreenState();
}

class _MemoryChallengeScreenState extends ConsumerState<MemoryChallengeScreen> {
  late DateTime _startTime;
  late int _gridSize;
  late int _pairsCount;
  late List<IconData> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;
  int? _firstCardIndex;
  int _moves = 0;
  int _matchedPairs = 0;
  bool _isProcessing = false;

  static const List<IconData> icons = [
    Icons.rocket_launch_rounded,
    Icons.pets_rounded,
    Icons.eco_rounded,
    Icons.bolt_rounded,
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.music_note_rounded,
    Icons.flight_rounded,
    Icons.directions_car_rounded,
    Icons.anchor_rounded,
    Icons.ac_unit_rounded,
    Icons.wb_sunny_rounded,
    Icons.local_fire_department_rounded,
    Icons.water_drop_rounded,
    Icons.diamond_rounded,
    Icons.extension_rounded,
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

    // Create pairs of icons
    final selectedIcons = icons.sublist(0, _pairsCount);
    _cards = [...selectedIcons, ...selectedIcons];
    _cards.shuffle(Random());

    // Pad to fill grid if needed (using a placeholder icon for empty spots)
    while (_cards.length < _gridSize * _gridSize) {
      _cards.add(Icons.crop_square); // Placeholder, shouldn't be clickable
    }

    _revealed = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_revealed[index]) return;
    if (_matched[index]) return;
    if (_cards[index] == Icons.crop_square) return; // Ignore placeholder

    HapticFeedback.selectionClick();

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
      HapticFeedback.mediumImpact();
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
      HapticFeedback.lightImpact();
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
          debugPrint('Auto-disabled non-repeating alarm after memory challenge');
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
                    const Icon(Icons.psychology_rounded, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'MEMORY',
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
                    _buildStat(Icons.touch_app_outlined, '$_moves'),
                    _buildStat(Icons.check_circle_outline, '$_matchedPairs/$_pairsCount'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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
                            if (_cards[index] == Icons.crop_square) {
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
                  color: AppTheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Find all matching pairs to dismiss the alarm!',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
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

  Widget _buildCard(int index) {
    final isRevealed = _revealed[index] || _matched[index];
    final isMatched = _matched[index];

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isRevealed
              ? (isMatched ? AppTheme.success : AppTheme.primary)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isMatched
                  ? AppTheme.success.withOpacity(0.3)
                  : (isRevealed ? AppTheme.primary.withOpacity(0.3) : Colors.transparent),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isRevealed ? Colors.transparent : AppTheme.textSecondary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRevealed
                ? Icon(
                    _cards[index],
                    key: ValueKey('revealed_$index'),
                    size: 36,
                    color: Colors.white,
                  )
                : Icon(
                    Icons.question_mark_rounded,
                    key: ValueKey('hidden_$index'),
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }
}
