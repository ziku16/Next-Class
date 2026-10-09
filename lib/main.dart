import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/theme/app_theme.dart';
import 'domain/services/notification_service.dart';
import 'ui/onboarding/splash_screen.dart';

/// Application entry point.
///
/// Ensures immediate UI rendering on cold boot while deferring background service
/// initialization (notifications, native timezone sync, alarm synchronization)
/// asynchronously to prevent startup stalls or crashes.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce system UI overlay style: dark status bar icons and navigation bar icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFDF0),
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize the baseline timezone database for date/time computations.
  try {
    tz.initializeTimeZones();
  } catch (_) {
    // Falls back gracefully to default UTC/system representation if database is absent.
  }

  // Render the application interface immediately to ensure the fastest time-to-first-frame.
  runApp(const NextClassApp());

  // Non-critical background services are initialized asynchronously without blocking the UI.
  _initNonCriticalServices();
}

/// Asynchronously bootstraps platform services (Timezone detection, notifications, alarms).
///
/// Handled defensively with isolated try-catch blocks so a transient failure in one
/// service does not impact core application availability or usability.
Future<void> _initNonCriticalServices() async {
  // 1. Synchronize device timezone via platform channel
  try {
    const channel = MethodChannel('com.nextclass.app/device_info');
    final String? timeZoneName =
        await channel.invokeMethod<String>('getTimeZone');
    if (timeZoneName != null && timeZoneName.isNotEmpty) {
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback: match by current UTC offset if exact Olson ID isn't in tz database
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
        }
      }
    }
  } catch (_) {
    // Native method channel unavailable (e.g. during certain test environments).
  }

  // 2. Initialize notification channels and permissions
  try {
    await NotificationService().initialize();
  } catch (_) {
    // Handled safely; notification service will retry upon user settings interaction.
  }

  // 3. Reschedule upcoming class and quiz reminders against current database
  try {
    await NotificationService().rescheduleAll();
  } catch (_) {
    // Background reminder rescheduling failure does not block user interaction.
  }
}

/// Root Application Widget for NextClass.
/// Strictly locked to Light theme to prevent Android dark mode inversion.
class NextClassApp extends StatelessWidget {
  final Widget? home;

  const NextClassApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextClass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: home ?? const SplashScreen(),
    );
  }
}
