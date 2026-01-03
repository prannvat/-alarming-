import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/alarm_sound_service.dart';
import 'core/services/alarm_manager_service.dart';
import 'core/services/native_alarm_service.dart';
import 'features/alarm/models/alarm_model.dart';
import 'features/alarm/providers/alarm_provider.dart';
import 'features/alarm/view/alarm_dismiss_screen.dart';

// Global navigator key for showing alarm screens
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Adapters
  Hive.registerAdapter(AlarmModelAdapter());

  // Initialize the native alarm package (THIS IS CRITICAL FOR BACKGROUND ALARMS)
  await Alarm.init();
  print('✅ Native Alarm package initialized');

  // Initialize notification service with alarm trigger handler
  await NotificationService().initialize(
    onAlarmTriggered: (alarmId) {
      _handleAlarmTrigger(alarmId);
    },
  );

  // Start alarm monitoring service
  AlarmManagerService().startMonitoring();

  runApp(const ProviderScope(child: AlarmingApp()));
}

void _handleAlarmTrigger(String alarmId) async {
  // This is called when user taps notification
  // The alarm sound should already be playing from AlarmManagerService
  // Just show the appropriate screen
  
  print('🔔 Notification tapped, handling alarm: $alarmId');
  
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) {
    print('❌ No navigator available for notification tap!');
    return;
  }
  
  // Get the alarm from storage
  final repository = AlarmRepository();
  final alarm = await repository.getAlarm(alarmId);
  
  if (alarm != null) {
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AlarmDismissScreen(alarmId: alarmId),
      ),
    );
  }
}

class AlarmingApp extends StatefulWidget {
  const AlarmingApp({super.key});

  @override
  State<AlarmingApp> createState() => _AlarmingAppState();
}

class _AlarmingAppState extends State<AlarmingApp> {
  StreamSubscription? _alarmSubscription;
  StreamSubscription? _nativeAlarmSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen for native alarm rings (from alarm package - works when locked!)
    _nativeAlarmSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
      print('🔔 NATIVE ALARM RINGING: ${alarmSettings.id}');
      _handleNativeAlarmRing(alarmSettings);
    });
    
    // Listen for alarm triggers from the manager service
    _alarmSubscription = AlarmManagerService().onAlarmTrigger.listen((alarm) {
      print('🔔 App received alarm trigger: ${alarm.id}');
      
      // Use a short delay to ensure the app is ready
      Future.delayed(const Duration(milliseconds: 300), () {
        _showAlarmScreen(alarm);
      });
    });
  }

  void _handleNativeAlarmRing(AlarmSettings alarmSettings) async {
    print('🔔 Handling native alarm: ${alarmSettings.id}');
    
    // Find the corresponding alarm model
    final repository = AlarmRepository();
    await repository.init();
    final alarms = await repository.getAlarms();
    
    // Find alarm by matching the ID (first 9 digits)
    AlarmModel? matchingAlarm;
    for (final alarm in alarms) {
      final nativeId = int.parse(alarm.id.substring(0, 9));
      if (nativeId == alarmSettings.id) {
        matchingAlarm = alarm;
        break;
      }
    }
    
    if (matchingAlarm != null) {
      _showAlarmScreen(matchingAlarm);
    } else {
      print('⚠️ Could not find matching alarm for native ID: ${alarmSettings.id}');
    }
  }

  void _showAlarmScreen(AlarmModel alarm) {
    print('🔔 Attempting to show alarm screen for alarm: ${alarm.id}');
    print('🔔 Is challenge alarm: ${alarm.isChallenge}');
    
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      print('❌ No navigator available!');
      return;
    }
    
    print('🔔 Pushing alarm screen route...');
    
    navigator.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return alarm.isChallenge
              ? _getChallengeScreen(alarm)
              : AlarmDismissScreen(alarmId: alarm.id);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    
    print('🔔 ✅ Alarm screen pushed');
  }

  Widget _getChallengeScreen(AlarmModel alarm) {
    // For now, return the dismiss screen with challenge indication
    // TODO: Return actual challenge screen based on daily challenge type
    return AlarmDismissScreen(alarmId: alarm.id);
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _nativeAlarmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Alarming',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Router(
        routerDelegate: appRouter.routerDelegate,
        routeInformationParser: appRouter.routeInformationParser,
        routeInformationProvider: appRouter.routeInformationProvider,
      ),
    );
  }
}
