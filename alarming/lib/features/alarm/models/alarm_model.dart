import 'package:hive/hive.dart';

part 'alarm_model.g.dart';

@HiveType(typeId: 0)
class AlarmModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int hour;

  @HiveField(2)
  int minute;

  @HiveField(3)
  bool isEnabled;

  @HiveField(4)
  String label;

  @HiveField(5)
  List<bool> repeatDays; // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]

  @HiveField(6)
  bool isChallenge;

  @HiveField(7)
  String? challengeType; // 'math', 'wordle', 'memory', etc.

  @HiveField(8)
  String? difficulty; // 'easy', 'medium', 'hard'

  @HiveField(9)
  bool vibrationEnabled;

  @HiveField(10)
  String? soundPath;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime? specificDate;

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    this.label = '',
    List<bool>? repeatDays,
    this.isChallenge = false,
    this.challengeType,
    this.difficulty = 'medium',
    this.vibrationEnabled = true,
    this.soundPath,
    DateTime? createdAt,
    this.specificDate,
  })  : repeatDays = repeatDays ?? List.filled(7, false),
        createdAt = createdAt ?? DateTime.now();

  String get timeString {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  String get repeatString {
    if (repeatDays.every((day) => !day)) return 'Once';
    if (repeatDays.every((day) => day)) return 'Every day';
    
    final weekdays = repeatDays.sublist(0, 5).every((day) => day);
    final weekend = repeatDays.sublist(5, 7).every((day) => !day);
    if (weekdays && weekend) return 'Weekdays';

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
      if (repeatDays[i]) activeDays.add(dayNames[i]);
    }
    return activeDays.join(', ');
  }

  DateTime? get nextTriggerTime {
    final now = DateTime.now();

    // If specific date is set, use it
    if (specificDate != null) {
      final trigger = DateTime(
        specificDate!.year,
        specificDate!.month,
        specificDate!.day,
        hour,
        minute,
      );
      
      // If the specific date/time is in the past, it won't trigger
      if (trigger.isBefore(now)) {
        return null; 
      }
      return trigger;
    }

    var next = DateTime(now.year, now.month, now.day, hour, minute);

    if (repeatDays.every((day) => !day)) {
      // One-time alarm
      if (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    }

    // Repeating alarm
    for (int i = 0; i < 7; i++) {
      final checkDay = next.add(Duration(days: i));
      final weekday = checkDay.weekday - 1; // Monday = 0
      
      if (repeatDays[weekday] && checkDay.isAfter(now)) {
        return checkDay;
      }
    }

    return null;
  }

  AlarmModel copyWith({
    String? id,
    int? hour,
    int? minute,
    bool? isEnabled,
    String? label,
    List<bool>? repeatDays,
    bool? isChallenge,
    String? challengeType,
    String? difficulty,
    bool? vibrationEnabled,
    String? soundPath,
    DateTime? specificDate,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      isChallenge: isChallenge ?? this.isChallenge,
      challengeType: challengeType ?? this.challengeType,
      difficulty: difficulty ?? this.difficulty,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundPath: soundPath ?? this.soundPath,
      createdAt: createdAt,
      specificDate: specificDate ?? this.specificDate,
    );
  }
}
