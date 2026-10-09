import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/notification_service.dart';
import '../../state/upload_provider.dart';
import '../main_navigation_screen.dart';
import '../review/review_screen.dart';
import '../shared/offline_banner.dart';
import '../shared/fluid_page_route.dart';
import 'parsing_loader_screen.dart';
import 'source_picker_sheet.dart';

/// Screen where user selects/takes a timetable photo, checks scan quota, and triggers AI extraction.
class UploadScreen extends StatefulWidget {
  final UploadProvider? uploadProvider;
  final ValueChanged<List<ClassItem>>? onClassesExtracted;
  final VoidCallback? onManualEdit;
  final bool? isOffline;

  const UploadScreen({
    super.key,
    this.uploadProvider,
    this.onClassesExtracted,
    this.onManualEdit,
    this.isOffline,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final UploadProvider _provider;
  final ImagePicker _picker = ImagePicker();
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _provider = widget.uploadProvider ?? UploadProvider();
    _provider.addListener(_onProviderUpdate);

    _isOffline = widget.isOffline ?? ConnectivityService().isOffline;
    if (widget.isOffline == null) {
      _connectivitySubscription =
          ConnectivityService().onConnectivityChanged.listen((offline) {
        if (mounted) setState(() => _isOffline = offline);
      });
    }
  }

  @override
  void didUpdateWidget(covariant UploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOffline != oldWidget.isOffline && widget.isOffline != null) {
      _isOffline = widget.isOffline!;
    }
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _navigateToHome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
      await NotificationService().rescheduleAll();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      FluidPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        _provider.setSelectedImage(picked);
      }
    } catch (_) {
      // Permission or hardware error
    }
  }

  Future<void> _openSourcePicker() async {
    final source = await SourcePickerSheet.show(context);
    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _startExtraction() async {
    // Launch full-screen parsing loader
    final result = await Navigator.of(context).push<List<ClassItem>?>(
      FluidPageRoute(
        builder: (_) => ParsingLoaderScreen(
          uploadProvider: _provider,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      if (widget.onClassesExtracted != null) {
        widget.onClassesExtracted!(result);
      } else {
        final saved = await Navigator.of(context).push<bool>(
          FluidPageRoute(
            builder: (_) => ReviewScreen(
              initialClasses: result,
              onSaved: _navigateToHome,
            ),
          ),
        );
        if (saved == true && mounted) {
          _navigateToHome();
        }
      }
    } else if (_provider.errorMessage != null) {
      _showExtractionErrorDialog(_provider.errorCode, _provider.errorMessage!);
    }
  }

  void _showExtractionErrorDialog(TimetableScanErrorCode? code, String message) {
    final title = switch (code) {
      TimetableScanErrorCode.rateLimitExceeded => "WEEKLY LIMIT REACHED",
      TimetableScanErrorCode.parserFormatError => "FORMAT ERROR",
      TimetableScanErrorCode.emptyResult => "NO CLASSES FOUND",
      _ => "CONNECTION ERROR",
    };

    final contentText = switch (code) {
      TimetableScanErrorCode.rateLimitExceeded =>
        "Weekly limit reached (2 scans max per week).",
      TimetableScanErrorCode.parserFormatError =>
        "Could not parse timetable format. Please try again.",
      TimetableScanErrorCode.emptyResult =>
        "No classes could be identified from this image. Please ensure your photo is clear and legible.",
      _ =>
        "Request timed out or connection lost. Please check your internet.",
    };

    final isRateLimit = code == TimetableScanErrorCode.rateLimitExceeded;
    final nc = context.ncColors;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: nc.border, width: 3.5),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            color: nc.textPrimary,
          ),
        ),
        content: Text(
          contentText,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w600,
            color: nc.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleManualEdit();
            },
            child: Text(
              'Enter Classes Manually',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w800,
                color: nc.textPrimary,
              ),
            ),
          ),
          if (!isRateLimit)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startExtraction();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: nc.border, width: 2),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleManualEdit() async {
    if (widget.onManualEdit != null) {
      widget.onManualEdit!();
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      FluidPageRoute(
        builder: (_) => ReviewScreen(
          initialClasses: const [],
          onSaved: _navigateToHome,
        ),
      ),
    );
    if (saved == true && mounted) {
      _navigateToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _navigateToHome();
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: nc.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, size: 20, color: nc.icon),
              ),
            ),
          ),
        ),
        title: Text(
          'Upload timetable',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
            color: nc.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _navigateToHome,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: nc.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined, size: 18, color: nc.icon),
                    const SizedBox(width: 4),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: nc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner below status bar
            OfflineBanner(isOffline: _isOffline),

            // Scrollable Upload Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quota Banner Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE500),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: nc.border, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: nc.shadow,
                            offset: const Offset(2.5, 2.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: Colors.black,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI-POWERED TIMETABLE SCANNER',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Add your timetable',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: nc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Take a clear photo of your class timetable. We'll read every class for you.",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: nc.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image Selection Area
                    if (_provider.selectedImage == null) ...[
                      // Empty Picker Box
                      InkWell(
                        onTap: _openSourcePicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          decoration: BoxDecoration(
                            color: nc.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: nc.border,
                              width: 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: nc.shadow,
                                offset: const Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5500),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: nc.border, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: nc.shadow,
                                      offset: const Offset(2.5, 2.5),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Take or choose a photo',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  color: nc.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Selected Image Preview Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: nc.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: nc.border,
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: nc.shadow,
                              offset: const Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: nc.border, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Photo selected',
                                        style: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: nc.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _provider.selectedImage!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: nc.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _provider.clearImage,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: nc.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: nc.border, width: 2),
                                    ),
                                    child: Icon(Icons.close, size: 18, color: nc.icon),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: nc.surface,
                                      foregroundColor: nc.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: nc.border, width: 2),
                                      ),
                                    ),
                                    icon: Icon(Icons.refresh, size: 18, color: nc.icon),
                                    label: Text(
                                      'Retake',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w800,
                                        color: nc.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: nc.surface,
                                      foregroundColor: nc.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(color: nc.border, width: 2),
                                      ),
                                    ),
                                    icon: Icon(Icons.image, size: 18, color: nc.icon),
                                    label: Text(
                                      'Choose another',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w800,
                                        color: nc.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Guidelines Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: nc.border, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: nc.shadow,
                            offset: const Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: nc.border, width: 1.5),
                                ),
                                child: const Text(
                                  'TIPS',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PHOTO GUIDELINES',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: nc.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildGuidelineRow(
                            context,
                            icon: Icons.light_mode_outlined,
                            text: 'Good light, no shadows',
                          ),
                          const SizedBox(height: 10),
                          _buildGuidelineRow(
                            context,
                            icon: Icons.crop_free_rounded,
                            text: 'Fit the whole table in the frame',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Primary Action: Extract classes
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: (_provider.selectedImage != null && !_isOffline)
                            ? [
                                BoxShadow(
                                  color: nc.shadow,
                                  offset: const Offset(3.5, 3.5),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: (_provider.selectedImage != null && !_isOffline)
                              ? () => _startExtraction()
                              : null,
                          icon: const Icon(Icons.auto_awesome, size: 20),
                          label: Text(
                            _isOffline
                                ? 'Offline — Extraction unavailable'
                                : 'Extract classes',
                            style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5500),
                            disabledBackgroundColor: const Color(0xFFDCE2E6),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: nc.textSecondary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: (_provider.selectedImage != null && !_isOffline)
                                    ? nc.border
                                    : nc.border.withValues(alpha: 0.3),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Secondary Fallback: Add classes manually
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
                        child: OutlinedButton.icon(
                          onPressed: _handleManualEdit,
                          icon: Icon(Icons.edit_outlined, size: 18, color: nc.icon),
                          label: Text(
                            'Add classes manually',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: nc.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: nc.surface,
                            foregroundColor: nc.textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: nc.border, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tertiary: Skip to Home
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _navigateToHome,
                        icon: Icon(Icons.arrow_forward_rounded, size: 18, color: nc.textSecondary),
                        label: Text(
                          'Skip and go to Home',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: nc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final nc = context.ncColors;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: nc.border, width: 1.5),
          ),
          child: Icon(icon, size: 16, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: nc.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
