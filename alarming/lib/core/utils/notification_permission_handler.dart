import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationPermissionHandler {
  static bool _hasRequestedPermission = false;

  static Future<bool> ensurePermissions(BuildContext context) async {
    final service = NotificationService();
    
    // Try to request permissions
    final granted = await service.requestPermissions();
    
    if (!granted && !_hasRequestedPermission) {
      _hasRequestedPermission = true;
      
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              'Enable Notifications',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: const Text(
              'To use alarm features, please enable notifications in your device settings:\n\n'
              'Settings → Alarming → Notifications → Allow Notifications',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      }
    }
    
    return granted;
  }
}
