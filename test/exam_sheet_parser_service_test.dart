import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextclass/services/exam_sheet_parser_service.dart';

const _programs = [
  'BAF',
  'BAI',
  'BBA',
  'BBD',
  'BCE',
  'BCS',
  'BEE',
  'BEN',
  'BMD',
  'BSE',
  'BSM',
  'PCE',
  'PCS',
  'PEE',
  'PMT',
  'RAE',
  'RCE',
  'RCS',
  'REE',
  'RMS',
  'RMT',
];

Uint8List _workbook({
  bool badBcsHeader = false,
  bool badBcsRow = false,
  bool badBcsTime = false,
  bool missingCourseCode = false,
  bool omitBcsSheet = false,
  bool excelDateCell = false,
  bool sharedCourseCode = false,
}) {
  final archive = Archive();
  final workbookSheets = StringBuffer(
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
  );
  final rels = StringBuffer(
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  for (var index = 0; index < _programs.length; index++) {
    final program = _programs[index];
    if (program == 'BCS' && omitBcsSheet) continue;
    final sheetId = index + 1;
    workbookSheets.write(
      '<sheet name="$program" sheetId="$sheetId" r:id="rId$sheetId"/>',
    );
    rels.write(
      '<Relationship Id="rId$sheetId" Target="worksheets/sheet$sheetId.xml"/>',
    );
    final rows = <List<String>>[
      program == 'BCS' && badBcsHeader
          ? ['No', 'When', 'Slot', 'Code', 'Name', 'Group', 'Place']
          : [
              'S No',
              'Date',
              'Time',
              'Course Code',
              'Course Title',
              'Class',
              'Strength',
              'Instructor',
              'Hall/Room',
              'Invigilators',
            ],
    ];
    if (program == 'BCS') {
      rows.addAll([
        [
          '1',
          '2026-11-04',
          badBcsTime ? '2560-2700' : '1500-1630',
          missingCourseCode ? '' : 'CSC211',
          'Data Structures',
          'BCS-III',
          '',
          '',
          'EEhall',
          '',
        ],
        [
          '2',
          '2026-11-05',
          '1500-1630',
          'CSC291',
          'Software Engineering Concepts',
          'BCS-III',
          '',
          '',
          'EEhall',
          '',
        ],
        [
          '3',
          '2026-11-06',
          '0830-1000',
          'MTH104',
          'Calculus and Analytic Geometry',
          'BCS-III',
          '',
          '',
          'EEhall',
          '',
        ],
        [
          '4',
          '2026-11-06',
          '1500-1630',
          'MGT250',
          'Introduction to Entrepreneurship',
          'BCS-III',
          '',
          '',
          'LH5',
          '',
        ],
        [
          '5',
          '2026-11-09',
          '1150-1320',
          'EEE240',
          'Fundamentals of Digital Logic Design',
          'BCS-III',
          '',
          '',
          'EEhall',
          '',
        ],
        [
          '6',
          badBcsRow ? '2026-02-30' : '2026-11-10',
          '1150-1320',
          'CSC270',
          'Database Systems',
          'BCS-III',
          '',
          '',
          'EEhall',
          '',
        ],
      ]);
    } else {
      rows.add([
        '1',
        '2026-11-04',
        '0830-1000',
        '${program}101',
        'Sample course',
        '$program-I',
        '',
        '',
        'Hall 1',
        '',
      ]);
    }
    final xml = StringBuffer(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final rowNumber = rowIndex == 0 ? 6 : rowIndex + 6;
      xml.write('<row r="$rowNumber">');
      for (var column = 0; column < rows[rowIndex].length; column++) {
        final cell = '${String.fromCharCode(65 + column)}$rowNumber';
        if (program == 'BCS' && excelDateCell && rowIndex == 1 && column == 1) {
          xml.write('<c r="$cell"><v>46330</v></c>');
          continue;
        }
        if (program == 'BCS' && sharedCourseCode && rowIndex == 1 && column == 3) {
          xml.write('<c r="$cell" t="s"><v>0</v></c>');
          continue;
        }
        final value = rows[rowIndex][column]
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;');
        xml.write('<c r="$cell" t="inlineStr"><is><t>$value</t></is></c>');
      }
      xml.write('</row>');
    }
    xml.write('</sheetData></worksheet>');
    archive.addFile(
      ArchiveFile(
        'xl/worksheets/sheet$sheetId.xml',
        xml.length,
        utf8.encode(xml.toString()),
      ),
    );
  }
  workbookSheets.write('</sheets></workbook>');
  rels.write('</Relationships>');
  if (sharedCourseCode) {
    archive.addFile(
      ArchiveFile.string(
        'xl/sharedStrings.xml',
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>CSC211</t></si></sst>',
      ),
    );
  }
  archive.addFile(
    ArchiveFile(
      'xl/workbook.xml',
      workbookSheets.length,
      utf8.encode(workbookSheets.toString()),
    ),
  );
  archive.addFile(
    ArchiveFile(
      'xl/_rels/workbook.xml.rels',
      rels.length,
      utf8.encode(rels.toString()),
    ),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

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
    test('detects XLSX by extension or MIME type', () {
      expect(
        ExamSheetParserService.isXlsx(
          'datesheet',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
        isTrue,
      );
      expect(ExamSheetParserService.isXlsx('datesheet.XLSX'), isTrue);
      expect(
        ExamSheetParserService.isXlsx(
          'datesheet.pdf',
          mimeType: 'application/pdf',
        ),
        isFalse,
      );
    });
    test(
      'discovers the 21 worksheets and only batches actually in the workbook',
      () {
        final batches = ExamSheetParserService.discoverXlsxBatches(_workbook());
        expect(batches, hasLength(21));
        expect(batches, containsAll(['BCS-III', 'BBA-I', 'RMT-I']));
        expect(ExamSheetParserService.normalizeBatch('BCS 3'), 'BCS-III');
        expect(ExamSheetParserService.normalizeBatch('BCS-3'), 'BCS-III');
        expect(ExamSheetParserService.normalizeBatch('BCS III'), 'BCS-III');
        expect(ExamSheetParserService.normalizeBatch('BCS-III'), 'BCS-III');
        expect(ExamSheetParserService.normalizeBatch('PMT 11'), 'PMT-XI');
      },
    );
    test('extracts the six expected BCS III exams locally with course code and title', () {
      final exams = ExamSheetParserService.parseXlsxBatch(
        _workbook(),
        selectedBatch: 'BCS III',
        scheduleId: 'schedule-test',
      );
      expect(exams, hasLength(6));
      expect(
        exams
            .map(
              (exam) =>
                  '${exam.dateKey}|${exam.subject}|${exam.startTime}|${exam.endTime}|${exam.venue}',
            )
            .toList(),
        [
          '2026-11-04|CSC211 — Data Structures|15:00|16:30|EEhall',
          '2026-11-05|CSC291 — Software Engineering Concepts|15:00|16:30|EEhall',
          '2026-11-06|MTH104 — Calculus and Analytic Geometry|08:30|10:00|EEhall',
          '2026-11-06|MGT250 — Introduction to Entrepreneurship|15:00|16:30|LH5',
          '2026-11-09|EEE240 — Fundamentals of Digital Logic Design|11:50|13:20|EEhall',
          '2026-11-10|CSC270 — Database Systems|11:50|13:20|EEhall',
        ],
      );
      expect(exams.every((exam) => exam.scheduleId == 'schedule-test'), isTrue);
    });
    test(
      'routes XLSX through local parsing without a Worker URL or HTTP client',
      () async {
        final exams = await ExamSheetParserService.parse(
          bytes: _workbook(),
          fileName: 'Midterm Datesheet Modified.xlsx',
          program: '',
          semester: '',
          section: 'BCS 3',
          scheduleId: 'schedule-local',
        );
        expect(exams, hasLength(6));
        expect(exams.first.subject, 'CSC211 — Data Structures');
      },
    );
    test('converts an Excel serial date cell to a calendar date', () {
      final exams = ExamSheetParserService.parseXlsxBatch(
        _workbook(excelDateCell: true),
        selectedBatch: 'BCS-III',
        scheduleId: 'schedule-serial',
      );
      expect(exams.first.dateKey, '2026-11-04');
    });
    test('resolves shared-string cell values from the workbook table', () {
      final exams = ExamSheetParserService.parseXlsxBatch(
        _workbook(sharedCourseCode: true),
        selectedBatch: 'BCS-III',
        scheduleId: 'schedule-shared',
      );
      expect(exams.first.subject, 'CSC211 — Data Structures');
    });
    test('reports missing worksheets, headers, batches, and invalid rows', () {
      expect(
        () => ExamSheetParserService.discoverXlsxBatches(Uint8List(0)),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(badBcsHeader: true),
          selectedBatch: 'BCS III',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(),
          selectedBatch: 'ZZZ II',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(omitBcsSheet: true),
          selectedBatch: 'BCS III',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(badBcsRow: true),
          selectedBatch: 'BCS III',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(badBcsTime: true),
          selectedBatch: 'BCS III',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(missingCourseCode: true),
          selectedBatch: 'BCS III',
          scheduleId: 's',
        ),
        throwsA(isA<ExamSheetFormatException>()),
      );
      expect(
        () => ExamSheetParserService.parseXlsxBatch(
          _workbook(),
          selectedBatch: 'BCS-IV',
          scheduleId: 's',
        ),
        throwsA(
          isA<ExamSheetFormatException>().having(
            (error) => error.message,
            'message',
            contains('No exams were found'),
          ),
        ),
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
