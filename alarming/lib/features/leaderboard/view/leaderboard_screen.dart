import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/app_theme.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final List<LeaderboardEntry> entries = [
      LeaderboardEntry(id: '1', name: 'Sarah W.', score: 2450, rank: 1),
      LeaderboardEntry(id: '2', name: 'Mike T.', score: 2300, rank: 2),
      LeaderboardEntry(id: '3', name: 'Jessica L.', score: 2150, rank: 3),
      LeaderboardEntry(id: '4', name: 'David K.', score: 1900, rank: 4),
      LeaderboardEntry(id: '5', name: 'You', score: 1850, rank: 5, isCurrentUser: true),
      LeaderboardEntry(id: '6', name: 'Tom H.', score: 1700, rank: 6),
      LeaderboardEntry(id: '7', name: 'Emily R.', score: 1650, rank: 7),
      LeaderboardEntry(id: '8', name: 'Chris P.', score: 1500, rank: 8),
      LeaderboardEntry(id: '9', name: 'Anna M.', score: 1450, rank: 9),
      LeaderboardEntry(id: '10', name: 'John D.', score: 1300, rank: 10),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Show info about points
            },
            icon: const Icon(CupertinoIcons.info, color: AppTheme.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top 3 Podium (Optional visual flair)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPodiumItem(entries[1], 80, Colors.grey.shade400), // 2nd
                _buildPodiumItem(entries[0], 100, const Color(0xFFFFD700)), // 1st
                _buildPodiumItem(entries[2], 80, const Color(0xFFCD7F32)), // 3rd
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFF2C2C2E)),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: entries.length - 3, // Subtract top 3
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFF2C2C2E),
                indent: 60, // Indent past rank/avatar
              ),
              itemBuilder: (context, index) {
                final entry = entries[index + 3];
                return Container(
                  color: entry.isCurrentUser ? const Color(0xFF1C1C1E) : Colors.transparent,
                  child: ListTile(
                    leading: SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          '${entry.rank}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      entry.name,
                      style: TextStyle(
                        color: entry.isCurrentUser ? AppTheme.primary : Colors.white,
                        fontWeight: entry.isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        fontSize: 17,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.bolt, // Currency icon (Energy/Points)
                          color: AppTheme.warning,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry entry, double size, Color color) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: const Color(0xFF1C1C1E),
          ),
          child: Center(
            child: Text(
              entry.name.substring(0, 1), // Initial
              style: TextStyle(
                color: color,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '#${entry.rank}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          entry.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${entry.score}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.bolt, size: 10, color: AppTheme.warning),
          ],
        ),
      ],
    );
  }
}
