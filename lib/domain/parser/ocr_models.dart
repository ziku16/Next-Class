import 'dart:ui';

/// Represents an individual recognized word or token with spatial bounds.
class OcrTextElement {
  final String text;
  final Rect boundingBox;
  final double? confidence;

  const OcrTextElement({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  double get left => boundingBox.left;
  double get top => boundingBox.top;
  double get right => boundingBox.right;
  double get bottom => boundingBox.bottom;
  double get width => boundingBox.width;
  double get height => boundingBox.height;
  Offset get center => boundingBox.center;
  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;

  @override
  String toString() => 'OcrTextElement("$text", bounds: $boundingBox)';
}

/// Represents a single recognized line of text with spatial bounds.
class OcrTextLine {
  final String text;
  final Rect boundingBox;
  final List<OcrTextElement> elements;

  const OcrTextLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
  });

  double get left => boundingBox.left;
  double get top => boundingBox.top;
  double get right => boundingBox.right;
  double get bottom => boundingBox.bottom;
  double get width => boundingBox.width;
  double get height => boundingBox.height;
  Offset get center => boundingBox.center;
  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;

  @override
  String toString() => 'OcrTextLine("$text", bounds: $boundingBox)';
}

/// Represents a cohesive spatial block of recognized text.
class OcrTextBlock {
  final String text;
  final Rect boundingBox;
  final List<OcrTextLine> lines;

  const OcrTextBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  double get left => boundingBox.left;
  double get top => boundingBox.top;
  double get right => boundingBox.right;
  double get bottom => boundingBox.bottom;
  double get width => boundingBox.width;
  double get height => boundingBox.height;
  Offset get center => boundingBox.center;
  double get centerX => boundingBox.center.dx;
  double get centerY => boundingBox.center.dy;

  @override
  String toString() => 'OcrTextBlock("${text.replaceAll('\n', ' ')}", bounds: $boundingBox)';
}

/// Normalized output of the local OCR engine, containing both hierarchy and spatial bounds.
class OcrResult {
  final List<OcrTextBlock> blocks;
  final List<OcrTextLine> lines;
  final String fullText;
  final Size imageSize;

  const OcrResult({
    required this.blocks,
    required this.lines,
    required this.fullText,
    required this.imageSize,
  });

  factory OcrResult.empty() => const OcrResult(
        blocks: [],
        lines: [],
        fullText: '',
        imageSize: Size.zero,
      );

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
}
