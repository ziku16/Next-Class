import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/class_item.dart';
import '../../state/upload_provider.dart';

/// Fullscreen animated loader with copy cycling every 3 seconds with a 150 ms crossfade.
class ParsingLoaderScreen extends StatefulWidget {
  final UploadProvider uploadProvider;
  final bool autoStartExtraction;

  const ParsingLoaderScreen({
    super.key,
    required this.uploadProvider,
    this.autoStartExtraction = true,
  });

  @override
  State<ParsingLoaderScreen> createState() => _ParsingLoaderScreenState();
}

class _ParsingLoaderScreenState extends State<ParsingLoaderScreen> {
  static const List<String> _rotatingCopy = [
    'PROCESSING TIMETABLE...',
    'PARSING SCHEDULE...',
    'EXTRACTING CLASSES...',
    'ORGANIZING SLOTS...',
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
    final result = await widget.uploadProvider.extractClasses();

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
      backgroundColor: const Color(0xFFFFFDF0),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 300,
            height: 230,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 3.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Monospace brutalist header tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDE59),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 2.0),
                    ),
                    child: const Text(
                      'TIMETABLE PARSER',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bold high-contrast loading indicator
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 4.5,
                      value: disableAnimations ? 0.75 : null,
                      color: const Color(0xFFFF6B00),
                      backgroundColor: const Color(0xFFFFDE59),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Fixed-height rotating status text container (zero layout shift)
                  SizedBox(
                    height: 26,
                    width: double.infinity,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        child: Text(
                          _rotatingCopy[_currentCopyIndex],
                          key: ValueKey<int>(_currentCopyIndex),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Fixed neutral hint text
                  const SizedBox(
                    height: 18,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        'PLEASE WAIT A MOMENT...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF666666),
                          letterSpacing: 0.5,
                        ),
                      ),
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
