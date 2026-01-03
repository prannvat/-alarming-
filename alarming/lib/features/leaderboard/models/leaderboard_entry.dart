class LeaderboardEntry {
  final String id;
  final String name;
  final int score;
  final int rank;
  final String avatarUrl; // In a real app, this would be a URL
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.id,
    required this.name,
    required this.score,
    required this.rank,
    this.avatarUrl = '',
    this.isCurrentUser = false,
  });
}
