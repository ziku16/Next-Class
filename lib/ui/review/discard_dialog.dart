import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';

/// Confirmation dialog shown when the user attempts to leave the review screen with unsaved edits.
class DiscardDialog extends StatelessWidget {
  const DiscardDialog({super.key});

  /// Shows the discard confirmation dialog and returns true if user confirmed discarding edits.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const DiscardDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;

    return AlertDialog(
      backgroundColor: nc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: nc.border, width: 3.5),
      ),
      title: Text(
        'Discard changes?',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: nc.textPrimary,
        ),
      ),
      content: Text(
        "You've edited your classes but haven't saved. If you leave now, those changes will be lost.",
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: nc.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep editing',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w900,
              color: nc.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: nc.shadow,
                offset: const Offset(2.5, 2.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: nc.border, width: 2.0),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
