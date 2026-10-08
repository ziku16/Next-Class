import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';

/// Tactile, heavy-bordered card embodying the Revo-Brutalist aesthetic:
/// - Thick outlines (3px - 3.5px)
/// - Hard-edged offset drop shadows with zero blur
/// - Subtle or minimal corner rounding (4px - 6px)
/// - Optional physical press interaction (0px shadow translation on press)
/// - Optional playful tilt rotation
class BrutalistCard extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;
  final Color? shadowColor;
  final double tiltAngle; // in radians
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool animatePress;

  const BrutalistCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 3.0,
    this.borderRadius = 6.0,
    this.shadowOffset = const Offset(4, 4),
    this.shadowColor,
    this.tiltAngle = 0.0,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.animatePress = true,
  });

  @override
  State<BrutalistCard> createState() => _BrutalistCardState();
}

class _BrutalistCardState extends State<BrutalistCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;
    final effectiveBg = widget.backgroundColor ?? nc.surface;
    final effectiveBorder = widget.borderColor ?? nc.border;
    final effectiveShadow = widget.shadowColor ?? nc.shadow;

    final isInteractive = widget.onTap != null;
    final currentShadow = (_isPressed && widget.animatePress)
        ? Offset.zero
        : widget.shadowOffset;
    final currentTranslation = (_isPressed && widget.animatePress)
        ? widget.shadowOffset
        : Offset.zero;

    Widget cardBody = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        currentTranslation.dx,
        currentTranslation.dy,
        0,
      ),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: effectiveBorder,
          width: widget.borderWidth,
        ),
        boxShadow: currentShadow == Offset.zero
            ? null
            : [
                BoxShadow(
                  color: effectiveShadow,
                  offset: currentShadow,
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (widget.borderRadius - widget.borderWidth).clamp(0.0, 32.0),
        ),
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );

    if (isInteractive) {
      cardBody = GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cardBody,
      );
    }

    if (widget.tiltAngle != 0.0) {
      return Transform.rotate(
        angle: widget.tiltAngle,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
