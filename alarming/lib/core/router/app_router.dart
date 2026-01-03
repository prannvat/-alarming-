import 'package:go_router/go_router.dart';
import '../widgets/main_scaffold.dart';
import '../../features/alarm/view/create_alarm_screen.dart';
import '../../features/challenge/view/math_challenge_screen.dart';
import '../../features/challenge/view/challenge_complete_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(),
    ),
    GoRoute(
      path: '/alarms/create',
      builder: (context, state) => const CreateAlarmScreen(),
    ),
    GoRoute(
      path: '/challenge/math',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MathChallengeScreen(
          difficulty: extra['difficulty'] as String,
          alarmId: extra['alarmId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/challenge/complete',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ChallengeCompleteScreen(
          completionTime: extra['completionTime'] as int,
          points: extra['points'] as int,
          difficulty: extra['difficulty'] as String,
        );
      },
    ),
  ],
);
