import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/onboarding/splash_screen.dart';
import 'ui/onboarding/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
