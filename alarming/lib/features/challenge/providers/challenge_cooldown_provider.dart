import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/challenge_cooldown_service.dart';

final challengeCooldownServiceProvider = Provider<ChallengeCooldownService>((ref) {
  return ChallengeCooldownService();
});

/// Provider to check if challenge points are currently available
final challengePointsAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(challengeCooldownServiceProvider);
  return await service.arePointsAvailable();
});

/// Provider to get remaining cooldown time as formatted string
final challengeCooldownStringProvider = FutureProvider<String>((ref) async {
  final service = ref.read(challengeCooldownServiceProvider);
  return await service.getRemainingCooldownString();
});
