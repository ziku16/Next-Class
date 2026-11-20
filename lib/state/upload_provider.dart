import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/class_item.dart';
import '../data/models/scan_quota.dart';
import '../data/repositories/settings_repository.dart';
import '../services/timetable_parser_service.dart';

enum TimetableScanErrorCode {
  rateLimitExceeded,
  configuration,
  authentication,
  modelUnavailable,
  apiQuotaExceeded,
  invalidRequest,
  parserFormatError,
  networkError,
  timeout,
  unreadableImage,
  serverError,
  emptyResult,
}

typedef TimetableExtractor = Future<Map<String, dynamic>> Function(
  File imageFile,
);

/// State management for timetable upload and Gemini Generative AI parsing pipeline.
class UploadProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final TimetableExtractor _timetableExtractor;

  XFile? _selectedImage;
  ScanQuota _quota = ScanQuota.initial();
  bool _isLoading = false;
  String? _errorMessage;
  TimetableScanErrorCode? _errorCode;
  List<ClassItem>? _extractedClasses;

  UploadProvider({
    SettingsRepository? settingsRepository,
    TimetableExtractor? timetableExtractor,
  }) : _settingsRepository = settingsRepository ?? SettingsRepository(),
       _timetableExtractor =
           timetableExtractor ?? TimetableParserService.parseTimetable;

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

  /// Executes client-side Gemini Generative AI timetable parsing.
  Future<List<ClassItem>?> extractClasses() async {
    if (_isLoading) return null;
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
      _quota = await _settingsRepository.getScanQuota();
      if (!_quota.canScan()) {
        _errorCode = TimetableScanErrorCode.rateLimitExceeded;
        _errorMessage = 'Scan limit reached. Try again after your daily or weekly allowance resets.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final rawJson = await _timetableExtractor(File(_selectedImage!.path));
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
      if (e is TimetableScanException) {
        _errorCode = switch (e.failure) {
          TimetableScanFailure.configuration =>
            TimetableScanErrorCode.configuration,
          TimetableScanFailure.authentication =>
            TimetableScanErrorCode.authentication,
          TimetableScanFailure.modelUnavailable =>
            TimetableScanErrorCode.modelUnavailable,
          TimetableScanFailure.apiQuotaExceeded =>
            TimetableScanErrorCode.apiQuotaExceeded,
          TimetableScanFailure.invalidRequest =>
            TimetableScanErrorCode.invalidRequest,
          TimetableScanFailure.serviceUnavailable =>
            TimetableScanErrorCode.serverError,
          TimetableScanFailure.timeout => TimetableScanErrorCode.timeout,
          TimetableScanFailure.network => TimetableScanErrorCode.networkError,
          TimetableScanFailure.unreadableImage =>
            TimetableScanErrorCode.unreadableImage,
          TimetableScanFailure.malformedResponse ||
          TimetableScanFailure.invalidSchema =>
            TimetableScanErrorCode.parserFormatError,
          TimetableScanFailure.emptyResult =>
            TimetableScanErrorCode.emptyResult,
        };
        _errorMessage = _messageFor(_errorCode!);
      } else if (e is FileSystemException) {
        _errorCode = TimetableScanErrorCode.unreadableImage;
        _errorMessage = _messageFor(_errorCode!);
      } else {
        _errorCode = TimetableScanErrorCode.networkError;
        _errorMessage = _messageFor(_errorCode!);
      }
      notifyListeners();
      return null;
    }
  }

  String _messageFor(TimetableScanErrorCode code) => switch (code) {
    TimetableScanErrorCode.rateLimitExceeded =>
      'Scan limit reached. Try again after your allowance resets.',
    TimetableScanErrorCode.configuration ||
    TimetableScanErrorCode.authentication => 'AI scanning is not configured correctly. Add a valid Gemini API key in the release configuration.',
    TimetableScanErrorCode.modelUnavailable =>
      'AI scanning is temporarily unavailable. Try again later.',
    TimetableScanErrorCode.apiQuotaExceeded =>
      'The AI service quota is exhausted. Try again later.',
    TimetableScanErrorCode.invalidRequest =>
      'Could not read this timetable. Try a clearer image.',
    TimetableScanErrorCode.parserFormatError =>
      'Could not read the timetable. Try a clearer image.',
    TimetableScanErrorCode.networkError =>
      'Internet connection unavailable. Check your connection and try again.',
    TimetableScanErrorCode.timeout =>
      'The AI service took too long to respond. Try again shortly.',
    TimetableScanErrorCode.unreadableImage =>
      'Could not open this image. Choose a clear JPG, PNG or WebP photo.',
    TimetableScanErrorCode.serverError =>
      'AI service temporarily unavailable. Try again later.',
    TimetableScanErrorCode.emptyResult =>
      'No classes found. Try a clearer photo of the full timetable.',
  };
}
