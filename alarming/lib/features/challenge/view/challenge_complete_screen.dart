import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/challenge_cooldown_provider.dart';

class ChallengeCompleteScreen extends ConsumerStatefulWidget {
  final int completionTime;
  final int points;
  final String difficulty;

  const ChallengeCompleteScreen({
    super.key,
    required this.completionTime,
    required this.points,
    required this.difficulty,
  });

  @override
  ConsumerState<ChallengeCompleteScreen> createState() => _ChallengeCompleteScreenState();
}

class _ChallengeCompleteScreenState extends ConsumerState<ChallengeCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    
    // Record challenge completion for cooldown
    _recordCompletion();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    
    _animationController.forward();
    _confettiController.play();
  }

  Future<void> _recordCompletion() async {
    try {
      await ref.read(challengeCooldownServiceProvider).recordCompletion();
    } catch (e) {
      debugPrint('Error recording challenge completion: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Success Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.success.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'CHALLENGE COMPLETE!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Stats Container
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          Icons.timer,
                          'Completion Time',
                          _formatTime(widget.completionTime),
                        ),
                        const SizedBox(height: 24),
                        _buildStatRow(
                          Icons.star,
                          'Points Earned',
                          '+${widget.points}',
                          valueColor: AppTheme.accent,
                        ),
                        const SizedBox(height: 24),
                        _buildStatRow(
                          Icons.trending_up,
                          'Difficulty',
                          widget.difficulty.toUpperCase(),
                          valueColor: _getDifficultyColor(),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            context.go('/');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Good Morning!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to leaderboard
                          context.go('/');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.leaderboard, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Text(
                              'View Leaderboard',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                AppTheme.primary,
                AppTheme.secondary,
                AppTheme.accent,
                AppTheme.success,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Color _getDifficultyColor() {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        return AppTheme.success;
      case 'hard':
        return AppTheme.error;
      case 'medium':
      default:
        return AppTheme.warning;
    }
  }
}
