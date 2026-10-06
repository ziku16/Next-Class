import 'package:flutter/material.dart';

/// Industrial technical stamp badge (e.g. "OCT0221 / CLASSIFY", "4 CLASSES TODAY")
class IndustrialStamp extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final bool hasBorder;
  final EdgeInsetsGeometry padding;

  const IndustrialStamp({
    super.key,
    required this.text,
    this.backgroundColor = Colors.transparent,
    this.borderColor = Colors.black,
    this.textColor = Colors.black,
    this.hasBorder = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(3),
        border: hasBorder ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Sticker Status Pill badge for class cards (e.g. "• LIVE", "ACTIVE", "UPCOMING", "LATER", "COMPLETED")
class StatusPillBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool isLive;

  const StatusPillBadge({
    super.key,
    required this.label,
    this.backgroundColor = const Color(0xFFFFE500),
    this.textColor = Colors.black,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFFF1744),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: textColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
