import 'dart:io';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Handles on-device image preprocessing to optimize OCR accuracy and speed.
class ImagePreprocessor {
  static const int maxDimension = 2048;

  const ImagePreprocessor();

  /// Preprocesses an image from [inputPath], baking EXIF orientation,
  /// downscaling oversized images, and slightly enhancing contrast.
  /// Returns a record with the preprocessed image path and original/adjusted image dimensions.
  Future<PreprocessedImageResult> preprocess(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return PreprocessedImageResult(
        path: inputPath,
        size: const Size(1000, 1000),
      );
    }

    try {
      // Decode image bytes
      final bytes = await inputFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return PreprocessedImageResult(
          path: inputPath,
          size: const Size(1000, 1000),
        );
      }

      // 1. Bake EXIF rotation so pixels are right-side-up
      img.Image processed = img.bakeOrientation(decoded);

      // 2. Downscale if dimension exceeds maxDimension
      if (processed.width > maxDimension || processed.height > maxDimension) {
        if (processed.width >= processed.height) {
          final targetHeight = (processed.height * (maxDimension / processed.width)).round();
          processed = img.copyResize(
            processed,
            width: maxDimension,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          );
        } else {
          final targetWidth = (processed.width * (maxDimension / processed.height)).round();
          processed = img.copyResize(
            processed,
            width: targetWidth,
            height: maxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // 3. Subtle contrast enhancement to help faint text on colored cells
      processed = img.adjustColor(processed, contrast: 1.12);

      // 4. Save to temporary preprocessed file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/preprocessed_tt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final encodedJpg = img.encodeJpg(processed, quality: 90);
      await tempFile.writeAsBytes(encodedJpg);

      return PreprocessedImageResult(
        path: tempFile.path,
        size: Size(processed.width.toDouble(), processed.height.toDouble()),
        isTemporary: true,
      );
    } catch (e) {
      debugPrint('[ImagePreprocessor] Preprocessing failed ($e), falling back to original.');
      return PreprocessedImageResult(
        path: inputPath,
        size: const Size(1000, 1000),
      );
    }
  }
}

class PreprocessedImageResult {
  final String path;
  final Size size;
  final bool isTemporary;

  const PreprocessedImageResult({
    required this.path,
    required this.size,
    this.isTemporary = false,
  });

  Future<void> cleanup() async {
    if (isTemporary) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }
}
