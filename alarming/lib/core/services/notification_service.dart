import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/alarm/models/alarm_model.dart';
import 'alarm_manager_service.dart';
import 'alarm_sound_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Function(String alarmId)? onAlarmTriggered;

  // Notification category identifiers for iOS
  static const String _alarmCategoryId = 'alarm_category';
  static const String _challengeAlarmCategoryId = 'challenge_alarm_category';

  Future<void> initialize({Function(String alarmId)? onAlarmTriggered}) async {
    if (_initialized) return;

    this.onAlarmTriggered = onAlarmTriggered;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings with notification categories for actions
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        // Category for regular alarms (with dismiss/snooze actions)
        DarwinNotificationCategory(
          _alarmCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              'dismiss',
              'Dismiss',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'snooze',
              'Snooze 5 min',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
        // Category for challenge alarms (only open action - must complete challenge)
        DarwinNotificationCategory(
          _challengeAlarmCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              'open_challenge',
              'Complete Challenge',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
    int id = 999,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      id,
      title,
      body,
      details,
    );
  }

  Future<bool> requestPermissions() async {
    // Request iOS notification permissions
    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImpl != null) {
      final result = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
      return result ?? false;
    }

    // For Android
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      final result = await androidImpl.requestNotificationsPermission();
      return result ?? false;
    }

    return true;
  }

  Future<void> scheduleAlarm(AlarmModel alarm) async {
    await initialize();
    
    // Try to request permissions
    await requestPermissions();

    // Cancel existing notification for this alarm
    await cancelAlarm(alarm.id);

    final nextTrigger = alarm.nextTriggerTime;
    if (nextTrigger == null) return;

    try {
      final scheduledDate = tz.TZDateTime.from(nextTrigger, tz.local);

    // For non-challenge alarms, add action buttons
    final List<AndroidNotificationAction> androidActions = alarm.isChallenge
        ? []
        : [
            const AndroidNotificationAction(
              'dismiss',
              'Dismiss',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'snooze',
              'Snooze 5 min',
              showsUserInterface: false,
            ),
          ];

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarms',
      channelDescription: 'Alarm notifications',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      actions: androidActions,
    );

    // iOS notification with category for long-press actions
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm_sound.mp3',
      interruptionLevel: InterruptionLevel.critical,
      // Use the appropriate category based on alarm type
      categoryIdentifier: alarm.isChallenge 
          ? _challengeAlarmCategoryId 
          : _alarmCategoryId,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    final body = alarm.isChallenge
        ? 'Complete today\'s challenge to dismiss'
        : 'Long-press for options';

    await _notifications.zonedSchedule(
      int.parse(alarm.id.substring(0, 9)), // Use first 9 digits as notification ID
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: alarm.repeatDays.any((day) => day)
          ? DateTimeComponents.time
          : DateTimeComponents.dateAndTime,
      payload: '${alarm.id}|${alarm.isChallenge}', // Include challenge info in payload
    );
    print('🔔 Notification scheduled successfully');
    } catch (e) {
      print('Failed to schedule alarm notification: $e');
      // Don't throw - allow alarm to be saved even if notification fails
    }
  }

  Future<void> cancelAlarm(String alarmId) async {
    await initialize();
    final notificationId = int.parse(alarmId.substring(0, 9));
    await _notifications.cancel(notificationId);
  }

  Future<void> cancelAllAlarms() async {
    await initialize();
    await _notifications.cancelAll();
  }

  void _onNotificationTap(NotificationResponse response) {
    print('🔔 Notification response received');
    print('🔔 Action ID: ${response.actionId}');
    print('🔔 Payload: ${response.payload}');
    
    final actionId = response.actionId;
    final payload = response.payload;
    
    if (payload == null) return;
    
    // Start playing alarm sound IMMEDIATELY when notification is tapped
    // This ensures sound plays even if app was in background
    AlarmSoundService().playAlarm();
    
    // Handle different actions
    switch (actionId) {
      case 'dismiss':
        // User pressed dismiss from notification
        print('🔔 User dismissed alarm from notification');
        AlarmManagerService().dismissCurrentAlarm();
        break;
        
      case 'snooze':
        // User pressed snooze from notification
        print('🔔 User snoozed alarm from notification');
        AlarmManagerService().dismissCurrentAlarm();
        // TODO: Schedule snooze alarm for 5 minutes
        break;
        
      case 'open_challenge':
      default:
        // User tapped notification or pressed "Complete Challenge"
        // Open the app and show the appropriate screen
        if (onAlarmTriggered != null) {
          onAlarmTriggered!(payload);
        }
        break;
    }
  }
}
