import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/class_item.dart';
import '../parser/class_deduplicator.dart';
import '../parser/deterministic_class_parser.dart';
import '../parser/grid_cell_assigner.dart';
import '../parser/image_preprocessor.dart';
import '../parser/local_ocr_engine.dart';
import '../parser/ocr_models.dart';
import '../parser/timetable_grid_detector.dart';

enum TimetableScanErrorCode {
  parsingFailed,
  noClassesFound,
  noInternet, // Retained for compatibility with legacy test enums
}

class TimetableScanException implements Exception {
  final TimetableScanErrorCode code;
  final String message;

  const TimetableScanException(this.code, this.message);

  @override
  String toString() => 'TimetableScanException($code): $message';
}

/// Service that performs 100% on-device local timetable scanning and parsing.
/// Zero Gemini, zero generative AI, zero cloud OCR API.
class TimetableScannerService {
  final ImagePreprocessor preprocessor;
  final LocalOcrEngine ocrEngine;
  final TimetableGridDetector gridDetector;
  final GridCellAssigner cellAssigner;
  final DeterministicClassParser classParser;

  const TimetableScannerService({
    this.preprocessor = const ImagePreprocessor(),
    this.ocrEngine = const MockOcrEngine.empty(),
    this.gridDetector = const TimetableGridDetector(),
    this.cellAssigner = const GridCellAssigner(),
    this.classParser = const DeterministicClassParser(),
  });

  /// Extracts structured [ClassItem]s from a timetable image file entirely on-device.
  Future<List<ClassItem>> scanTimetable(
    String imagePath, {
    bool simulateError = false,
    bool simulateEmpty = false,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    if (simulateError) {
      await Future.delayed(delay);
      throw const TimetableScanException(
        TimetableScanErrorCode.parsingFailed,
        "We couldn't read your timetable this time. It didn't use up a scan, so please try again.",
      );
    }

    if (simulateEmpty) {
      await Future.delayed(delay);
      throw const TimetableScanException(
        TimetableScanErrorCode.noClassesFound,
        "That doesn't look like a timetable. Try a clearer photo, or add your classes yourself.",
      );
    }

    final file = File(imagePath);
    final fileExists = await file.exists();
    final isMock = ocrEngine is MockOcrEngine;
    if (!fileExists && !isMock) {
      await Future.delayed(delay);
      throw const TimetableScanException(
        TimetableScanErrorCode.parsingFailed,
        "Timetable image could not be loaded. Please select a valid photo.",
      );
    }

    PreprocessedImageResult? preprocessed;
    try {
      final OcrResult ocrResult;
      if (isMock) {
        ocrResult = await ocrEngine.recognizeText(imagePath);
      } else {
        // 1. Image preprocessing (orientation, downscaling, subtle contrast)
        preprocessed = await preprocessor.preprocess(imagePath);

        // 2. Local on-device OCR
        ocrResult = await ocrEngine.recognizeText(
          preprocessed.path,
          fallbackSize: preprocessed.size,
        );
      }

      if (ocrResult.isEmpty) {
        throw const TimetableScanException(
          TimetableScanErrorCode.noClassesFound,
          "No text could be read from this photo. Please make sure the image is well-lit and in focus.",
        );
      }

      // 2.5 OCR Level Deduplication (merges overlapping duplicate bounding boxes)
      final deduplicatedLines = ClassDeduplicator.deduplicateOcrLines(ocrResult.lines);
      final cleanOcrResult = OcrResult(
        blocks: ocrResult.blocks,
        lines: deduplicatedLines,
        fullText: ocrResult.fullText,
        imageSize: ocrResult.imageSize,
      );

      // 3. Adaptive Grid reconstruction
      final grid = gridDetector.detectGrid(cleanOcrResult);

      // 4. Assign text elements to grid cells
      final cells = cellAssigner.assignLinesToCells(
        ocrResult: cleanOcrResult,
        grid: grid,
      );

      // 5. Deterministic class parsing (Subject, Teacher, Room, Time)
      final classes = classParser.parseCells(cells);

      if (classes.isEmpty) {
        throw const TimetableScanException(
          TimetableScanErrorCode.noClassesFound,
          "Couldn't detect a timetable. Please use a clearer image containing the full timetable.",
        );
      }

      return classes;
    } catch (e) {
      if (e is TimetableScanException) rethrow;
      debugPrint('[TimetableScannerService] Error during local scan: $e');
      throw const TimetableScanException(
        TimetableScanErrorCode.parsingFailed,
        "We couldn't read your timetable this time. Please try again with a clearer photo.",
      );
    } finally {
      await preprocessed?.cleanup();
    }
  }
}
