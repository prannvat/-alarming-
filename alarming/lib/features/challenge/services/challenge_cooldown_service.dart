import 'package:hive_flutter/hive_flutter.dart';

/// Service to manage challenge cooldown and point eligibility
class ChallengeCooldownService {
  static const String _boxName = 'challenge_cooldown';
  static const String _lastCompletionKey = 'last_completion';
  static const Duration cooldownPeriod = Duration(hours: 24);
  
  Box? _box;

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  /// Record that a challenge was just completed
  Future<void> recordCompletion() async {
    await init();
    await _box!.put(_lastCompletionKey, DateTime.now().millisecondsSinceEpoch);
    print('🏆 Challenge completion recorded at ${DateTime.now()}');
  }

  /// Get the last challenge completion time
  Future<DateTime?> getLastCompletion() async {
    await init();
    final timestamp = _box!.get(_lastCompletionKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp as int);
  }

  /// Check if challenge cooldown is active
  Future<bool> isCooldownActive() async {
    final lastCompletion = await getLastCompletion();
    if (lastCompletion == null) return false;
    
    final timeSinceCompletion = DateTime.now().difference(lastCompletion);
    return timeSinceCompletion < cooldownPeriod;
  }

  /// Get remaining cooldown time
  Future<Duration?> getRemainingCooldown() async {
    final lastCompletion = await getLastCompletion();
    if (lastCompletion == null) return null;
    
    final timeSinceCompletion = DateTime.now().difference(lastCompletion);
    if (timeSinceCompletion >= cooldownPeriod) return null;
    
    return cooldownPeriod - timeSinceCompletion;
  }

  /// Check if points are available for a challenge
  Future<bool> arePointsAvailable() async {
    return !(await isCooldownActive());
  }

  /// Format remaining cooldown time as string
  Future<String> getRemainingCooldownString() async {
    final remaining = await getRemainingCooldown();
    if (remaining == null) return 'Available now';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
