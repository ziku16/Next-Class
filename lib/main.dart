import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/theme/app_theme.dart';
import 'domain/services/alarm_scheduler.dart';
import 'domain/services/notification_service.dart';
import 'ui/onboarding/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize timezone database
  tz.initializeTimeZones();

  // 2. Set tz.local via native Android MethodChannel
  try {
    const channel = MethodChannel('com.nextclass.app/device_info');
    final String? timeZoneName =
        await channel.invokeMethod<String>('getTimeZone');
    if (timeZoneName != null && timeZoneName.isNotEmpty) {
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[main] Timezone initialized to: ${tz.local.name} ($timeZoneName)');
      } catch (tzErr) {
        debugPrint('[main] Location not found for $timeZoneName ($tzErr). Attempting offset match...');
        final offset = DateTime.now().timeZoneOffset;
        tz.Location? matched;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset.inMilliseconds) {
            matched = loc;
            break;
          }
        }
        if (matched != null) {
          tz.setLocalLocation(matched);
          debugPrint('[main] Fallback matched timezone: ${tz.local.name} (offset ${offset.inHours}h)');
        }
      }
    } else {
      debugPrint(
        '[main] WARNING: Native getTimeZone returned null or empty. Fallback tz: ${tz.local.name}',
      );
    }
  } catch (e, stack) {
    debugPrint('[main] CRITICAL: Failed to get/set native timezone: $e\n$stack');
  }

  // 3. Initialize notifications plugin & create notification channels
  try {
    await NotificationService().initialize();
  } catch (e, stack) {
    debugPrint('[main] CRITICAL: Failed to initialize NotificationService: $e\n$stack');
  }

  // 4. ONLY THEN reschedule alarms from database
  try {
    await AlarmScheduler().rescheduleAll();
  } catch (e, stack) {
    debugPrint('[main] CRITICAL: Failed to reschedule alarms at startup: $e\n$stack');
  }

  runApp(const NextClassApp());
}

/// Root Application Widget for NextClass.
class NextClassApp extends StatelessWidget {
  final Widget? home;

  const NextClassApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextClass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: home ?? const SplashScreen(),
    );
  }
}
