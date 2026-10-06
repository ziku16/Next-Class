import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Comic-style multi-pointed starburst badge:
/// Used for high-urgency countdowns like "STARTS IN 24 MIN"
/// Features hard drop shadow, bold black outline, and vibrant sticker styling.
class StarburstBadge extends StatelessWidget {
  final String label;
  final String? subLabel;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double size;
  final int points;

  const StarburstBadge({
    super.key,
    required this.label,
    this.subLabel,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.textColor = Colors.black,
    this.size = 84.0,
    this.points = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarburstPainter(
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          points: points,
          shadowOffset: const Offset(3.5, 3.5),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: subLabel != null ? 8.5 : 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: textColor,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final int points;
  final Offset shadowOffset;

  _StarburstPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.points,
    required this.shadowOffset,
  });

  Path _createStarburstPath(Size size, Offset offset) {
    final path = Path();
    final center = Offset(size.width / 2 + offset.dx, size.height / 2 + offset.dy);
    final outerRadius = size.width / 2.15;
    final innerRadius = outerRadius * 0.76;
    final totalSteps = points * 2;
    final stepAngle = (math.pi * 2) / totalSteps;

    for (int i = 0; i < totalSteps; i++) {
      final currentRadius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * stepAngle) - (math.pi / 2);
      final x = center.dx + math.cos(angle) * currentRadius;
      final y = center.dy + math.sin(angle) * currentRadius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw hard shadow path (offset, no blur)
    final shadowPath = _createStarburstPath(size, shadowOffset);
    final shadowPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Draw starburst fill
    final mainPath = _createStarburstPath(size, Offset.zero);
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(mainPath, fillPaint);

    // 3. Draw bold outline
    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(mainPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor ||
      borderColor != oldDelegate.borderColor ||
      points != oldDelegate.points;
}
