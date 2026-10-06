import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/class_item.dart';
import '../../domain/services/ai_extraction_service.dart';
import '../../domain/services/alarm_scheduler.dart';
import '../../domain/services/connectivity_service.dart';
import '../../state/upload_provider.dart';
import '../main_navigation_screen.dart';
import '../review/review_screen.dart';
import '../shared/offline_banner.dart';
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
      await AlarmScheduler().rescheduleAll();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
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

  Future<void> _startExtraction({
    bool simulateError = false,
    bool simulateEmpty = false,
  }) async {
    // Check quota before extracting
    if (!_provider.quota.canScan()) {
      _showLimitReachedDialog();
      return;
    }

    // Launch full-screen parsing loader
    final result = await Navigator.of(context).push<List<ClassItem>?>(
      MaterialPageRoute(
        builder: (_) => ParsingLoaderScreen(
          uploadProvider: _provider,
          simulateError: simulateError,
          simulateEmpty: simulateEmpty,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      if (widget.onClassesExtracted != null) {
        widget.onClassesExtracted!(result);
      } else {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
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

  void _showLimitReachedDialog() {
    final isDaily = _provider.quota.isDailyLimitReached;
    final message = isDaily
        ? "You've used today's 2 scans. Try again tomorrow, or edit your timetable by hand."
        : "You've used this week's 3 scans. Need help? Contact support.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: const Text(
          'Scan limit reached',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleManualEdit();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: const Text(
              'Edit manually',
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

  void _showExtractionErrorDialog(AiExtractionErrorCode? code, String message) {
    String title = "That didn't work";
    if (code == AiExtractionErrorCode.noInternet) {
      title = 'No internet';
    } else if (code == AiExtractionErrorCode.noClassesFound) {
      title = 'No classes found';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleManualEdit();
            },
            child: const Text(
              'Edit manually',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
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
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: const Text(
              'Try again',
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
      MaterialPageRoute(
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
    final quota = _provider.quota;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
              ),
            ),
          ),
        ),
        title: const Text(
          'Upload timetable',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
            color: Colors.black,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined, size: 18, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.black,
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
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2.5, 2.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.photo_camera_rounded,
                            size: 20,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              quota.quotaLabel,
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Add your timetable',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Take a clear photo of your class timetable. We'll read every class for you.",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black,
                              width: 3.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
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
                                  border: Border.all(color: Colors.black, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(2.5, 2.5),
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
                              const Text(
                                'Take or choose a photo',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  color: Colors.black,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black,
                            width: 3.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
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
                                    border: Border.all(color: Colors.black, width: 2),
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
                                      const Text(
                                        'Photo selected',
                                        style: TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        _provider.selectedImage!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
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
                                      color: const Color(0xFFDCE2E6),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: Colors.black),
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
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(color: Colors.black, width: 2),
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh, size: 18, color: Colors.black),
                                    label: const Text(
                                      'Retake',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(color: Colors.black, width: 2),
                                      ),
                                    ),
                                    icon: const Icon(Icons.image, size: 18, color: Colors.black),
                                    label: const Text(
                                      'Choose another',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(3, 3),
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
                                  border: Border.all(color: Colors.black, width: 1.5),
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
                              const Text(
                                'PHOTO GUIDELINES',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: Colors.black,
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
                            ? const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(3.5, 3.5),
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
                            disabledForegroundColor: Colors.black38,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: (_provider.selectedImage != null && !_isOffline)
                                    ? Colors.black
                                    : Colors.black26,
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
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2.5, 2.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _handleManualEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black),
                          label: const Text(
                            'Add classes manually',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Colors.black, width: 2.5),
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
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black87),
                        label: const Text(
                          'Skip and go to Home',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.black87,
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE500),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: Icon(icon, size: 16, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
