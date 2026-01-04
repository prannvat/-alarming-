import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../challenge/view/math_challenge_screen.dart';
import '../../challenge/view/wordle_challenge_screen.dart';
import '../../challenge/view/memory_challenge_screen.dart';
import '../../challenge/view/general_knowledge_challenge_screen.dart';

class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Debug Menu'),
        backgroundColor: AppTheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Challenge Previews'),
          _buildDebugItem(
            context,
            'Math Challenge (Medium)',
            Icons.calculate,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MathChallengeScreen(
                  difficulty: 'medium',
                  alarmId: 'debug_alarm',
                ),
              ),
            ),
          ),
          _buildDebugItem(
            context,
            'Wordle Challenge (Medium)',
            Icons.grid_4x4,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WordleChallengeScreen(
                  difficulty: 'medium',
                  alarmId: 'debug_alarm',
                ),
              ),
            ),
          ),
          _buildDebugItem(
            context,
            'Memory Challenge (Medium)',
            Icons.memory,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MemoryChallengeScreen(
                  difficulty: 'medium',
                  alarmId: 'debug_alarm',
                ),
              ),
            ),
          ),
          _buildDebugItem(
            context,
            'General Knowledge (Medium)',
            Icons.quiz,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GeneralKnowledgeChallengeScreen(
                  difficulty: 'medium',
                  alarmId: 'debug_alarm',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDebugItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.textPrimary),
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
