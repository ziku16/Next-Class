import 'dart:async';
import 'package:flutter/material.dart';

/// A 6 dp rounded progress bar that automatically advances once a minute
/// representing the elapsed duration of an active class.
class LiveProgressBar extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  final Color? progressColor;
  final Color? backgroundColor;
  final double height;

  const LiveProgressBar({
    super.key,
    required this.startTime,
    required this.endTime,
    this.progressColor,
    this.backgroundColor,
    this.height = 6.0,
  });

  @override
  State<LiveProgressBar> createState() => _LiveProgressBarState();
}

class _LiveProgressBarState extends State<LiveProgressBar> {
  Timer? _timer;
  late double _progress;

  @override
  void initState() {
    super.initState();
    _calculateProgress();
    // Update every minute to advance the live progress bar
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(_calculateProgress);
      }
    });
  }

  void _calculateProgress() {
    final now = DateTime.now();
    final totalDuration = widget.endTime.difference(widget.startTime).inSeconds;
    if (totalDuration <= 0) {
      _progress = 1.0;
      return;
    }

    final elapsed = now.difference(widget.startTime).inSeconds;
    _progress = (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(LiveProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      _calculateProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.progressColor ?? theme.colorScheme.primary;
    final bg = widget.backgroundColor ?? theme.colorScheme.primaryContainer.withValues(alpha: 0.4);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (disableAnimations) {
      return _buildBar(primary, bg, _progress);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _progress, end: _progress),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return _buildBar(primary, bg, value);
      },
    );
  }

  Widget _buildBar(Color primary, Color bg, double value) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * value;
          return Container(
            width: fillWidth,
            height: widget.height,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          );
        },
      ),
    );
  }
}
