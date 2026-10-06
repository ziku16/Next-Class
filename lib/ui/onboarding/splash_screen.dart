import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/timetable_repository.dart';
import '../main_navigation_screen.dart';
import 'welcome_screen.dart';

/// Minimalist splash screen displaying the NextClass Forward Calendar brand icon.
class SplashScreen extends StatefulWidget {
  final Widget? nextDestination;

  const SplashScreen({super.key, this.nextDestination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 1600), () async {
      if (mounted) {
        Widget destination = widget.nextDestination ?? const WelcomeScreen();
        if (widget.nextDestination == null) {
          try {
            final hasClasses = await TimetableRepository().hasClasses();
            bool hasSeenOnboarding = false;
            try {
              final prefs = await SharedPreferences.getInstance().timeout(
                const Duration(milliseconds: 300),
              );
              hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
            } catch (_) {}

            if (hasClasses || hasSeenOnboarding) {
              destination = const MainNavigationScreen();
            }
          } catch (_) {}
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, _, _) => destination,
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Direction A: Forward Calendar Brand Icon with Revo-Brutalist Frame
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE500),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(4.5, 4.5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 54,
                        color: Colors.black,
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5500),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'NextClass',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Never miss a class or a quiz',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Text(
                    'ACADEMIC ASSISTANT',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
