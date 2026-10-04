import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/class_item.dart';
import '../../domain/services/ai_extraction_service.dart';
import '../../state/upload_provider.dart';
import '../review/review_screen.dart';
import 'parsing_loader_screen.dart';
import 'source_picker_sheet.dart';

/// Screen where user selects/takes a timetable photo, checks scan quota, and triggers AI extraction.
class UploadScreen extends StatefulWidget {
  final UploadProvider? uploadProvider;
  final ValueChanged<List<ClassItem>>? onClassesExtracted;
  final VoidCallback? onManualEdit;

  const UploadScreen({
    super.key,
    this.uploadProvider,
    this.onClassesExtracted,
    this.onManualEdit,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final UploadProvider _provider;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _provider = widget.uploadProvider ?? UploadProvider();
    _provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReviewScreen(initialClasses: result),
          ),
        );
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
        title: const Text('Scan limit reached'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleManualEdit();
            },
            child: const Text('Edit manually'),
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleManualEdit();
            },
            child: const Text('Edit manually'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startExtraction();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  void _handleManualEdit() {
    if (widget.onManualEdit != null) {
      widget.onManualEdit!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReviewScreen(initialClasses: []),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quota = _provider.quota;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Upload timetable'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quota Banner Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quota.quotaLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Add your timetable',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Take a clear photo of your class timetable. We'll read every class for you.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Image Selection Area
              if (_provider.selectedImage == null) ...[
                // Empty Picker Box
                InkWell(
                  onTap: _openSourcePicker,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 28,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Take or choose a photo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
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
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Photo selected',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _provider.selectedImage!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _provider.clearImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retake'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.image, size: 18),
                              label: const Text('Choose another'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Guidelines Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildGuidelineRow(
                      context,
                      icon: Icons.light_mode_outlined,
                      text: 'Good light, no shadows',
                    ),
                    const SizedBox(height: 12),
                    _buildGuidelineRow(
                      context,
                      icon: Icons.crop_free_rounded,
                      text: 'Fit the whole table in the frame',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Primary Action: Extract classes
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _provider.selectedImage != null
                      ? () => _startExtraction()
                      : null,
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Extract classes'),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Fallback: Add classes manually
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _handleManualEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Add classes manually'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
