import 'package:flutter/material.dart';

/// Revo-Brutalist checkbox:
/// Chunky square with 3px solid black border and hard shadow.
/// Vivid orange fill with bold solid black checkmark when selected.
class BrutalistCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final Color activeColor;

  const BrutalistCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 28.0,
    this.activeColor = const Color(0xFFFF5500),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.black, width: 3.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: value
            ? const Center(
                child: Icon(
                  Icons.check,
                  size: 20,
                  color: Colors.black,
                  weight: 800,
                ),
              )
            : null,
      ),
    );
  }
}
