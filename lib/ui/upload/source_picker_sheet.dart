import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/next_class_colors.dart';

/// Modal bottom sheet allowing selection between Camera and Gallery sources.
class SourcePickerSheet extends StatelessWidget {
  const SourcePickerSheet({super.key});

  /// Displays the source picker bottom sheet and returns the selected ImageSource (or null).
  static Future<ImageSource?> show(BuildContext context) {
    final nc = context.ncColors;
    return showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: nc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: nc.border, width: 3.5),
      ),
      builder: (context) => const SourcePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brutalist Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: nc.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add a timetable photo',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: nc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a clear picture or select from your gallery.',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: nc.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Camera Option
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: nc.shadow,
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: nc.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: nc.border, width: 2.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE500),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: nc.border, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Camera',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: nc.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Take a fresh photo',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: nc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: nc.icon),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Gallery Option
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: nc.shadow,
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: nc.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: nc.border, width: 2.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: nc.border, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: nc.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pick one you already have',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: nc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: nc.icon),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
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
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: nc.surface,
                    foregroundColor: nc.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: nc.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
