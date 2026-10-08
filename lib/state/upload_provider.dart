import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/class_item.dart';
import '../data/models/scan_quota.dart';
import '../data/repositories/settings_repository.dart';
import '../services/timetable_parser_service.dart';

enum TimetableScanErrorCode {
  rateLimitExceeded,
  networkError,
  serverError,
  emptyResult,
}

/// State management for timetable upload and Cloudflare AI Vision parsing pipeline.
class UploadProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  XFile? _selectedImage;
  ScanQuota _quota = ScanQuota.initial();
  bool _isLoading = false;
  String? _errorMessage;
  TimetableScanErrorCode? _errorCode;
  List<ClassItem>? _extractedClasses;

  UploadProvider({
    SettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? SettingsRepository() {
    refreshQuota();
  }

  XFile? get selectedImage => _selectedImage;
  String? get selectedImagePath => _selectedImage?.path;
  ScanQuota get quota => _quota;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TimetableScanErrorCode? get errorCode => _errorCode;
  List<ClassItem>? get extractedClasses => _extractedClasses;

  bool get canExtract => _selectedImage != null && !_isLoading;

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

  /// Executes Cloudflare AI Vision timetable parsing.
  Future<List<ClassItem>?> extractClasses() async {
    if (_selectedImage == null) {
      _errorMessage = 'Please select a photo first.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final rawJson = await TimetableParserService.parseTimetable(File(_selectedImage!.path));
      final classes = TimetableParserService.jsonToClassItems(rawJson);

      if (classes.isEmpty) {
        _isLoading = false;
        _errorCode = TimetableScanErrorCode.emptyResult;
        _errorMessage = "No classes could be identified from this image. Please ensure your photo is clear and legible.";
        notifyListeners();
        return null;
      }

      // Consume quota ONLY on success
      _quota = await _settingsRepository.consumeScan();
      _extractedClasses = classes;
      _isLoading = false;
      notifyListeners();
      return classes;
    } catch (e) {
      _isLoading = false;
      final errStr = e.toString();
      if (errStr.contains('RATE_LIMIT_EXCEEDED')) {
        _errorCode = TimetableScanErrorCode.rateLimitExceeded;
        _errorMessage = 'Weekly scan limit reached (2 scans/week). Please enter classes manually.';
      } else if (errStr.contains('SERVER_ERROR')) {
        _errorCode = TimetableScanErrorCode.serverError;
        _errorMessage = 'The timetable parser encountered a server error. Please try again.';
      } else {
        _errorCode = TimetableScanErrorCode.networkError;
        _errorMessage = 'Unable to reach Cloudflare AI parser. Please check your internet connection.';
      }
      notifyListeners();
      return null;
    }
  }
}
