import 'dart:math';

/// Service that determines the daily challenge for all users.
/// Everyone gets the same challenge type each day.
class DailyChallengeService {
  static final DailyChallengeService _instance = DailyChallengeService._internal();
  factory DailyChallengeService() => _instance;
  DailyChallengeService._internal();

  // Available challenge types
  static const List<String> challengeTypes = ['math', 'wordle', 'memory'];

  /// Get today's challenge type.
  /// Uses the date as a seed so everyone gets the same challenge.
  String getTodaysChallengeType() {
    final now = DateTime.now();
    // Create a seed based on the date (year + month + day)
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    
    // Pick a challenge type based on the seed
    final index = random.nextInt(challengeTypes.length);
    return challengeTypes[index];
  }

  /// Get the challenge type for a specific date
  String getChallengeTypeForDate(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final random = Random(seed);
    final index = random.nextInt(challengeTypes.length);
    return challengeTypes[index];
  }

  /// Get a human-readable name for the challenge type
  String getChallengeDisplayName(String type) {
    switch (type) {
      case 'math':
        return 'Math Challenge';
      case 'wordle':
        return 'Wordle';
      case 'memory':
        return 'Memory Game';
      default:
        return 'Challenge';
    }
  }

  /// Get the icon for a challenge type
  String getChallengeIcon(String type) {
    switch (type) {
      case 'math':
        return '🧮';
      case 'wordle':
        return '📝';
      case 'memory':
        return '🧠';
      default:
        return '🎯';
    }
  }
}
