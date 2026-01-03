import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/alarm_provider.dart';
import '../models/alarm_model.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: TextButton(
          onPressed: () {
            // TODO: Implement Edit Mode
          },
          child: const Text(
            'Edit',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 17,
            ),
          ),
        ),
        title: const Text(
          'Alarm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/alarms/create');
            },
            icon: const Icon(Icons.add, color: AppTheme.primary),
          ),
        ],
      ),
      body: alarmsAsync.when(
        data: (alarms) {
          if (alarms.isEmpty) {
            return _buildEmptyState(context);
          }

          // Sort by next trigger time
          alarms.sort((a, b) {
            final aTime = a.nextTriggerTime;
            final bTime = b.nextTriggerTime;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return aTime.compareTo(bTime);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  'Alarm',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: alarms.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: Color(0xFF2C2C2E),
                    indent: 16,
                  ),
                  itemBuilder: (context, index) {
                    return _buildAlarmItem(context, ref, alarms[index]);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No Alarms',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmItem(BuildContext context, WidgetRef ref, AlarmModel alarm) {
    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text(
          'Delete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      onDismissed: (direction) {
        ref.read(alarmRepositoryProvider).deleteAlarm(alarm.id);
      },
      child: InkWell(
        onTap: () {
          _showTestDialog(context, alarm);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          alarm.timeString,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 60,
                            fontWeight: FontWeight.w200,
                            color: alarm.isEnabled
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (alarm.hour < 12) ...[
                          const SizedBox(width: 4),
                          Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 20,
                              color: alarm.isEnabled ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          Text(
                            'PM',
                            style: TextStyle(
                              fontSize: 20,
                              color: alarm.isEnabled ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      alarm.label.isEmpty ? 'Alarm' : alarm.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: alarm.isEnabled ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    if (alarm.isChallenge)
                      Text(
                        '${alarm.challengeType?.toUpperCase()} Challenge',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: alarm.isEnabled,
                onChanged: (value) {
                  final repository = ref.read(alarmRepositoryProvider);
                  repository.updateAlarm(alarm.copyWith(isEnabled: value));
                },
                activeColor: AppTheme.secondary,
                activeTrackColor: AppTheme.secondary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFF39393D),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTestDialog(BuildContext context, AlarmModel alarm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          alarm.isChallenge ? 'Test Challenge?' : 'Test Alarm?', 
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          alarm.isChallenge 
            ? 'Launch the ${alarm.challengeType} challenge now for testing?' 
            : 'This alarm doesn\'t have a challenge. Want to test a challenge anyway?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/challenge/math', extra: {
                'difficulty': alarm.difficulty ?? 'medium',
                'alarmId': alarm.id,
              });
            },
            child: const Text('Test Now!', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}
