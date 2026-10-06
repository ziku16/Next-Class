import 'package:flutter/material.dart';

/// Tactile push button with 3px black border, hard offset black drop shadow,
/// and physical press displacement (translates down-right on tap).
class BrutalistButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const BrutalistButton({
    super.key,
    this.child,
    this.text,
    this.icon,
    this.onPressed,
    this.backgroundColor = const Color(0xFFFF5500),
    this.foregroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 3.0,
    this.borderRadius = 6.0,
    this.shadowOffset = const Offset(3.5, 3.5),
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.width,
    this.height,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final currentOffset = (_isPressed && isEnabled) ? Offset.zero : widget.shadowOffset;
    final translation = (_isPressed && isEnabled) ? widget.shadowOffset : Offset.zero;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
        decoration: BoxDecoration(
          color: isEnabled ? widget.backgroundColor : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor,
            width: widget.borderWidth,
          ),
          boxShadow: currentOffset == Offset.zero
              ? null
              : [
                  BoxShadow(
                    color: Colors.black,
                    offset: currentOffset,
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: widget.padding,
        child: Center(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 20,
                color: isEnabled ? widget.foregroundColor : Colors.grey[700],
              ),
              if (widget.text != null || widget.child != null)
                const SizedBox(width: 8),
            ],
            if (widget.text != null)
              Text(
                widget.text!.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isEnabled ? widget.foregroundColor : Colors.grey[700],
                ),
              ),
            if (widget.child != null) widget.child!,
          ],
        ),
      ),
    );
  }
}
