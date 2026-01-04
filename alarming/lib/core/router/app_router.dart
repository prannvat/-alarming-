import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_scaffold.dart';
import '../../features/alarm/view/create_alarm_screen.dart';
import '../../features/alarm/view/alarms_screen.dart';
import '../../features/timer/view/timer_screen.dart';
import '../../features/challenge/view/math_challenge_screen.dart';
import '../../features/challenge/view/challenge_complete_screen.dart';
import '../../features/debug/view/debug_menu_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(),
    ),
    GoRoute(
      path: '/debug',
      builder: (context, state) => const DebugMenuScreen(),
    ),
    GoRoute(
      path: '/alarms',
      builder: (context, state) => const AlarmsScreen(),
    ),
    GoRoute(
      path: '/alarms/create',
      builder: (context, state) => const CreateAlarmScreen(),
    ),
    GoRoute(
      path: '/timer',
      builder: (context, state) => const TimerScreen(),
    ),
    GoRoute(
      path: '/timer/:timerId',
      builder: (context, state) {
        final timerId = state.pathParameters['timerId'];
        return TimerScreen(timerId: timerId);
      },
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
