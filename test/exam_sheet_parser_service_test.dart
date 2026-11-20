import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextclass/services/exam_sheet_parser_service.dart';

void main() {
  group('ExamSheetParserService', () {
    test('accepts supported formats and rejects legacy XLS', () {
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
    test(
      'sends PDF through the Worker and preserves extracted exams for review',
      () async {
        final client = MockClient((request) async {
          expect(request.url.toString(), 'https://worker.test/v1/extract/exam');
          expect(
            request.headers['idempotency-key'],
            matches(RegExp(r'^[0-9a-f-]{36}$')),
          );
          expect(request.headers.containsKey('x-goog-api-key'), isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['document']['mimeType'], 'application/pdf');
          expect(body['program'], 'BS Computer Science');
          expect(body['semester'], 'Semester 3');
          expect(body['section'], 'A');
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'exams': [
                  {
                    'subject': 'Algorithms',
                    'date': '2026-12-15',
                    'startTime': '09:00',
                    'endTime': '12:00',
                    'program': 'BS Computer Science',
                    'semester': 'Semester 3',
                    'section': 'A',
                    'venue': 'Main Hall',
                    'examType': 'Final',
                  },
                ],
              },
            }),
            200,
          );
        });
        final result = await ExamSheetParserService.parse(
          bytes: Uint8List.fromList([37, 80, 68, 70]),
          fileName: 'sheet.pdf',
          program: 'BS Computer Science',
          semester: 'Semester 3',
          section: 'A',
          scheduleId: 'schedule-1',
          httpClient: client,
          workerBaseUrlOverride: 'https://worker.test/',
        );
        expect(result, hasLength(1));
        expect(result.single.subject, 'Algorithms');
        expect(result.single.scheduleId, 'schedule-1');
        expect(result.single.isAiUnsure, isFalse);
      },
    );
    test(
      'handles Worker failures and offline behavior without retrying',
      () async {
        for (final status in [413, 422, 429, 503, 504]) {
          var requests = 0;
          final client = MockClient((_) async {
            requests++;
            return http.Response('{}', status);
          });
          await expectLater(
            ExamSheetParserService.parse(
              bytes: Uint8List.fromList([1]),
              fileName: 'sheet.pdf',
              program: 'CS',
              semester: '3',
              section: 'A',
              httpClient: client,
              workerBaseUrlOverride: 'https://worker.test',
            ),
            throwsA(isA<ExamSheetFormatException>()),
          );
          expect(requests, 1);
        }
        final offline = MockClient(
          (_) async => throw http.ClientException('offline'),
        );
        await expectLater(
          ExamSheetParserService.parse(
            bytes: Uint8List.fromList([1]),
            fileName: 'sheet.pdf',
            program: 'CS',
            semester: '3',
            section: 'A',
            httpClient: offline,
            workerBaseUrlOverride: 'https://worker.test',
          ),
          throwsA(isA<ExamSheetFormatException>()),
        );
      },
    );
  });
}
