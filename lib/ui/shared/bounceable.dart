import 'package:flutter/material.dart';
import 'bouncy_tap.dart';

export 'bouncy_tap.dart';

/// Framer-Motion-style micro-interaction widget.
/// Backwards-compatible wrapper delegating to [BouncyTap].
class Bounceable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const Bounceable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 80),
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scaleDown: scaleFactor,
      durationDown: duration,
      durationUp: const Duration(milliseconds: 150),
      child: child,
    );
  }
}
