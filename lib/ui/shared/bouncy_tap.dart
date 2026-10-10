import 'package:flutter/material.dart';

/// Reusable Framer-Motion-style tactile bouncy interaction wrapper.
/// On tap down, scales down smoothly to [scaleDown] (0.96) over 80ms ([Curves.easeInOut]).
/// On tap up or cancel, springs back to 1.0 over 150ms using a spring curve ([Curves.easeOutBack]).
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration durationDown;
  final Duration durationUp;
  final bool enabled;
  final HitTestBehavior behavior;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.durationDown = const Duration(milliseconds: 80),
    this.durationUp = const Duration(milliseconds: 150),
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.durationDown,
      reverseDuration: widget.durationUp,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _controller.animateTo(
      1.0,
      duration: widget.durationDown,
      curve: Curves.easeInOut,
    );
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    _controller.animateTo(
      0.0,
      duration: widget.durationUp,
      curve: Curves.easeOutBack,
    );
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    _controller.animateTo(
      0.0,
      duration: widget.durationUp,
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      behavior: widget.onTap != null ? widget.behavior : HitTestBehavior.translucent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
