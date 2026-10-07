import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_models.dart';

/// Abstract contract for local on-device OCR engines.
abstract class LocalOcrEngine {
  Future<OcrResult> recognizeText(String imagePath, {Size? fallbackSize});
}

/// Google ML Kit on-device Text Recognition implementation.
/// Runs completely offline with zero network calls.
class MlKitOcrEngine implements LocalOcrEngine {
  final TextRecognitionScript script;

  const MlKitOcrEngine({this.script = TextRecognitionScript.latin});

  @override
  Future<OcrResult> recognizeText(String imagePath, {Size? fallbackSize}) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult.empty();
    }

    final recognizer = TextRecognizer(script: script);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);

      final List<OcrTextBlock> ocrBlocks = [];
      final List<OcrTextLine> ocrLines = [];

      for (final block in recognizedText.blocks) {
        final List<OcrTextLine> blockLines = [];

        for (final line in block.lines) {
          final List<OcrTextElement> lineElements = [];
          for (final element in line.elements) {
            lineElements.add(OcrTextElement(
              text: element.text,
              boundingBox: element.boundingBox,
              confidence: element.confidence,
            ));
          }

          final ocrLine = OcrTextLine(
            text: line.text,
            boundingBox: line.boundingBox,
            elements: lineElements,
          );
          blockLines.add(ocrLine);
          ocrLines.add(ocrLine);
        }

        ocrBlocks.add(OcrTextBlock(
          text: block.text,
          boundingBox: block.boundingBox,
          lines: blockLines,
        ));
      }

      // Sort lines top-to-bottom, then left-to-right
      ocrLines.sort((a, b) {
        final dy = a.top.compareTo(b.top);
        if (dy.abs() > 8) return dy;
        return a.left.compareTo(b.left);
      });

      final effectiveSize = fallbackSize ??
          (ocrLines.isNotEmpty
              ? Size(
                  ocrLines.map((l) => l.right).reduce((a, b) => a > b ? a : b),
                  ocrLines.map((l) => l.bottom).reduce((a, b) => a > b ? a : b),
                )
              : const Size(1000, 1000));

      return OcrResult(
        blocks: ocrBlocks,
        lines: ocrLines,
        fullText: recognizedText.text,
        imageSize: effectiveSize,
      );
    } catch (e) {
      debugPrint('[MlKitOcrEngine] OCR recognition error: $e');
      rethrow;
    } finally {
      await recognizer.close();
    }
  }
}

/// In-memory mock OCR engine for testing without Google Play Services.
class MockOcrEngine implements LocalOcrEngine {
  final OcrResult Function(String path) _resultBuilder;

  MockOcrEngine(this._resultBuilder);

  factory MockOcrEngine.fromResult(OcrResult result) =>
      MockOcrEngine((_) => result);

  @override
  Future<OcrResult> recognizeText(String imagePath, {Size? fallbackSize}) async {
    return _resultBuilder(imagePath);
  }
}
