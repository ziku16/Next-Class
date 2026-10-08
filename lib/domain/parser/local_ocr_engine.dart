import 'dart:ui';
import 'ocr_models.dart';

/// Abstract contract for local on-device OCR engines.
abstract class LocalOcrEngine {
  Future<OcrResult> recognizeText(String imagePath, {Size? fallbackSize});
}

/// In-memory mock/stub OCR engine for testing without external native libraries.
class MockOcrEngine implements LocalOcrEngine {
  final OcrResult Function(String path) _resultBuilder;

  const MockOcrEngine([this._resultBuilder = _defaultEmpty]);

  const MockOcrEngine.empty() : _resultBuilder = _defaultEmpty;

  static OcrResult _defaultEmpty(String _) => OcrResult.empty();

  factory MockOcrEngine.fromResult(OcrResult result) =>
      MockOcrEngine((_) => result);

  @override
  Future<OcrResult> recognizeText(String imagePath, {Size? fallbackSize}) async {
    return _resultBuilder(imagePath);
  }
}
