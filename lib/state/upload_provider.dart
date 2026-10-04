import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/class_item.dart';
import '../data/models/scan_quota.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/services/ai_extraction_service.dart';

/// State management for timetable upload and AI extraction pipeline.
class UploadProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final AiExtractionService _aiExtractionService;

  XFile? _selectedImage;
  ScanQuota _quota = ScanQuota.initial();
  bool _isLoading = false;
  String? _errorMessage;
  AiExtractionErrorCode? _errorCode;
  List<ClassItem>? _extractedClasses;

  UploadProvider({
    SettingsRepository? settingsRepository,
    AiExtractionService? aiExtractionService,
  })  : _settingsRepository = settingsRepository ?? SettingsRepository(),
        _aiExtractionService = aiExtractionService ?? const AiExtractionService() {
    refreshQuota();
  }

  XFile? get selectedImage => _selectedImage;
  String? get selectedImagePath => _selectedImage?.path;
  ScanQuota get quota => _quota;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AiExtractionErrorCode? get errorCode => _errorCode;
  List<ClassItem>? get extractedClasses => _extractedClasses;

  bool get canExtract => _selectedImage != null && _quota.canScan() && !_isLoading;

  /// Refreshes quota from repository
  Future<void> refreshQuota() async {
    _quota = await _settingsRepository.getScanQuota();
    notifyListeners();
  }

  /// Sets chosen image file
  void setSelectedImage(XFile? file) {
    _selectedImage = file;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  /// Clears current image selection
  void clearImage() {
    _selectedImage = null;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  /// Executes AI extraction. Quota is consumed ONLY upon success!
  Future<List<ClassItem>?> extractClasses({
    bool isOnline = true,
    bool simulateError = false,
    bool simulateEmpty = false,
  }) async {
    if (_selectedImage == null) {
      _errorMessage = 'Please select a photo first.';
      notifyListeners();
      return null;
    }

    // Check quota before extracting
    await refreshQuota();
    if (!_quota.canScan()) {
      _errorMessage = _quota.isDailyLimitReached
          ? "You've used today's 2 scans. Try again tomorrow, or edit your timetable by hand."
          : "You've used this week's 3 scans. Need help? Contact support.";
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final classes = await _aiExtractionService.extractClassesFromImage(
        _selectedImage!.path,
        isOnline: isOnline,
        simulateError: simulateError,
        simulateEmpty: simulateEmpty,
      );

      // Consume quota ONLY on success
      _quota = await _settingsRepository.consumeScan();
      _extractedClasses = classes;
      _isLoading = false;
      notifyListeners();
      return classes;
    } on AiExtractionException catch (e) {
      _isLoading = false;
      _errorCode = e.code;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _errorCode = AiExtractionErrorCode.parsingFailed;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
