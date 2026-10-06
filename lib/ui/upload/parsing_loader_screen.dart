import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/class_item.dart';
import '../../state/upload_provider.dart';

/// Fullscreen animated loader with copy cycling every 3 seconds with a 150 ms crossfade.
class ParsingLoaderScreen extends StatefulWidget {
  final UploadProvider uploadProvider;
  final bool simulateError;
  final bool simulateEmpty;
  final bool autoStartExtraction;

  const ParsingLoaderScreen({
    super.key,
    required this.uploadProvider,
    this.simulateError = false,
    this.simulateEmpty = false,
    this.autoStartExtraction = true,
  });

  @override
  State<ParsingLoaderScreen> createState() => _ParsingLoaderScreenState();
}

class _ParsingLoaderScreenState extends State<ParsingLoaderScreen> {
  static const List<String> _rotatingCopy = [
    'Reading your timetable…',
    'Finding your classes…',
    'Almost there!',
  ];

  int _currentCopyIndex = 0;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _startCopyRotation();
    if (widget.autoStartExtraction) {
      _performExtraction();
    }
  }

  void _startCopyRotation() {
    _copyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _currentCopyIndex = (_currentCopyIndex + 1) % _rotatingCopy.length;
        });
      }
    });
  }

  Future<void> _performExtraction() async {
    final result = await widget.uploadProvider.extractClasses(
      simulateError: widget.simulateError,
      simulateEmpty: widget.simulateEmpty,
    );

    if (!mounted) return;

    // Pop and return extraction result or null on failure
    Navigator.of(context).pop<List<ClassItem>?>(result);
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 3.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4.5, 4.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brutalist status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE500),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      'AI OCR SCANNER',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // High-energy circular progress indicator
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      strokeWidth: 5.0,
                      value: disableAnimations ? 0.75 : null,
                      color: const Color(0xFFFF5500),
                      backgroundColor: const Color(0xFFFFE500),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Rotating Copy with 150 ms crossfade
                  AnimatedSwitcher(
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: Text(
                      _rotatingCopy[_currentCopyIndex],
                      key: ValueKey<int>(_currentCopyIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Usually 5 to 15 seconds',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
