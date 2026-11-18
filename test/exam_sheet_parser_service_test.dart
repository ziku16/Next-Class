import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/services/exam_sheet_parser_service.dart';

void main() {
  group('ExamSheetParserService', () {
    test('accepts supported exam sheet formats and rejects legacy XLS', () {
      expect(ExamSheetParserService.isSupportedFile('sheet.pdf'), isTrue);
      expect(ExamSheetParserService.isSupportedFile('sheet.XLSX'), isTrue);
      expect(ExamSheetParserService.isSupportedFile('sheet.jpeg'), isTrue);
      expect(ExamSheetParserService.isSupportedFile('sheet.xls'), isFalse);
      expect(ExamSheetParserService.isSupportedFile('sheet.docx'), isFalse);
    });

    test('reports malformed XLSX archives clearly', () {
      expect(
        () => ExamSheetParserService.xlsxToText(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ExamSheetFormatException>()),
      );
    });
  });
}
