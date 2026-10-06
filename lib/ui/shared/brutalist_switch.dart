import 'package:flutter/material.dart';

/// Revo-Brutalist toggle switch:
/// Heavy white capsule track with 3px solid black border.
/// Saturated orange circular thumb with 3px solid black border.
class BrutalistSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color activeThumbColor;
  final Color inactiveThumbColor;

  const BrutalistSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor = Colors.white,
    this.inactiveTrackColor = const Color(0xFFEBEBEB),
    this.activeThumbColor = const Color(0xFFFF5500), // Vivid orange
    this.inactiveThumbColor = const Color(0xFF9E9E9E), // Inactive grey
  });

  @override
  Widget build(BuildContext context) {
    const trackWidth = 58.0;
    const trackHeight = 32.0;
    const thumbSize = 24.0;
    const padding = 2.0;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: trackWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          color: value ? activeTrackColor : inactiveTrackColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 3.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(padding),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: thumbSize,
          height: thumbSize,
          decoration: BoxDecoration(
            color: value ? activeThumbColor : inactiveThumbColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2.5),
          ),
        ),
      ),
    );
  }
}
