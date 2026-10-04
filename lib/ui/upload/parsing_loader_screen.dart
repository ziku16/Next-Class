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
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Calm glowing / pulsing circular indicator
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 36),

                // Rotating Copy with 150 ms crossfade
                AnimatedSwitcher(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  child: Text(
                    _rotatingCopy[_currentCopyIndex],
                    key: ValueKey<int>(_currentCopyIndex),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'Usually 5 to 15 seconds',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
