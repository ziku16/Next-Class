import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../data/models/exam_item.dart';

class ExamSheetFormatException implements Exception {
  final String message;
  const ExamSheetFormatException(this.message);
  @override
  String toString() => message;
}

class _XlsxSheet {
  final String name;
  final Map<int, Map<int, String>> rows;
  const _XlsxSheet(this.name, this.rows);
}

class _XlsxWorkbook {
  final List<_XlsxSheet> sheets;
  const _XlsxWorkbook(this.sheets);
}

class _ExamHeaders {
  final int row;
  final int dateColumn;
  final int timeColumn;
  final int courseCodeColumn;
  final int courseTitleColumn;
  final int classColumn;
  final int roomColumn;
  const _ExamHeaders({
    required this.row,
    required this.dateColumn,
    required this.timeColumn,
    required this.courseCodeColumn,
    required this.courseTitleColumn,
    required this.classColumn,
    required this.roomColumn,
  });
}

/// Reads XLSX date sheets locally and sends only PDFs/images to the Worker.
class ExamSheetParserService {
  static const String _workerBaseUrl = String.fromEnvironment(
    'NEXTCLASS_WORKER_URL',
  );

  static bool isSupportedFile(String fileName, {String? mimeType}) {
    final extension = fileName.toLowerCase().split('.').last;
    return isXlsx(fileName, mimeType: mimeType) ||
        const {'pdf', 'jpg', 'jpeg', 'png'}.contains(extension);
  }

  static bool isXlsx(String fileName, {String? mimeType}) =>
      fileName.toLowerCase().trim().endsWith('.xlsx') ||
      mimeType?.toLowerCase().split(';').first.trim() ==
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const Map<int, String> _semesterRomans = {
    1: 'I',
    2: 'II',
    3: 'III',
    4: 'IV',
    5: 'V',
    6: 'VI',
    7: 'VII',
    8: 'VIII',
    9: 'IX',
    10: 'X',
    11: 'XI',
  };

  static String normalizeBatch(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'[\s\-‐‑‒–—]+'),
      '-',
    );
    final match = RegExp(r'^([A-Z]+)-([A-Z]+|\d{1,2})$').firstMatch(normalized);
    if (match == null) return normalized;
    final program = match.group(1)!;
    final semester = match.group(2)!;
    final number = int.tryParse(semester);
    if (number != null) {
      final roman = _semesterRomans[number];
      return roman == null ? normalized : '$program-$roman';
    }
    final knownRoman = _semesterRomans.values.contains(semester);
    return knownRoman ? '$program-$semester' : normalized;
  }

  /// Returns the distinct class values found in every worksheet.
  static List<String> discoverXlsxBatches(Uint8List bytes) {
    final workbook = _readXlsxWorkbook(bytes);
    final batches = <String, String>{};
    var inspectedHeaders = 0;
    for (final sheet in workbook.sheets) {
      final header = _findExamHeaders(sheet.rows);
      if (header == null) continue;
      inspectedHeaders++;
      for (final row in sheet.rows.entries.where(
        (entry) => entry.key > header.row,
      )) {
        final batch = _cellText(row.value[header.classColumn]).trim();
        if (batch.isNotEmpty) {
          batches.putIfAbsent(normalizeBatch(batch), () => batch);
        }
      }
    }
    if (inspectedHeaders == 0) {
      throw const ExamSheetFormatException(
        'Required exam columns were not found. Check that the worksheet has Date, Time, Course Code, Course Title, Class, and Hall/Room headers.',
      );
    }
    if (batches.isEmpty) {
      throw const ExamSheetFormatException(
        'No class batches were found in this workbook.',
      );
    }
    return batches.values.toList()
      ..sort((a, b) => normalizeBatch(a).compareTo(normalizeBatch(b)));
  }

  /// Parses a selected class from the worksheet whose name matches its program prefix.
  static List<ExamItem> parseXlsxBatch(
    Uint8List bytes, {
    required String selectedBatch,
    String? scheduleId,
  }) {
    final normalizedBatch = normalizeBatch(selectedBatch);
    final match = RegExp(r'^([A-Z]+)-([IVX]+)$').firstMatch(normalizedBatch);
    if (match == null || !_semesterRomans.values.contains(match.group(2))) {
      throw const ExamSheetFormatException(
        'Selected batch was not found in this workbook.',
      );
    }
    final program = match.group(1)!;
    final workbook = _readXlsxWorkbook(bytes);
    final matchingSheets = workbook.sheets.where(
      (candidate) => candidate.name.toUpperCase() == program,
    );
    final sheet = matchingSheets.isEmpty ? null : matchingSheets.first;
    if (sheet == null) {
      throw ExamSheetFormatException(
        'No matching program worksheet was found for $program.',
      );
    }
    final headers = _findExamHeaders(sheet.rows);
    if (headers == null) {
      throw ExamSheetFormatException(
        'Required columns are missing from the $program worksheet. Expected Date, Time, Course Code, Course Title, Class, and Hall/Room.',
      );
    }
    final exams = <ExamItem>[];
    final seenRecords = <String>{};
    for (final rowEntry in sheet.rows.entries.where(
      (entry) => entry.key > headers.row,
    )) {
      final row = rowEntry.value;
      final rowBatch = _cellText(row[headers.classColumn]).trim();
      if (rowBatch.isEmpty || normalizeBatch(rowBatch) != normalizedBatch) {
        continue;
      }
      final dateValue = _cellText(row[headers.dateColumn]).trim();
      final timeValue = _cellText(row[headers.timeColumn]).trim();
      final courseCode = _cellText(row[headers.courseCodeColumn]).trim();
      final courseTitle = _cellText(row[headers.courseTitleColumn]).trim();
      final venue = _cellText(row[headers.roomColumn]).trim();
      final date = _parseXlsxDate(dateValue);
      final times = _parseTimeRange(timeValue);
      if (date == null || times == null) {
        throw ExamSheetFormatException(
          'Invalid date or time in row ${rowEntry.key} for $rowBatch. Check the date and 24-hour time range.',
        );
      }
      if (courseCode.isEmpty || courseTitle.isEmpty || venue.isEmpty) {
        throw ExamSheetFormatException(
          'Required course code, course title, or Hall/Room is missing in row ${rowEntry.key}. No incomplete exam was added.',
        );
      }
      final recordKey = [
        date.toIso8601String(),
        times.$1,
        times.$2,
        courseCode.toUpperCase(),
        venue.toUpperCase(),
      ].join('|');
      if (!seenRecords.add(recordKey)) continue;
      exams.add(
        ExamItem(
          id: 'exam_${DateTime.now().microsecondsSinceEpoch}_${exams.length}',
          scheduleId: scheduleId ?? 'pending',
          subject: '$courseCode — $courseTitle',
          examDate: date,
          startTime: times.$1,
          endTime: times.$2,
          venue: venue,
        ),
      );
    }
    if (exams.isEmpty) {
      throw ExamSheetFormatException(
        'No exams were found for the selected batch $selectedBatch.',
      );
    }
    exams.sort((a, b) {
      final dateOrder = a.localDate.compareTo(b.localDate);
      return dateOrder != 0 ? dateOrder : a.startTime!.compareTo(b.startTime!);
    });
    return exams;
  }

  static Future<List<ExamItem>> parse({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    required String program,
    required String semester,
    required String section,
    String? scheduleId,
    http.Client? httpClient,
    String? workerBaseUrlOverride,
    Duration requestTimeout = const Duration(seconds: 40),
  }) async {
    final extension = fileName.toLowerCase().split('.').last;
    final xlsxFile = isXlsx(fileName, mimeType: mimeType);
    if (extension == 'xls' && !xlsxFile) {
      throw const ExamSheetFormatException(
        'Legacy .xls files are not supported. Please save this sheet as .xlsx or PDF.',
      );
    }
    if (!isSupportedFile(fileName, mimeType: mimeType)) {
      throw const ExamSheetFormatException(
        'Unsupported file. Choose a PDF, XLSX, JPG, JPEG, or PNG date sheet.',
      );
    }
    if (bytes.isEmpty) {
      throw const ExamSheetFormatException(
        'The selected file is empty or unreadable.',
      );
    }
    if (xlsxFile) {
      return parseXlsxBatch(
        bytes,
        selectedBatch: section,
        scheduleId: scheduleId,
      );
    }
    final baseUrl = (workerBaseUrlOverride ?? _workerBaseUrl).trim();
    if (baseUrl.isEmpty) {
      throw const ExamSheetFormatException(
        'Exam scanning is not configured yet. Please try again later.',
      );
    }
    final documentMimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    final document = {
      'mimeType': documentMimeType,
      'data': base64Encode(bytes),
    };

    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    String responseText;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/extract/exam',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Idempotency-Key': const Uuid().v4(),
            },
            body: jsonEncode({
              'document': document,
              'program': program,
              'semester': semester,
              'section': section,
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          413 => 'This file is too large. Choose a smaller document.',
          422 => 'This date sheet could not be read. Try a clearer image or document.',
          429 =>
            'Too many scans right now. Please wait a minute and try again.',
          504 => 'The AI service took too long to respond. Please try again.',
          >= 500 =>
            'Exam scanning is temporarily unavailable. Please try again later.',
          _ =>
            'Could not scan this date sheet. Check the details and try again.',
        };
        throw ExamSheetFormatException(message);
      }
      final envelope = jsonDecode(response.body);
      if (envelope is! Map<String, dynamic> ||
          envelope['ok'] != true ||
          envelope['data'] is! Map) {
        throw const ExamSheetFormatException(
          'The AI service returned an unreadable response. Please try again.',
        );
      }
      responseText = jsonEncode(envelope['data']);
    } on TimeoutException {
      throw const ExamSheetFormatException(
        'Exam scanning took too long. Check your connection and try again.',
      );
    } on SocketException {
      throw const ExamSheetFormatException(
        'Could not connect to exam scanning. Check your internet connection and try again.',
      );
    } on http.ClientException {
      throw const ExamSheetFormatException(
        'Could not connect to exam scanning. Check your internet connection and try again.',
      );
    } on FormatException {
      throw const ExamSheetFormatException(
        'The AI service returned an unreadable response. Please try again.',
      );
    } finally {
      if (ownsClient) client.close();
    }

    try {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
      if (match == null) throw const FormatException('Missing JSON object');
      final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final rows = decoded['exams'] as List<dynamic>? ?? const [];
      final parsed = <ExamItem>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final subject = row['subject']?.toString().trim() ?? '';
        final date = _parseDate(row['date']?.toString() ?? '');
        if (subject.isEmpty ||
            date == null ||
            !_matchesIdentity(row, program, semester, section)) {
          continue;
        }
        final explicitFields = [
          row['program'],
          row['semester'],
          row['section'],
        ];
        parsed.add(
          ExamItem(
            id: 'exam_${DateTime.now().microsecondsSinceEpoch}_${parsed.length}',
            scheduleId: scheduleId ?? 'pending',
            subject: subject,
            examDate: date,
            startTime: _normalizeTime(row['startTime']?.toString()),
            endTime: _normalizeTime(row['endTime']?.toString()),
            venue: _optionalText(row['venue']),
            examType: _optionalText(row['examType']),
            isAiUnsure: explicitFields.any(
              (value) => _optionalText(value) == null,
            ),
          ),
        );
      }
      if (parsed.isEmpty) {
        throw const ExamSheetFormatException(
          'No exams matched the selected program, semester, and section. Check the details or add exams manually.',
        );
      }
      parsed.sort((a, b) {
        final dateOrder = a.localDate.compareTo(b.localDate);
        return dateOrder != 0
            ? dateOrder
            : (a.startTime ?? '99:99').compareTo(b.startTime ?? '99:99');
      });
      return parsed;
    } on ExamSheetFormatException {
      rethrow;
    } catch (error) {
      throw ExamSheetFormatException(
        'Could not parse the extracted exam data: $error',
      );
    }
  }

  static bool _matchesIdentity(
    Map<String, dynamic> row,
    String program,
    String semester,
    String section,
  ) {
    bool matches(String key, String selected) {
      final value = _optionalText(row[key]);
      return value == null ||
          _normalizeIdentity(value) == _normalizeIdentity(selected);
    }

    return matches('program', program) &&
        matches('semester', semester) &&
        matches('section', section);
  }

  static String _normalizeIdentity(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty ||
        text.toLowerCase() == 'null' ||
        text.toLowerCase() == 'n/a') {
      return null;
    }
    return text;
  }

  static DateTime? _parseDate(String raw) {
    final value = raw.trim();
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$')
        .firstMatch(value);
    if (match == null) return null;
    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += year < 70 ? 2000 : 1900;
    // Ambiguous slash dates are treated as day/month/year, common on university sheets.
    final day = first;
    final month = second;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String _cellText(String? value) => value ?? '';

  static _ExamHeaders? _findExamHeaders(Map<int, Map<int, String>> rows) {
    for (final entry in rows.entries) {
      final columns = <String, int>{};
      for (final cell in entry.value.entries) {
        columns[_normalizeHeader(cell.value)] = cell.key;
      }
      int? find(Iterable<String> aliases) {
        for (final alias in aliases) {
          final column = columns[alias];
          if (column != null) return column;
        }
        return null;
      }

      final date = find(const ['date', 'examdate', 'examday']);
      final time = find(const ['time', 'examtime', 'timerange']);
      final courseCode = find(const ['coursecode', 'subjectcode', 'courseno']);
      final courseTitle = find(const [
        'coursetitle',
        'coursename',
        'subject',
        'course',
      ]);
      final classColumn = find(const ['class', 'batch']);
      final room = find(const [
        'hallroom',
        'hall',
        'room',
        'venue',
        'location',
      ]);
      if (date != null &&
          time != null &&
          courseCode != null &&
          courseTitle != null &&
          classColumn != null &&
          room != null) {
        return _ExamHeaders(
          row: entry.key,
          dateColumn: date,
          timeColumn: time,
          courseCodeColumn: courseCode,
          courseTitleColumn: courseTitle,
          classColumn: classColumn,
          roomColumn: room,
        );
      }
    }
    return null;
  }

  static String _normalizeHeader(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static DateTime? _parseXlsxDate(String value) {
    final numeric = double.tryParse(value.trim());
    if (numeric != null && numeric >= 1 && numeric < 100000) {
      final date = DateTime(1899, 12, 30).add(Duration(days: numeric.floor()));
      return DateTime(date.year, date.month, date.day);
    }
    final isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})')
        .firstMatch(value.trim());
    if (isoDate != null) {
      final year = int.parse(isoDate.group(1)!);
      final month = int.parse(isoDate.group(2)!);
      final day = int.parse(isoDate.group(3)!);
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    }
    final parsed = _parseDate(value);
    if (parsed != null) return parsed;
    final namedMonth = RegExp(r'^(\d{1,2})[-\s]([A-Za-z]{3,9})[-\s](\d{4})$')
        .firstMatch(value.trim());
    if (namedMonth == null) return null;
    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };
    final day = int.parse(namedMonth.group(1)!);
    final month = months[namedMonth.group(2)!.substring(0, 3).toUpperCase()];
    final year = int.parse(namedMonth.group(3)!);
    if (month == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static (String, String)? _parseTimeRange(String raw) {
    final match = RegExp(
      r'^\s*(\d{3,4}|\d{1,2}:\d{2})\s*[-–—]\s*(\d{3,4}|\d{1,2}:\d{2})\s*$',
    ).firstMatch(raw);
    if (match == null) return null;
    String? time(String value) {
      int hour;
      int minute;
      if (value.contains(':')) {
        final parts = value.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      } else {
        final digits = value.padLeft(4, '0');
        hour = int.parse(digits.substring(0, 2));
        minute = int.parse(digits.substring(2));
      }
      if (hour > 23 || minute > 59) return null;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    final start = time(match.group(1)!);
    final end = time(match.group(2)!);
    if (start == null || end == null || start.compareTo(end) >= 0) return null;
    return (start, end);
  }

  static _XlsxWorkbook _readXlsxWorkbook(Uint8List bytes) {
    try {
      if (bytes.isEmpty) throw const FormatException('Empty workbook');
      final archive = ZipDecoder().decodeBytes(bytes);
      String? fileText(String path) {
        final entry = archive.findFile(path);
        final content = entry?.getContent()?.toUint8List();
        return content == null
            ? null
            : utf8.decode(content, allowMalformed: true);
      }

      final workbookXml = fileText('xl/workbook.xml');
      final relsXml = fileText('xl/_rels/workbook.xml.rels');
      if (workbookXml == null || relsXml == null) {
        throw const FormatException('Workbook sheet metadata is missing');
      }
      final sharedXml = fileText('xl/sharedStrings.xml');
      final sharedStrings = sharedXml == null
          ? <String>[]
          : XmlDocument.parse(sharedXml)
                .findAllElements('si')
                .map(
                  (item) => item
                      .findAllElements('t')
                      .map((node) => node.innerText)
                      .join(),
                )
                .toList();
      final relationships = <String, String>{};
      for (final relationship in XmlDocument.parse(
        relsXml,
      ).findAllElements('Relationship')) {
        final id = relationship.getAttribute('Id');
        final target = relationship.getAttribute('Target');
        if (id == null || target == null) continue;
        relationships[id] = _normalizeWorksheetPath(target);
      }
      final sheets = <_XlsxSheet>[];
      for (final sheetNode in XmlDocument.parse(
        workbookXml,
      ).findAllElements('sheet')) {
        final name = sheetNode.getAttribute('name');
        final relationId = sheetNode.getAttribute('r:id');
        final path = relationId == null ? null : relationships[relationId];
        if (name == null || path == null) continue;
        final xml = fileText(path);
        if (xml == null) continue;
        final rows = <int, Map<int, String>>{};
        final document = XmlDocument.parse(xml);
        for (final cell in document.findAllElements('c')) {
          final coordinate = _cellCoordinate(cell.getAttribute('r') ?? '');
          if (coordinate == null) continue;
          final (rowIndex, columnIndex) = coordinate;
          final type = cell.getAttribute('t');
          final values = cell.findElements('v');
          final raw = values.isEmpty ? '' : values.first.innerText;
          final value = switch (type) {
            's' =>
              int.tryParse(raw) != null && int.parse(raw) < sharedStrings.length
                  ? sharedStrings[int.parse(raw)]
                  : '',
            'inlineStr' =>
              cell.findAllElements('t').map((node) => node.innerText).join(),
            'str' => raw,
            _ => raw,
          };
          rows.putIfAbsent(rowIndex, () => <int, String>{})[columnIndex] =
              value;
        }
        if (rows.isNotEmpty) sheets.add(_XlsxSheet(name, rows));
      }
      if (sheets.isEmpty) {
        throw const FormatException('No readable worksheets found');
      }
      return _XlsxWorkbook(sheets);
    } on ExamSheetFormatException {
      rethrow;
    } catch (error) {
      throw ExamSheetFormatException(
        'This XLSX workbook is invalid or corrupted: $error',
      );
    }
  }

  static String _normalizeWorksheetPath(String target) {
    final segments = <String>[];
    for (final segment in target.replaceFirst(RegExp(r'^/+'), '').split('/')) {
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        segments.add(segment);
      }
    }
    final path = segments.join('/');
    return path.startsWith('xl/') ? path : 'xl/$path';
  }

  static String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (value.isEmpty || value == 'NULL') return null;
    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$')
        .firstMatch(value);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final suffix = match.group(3);
    if (suffix == 'PM' && hour < 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Extracts workbook XML and resolves shared/inline strings and merged cells.
  static String xlsxToText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? fileText(String path) {
        final file = archive.findFile(path);
        if (file == null) return null;
        final content = file.getContent()?.toUint8List();
        if (content == null) return null;
        return utf8.decode(content, allowMalformed: true);
      }

      final sharedXml = fileText('xl/sharedStrings.xml');
      final sharedStrings = sharedXml == null
          ? <String>[]
          : XmlDocument.parse(sharedXml)
                .findAllElements('si')
                .map(
                  (si) =>
                      si.findAllElements('t').map((t) => t.innerText).join(),
                )
                .toList();
      final sheets =
          archive.files
              .where(
                (file) =>
                    file.isFile &&
                    RegExp(r'^xl/worksheets/sheet\d+\.xml$')
                        .hasMatch(file.name),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      if (sheets.isEmpty) throw const FormatException('No worksheets found');

      final output = <String>[];
      for (final sheet in sheets) {
        final content = sheet.getContent()?.toUint8List();
        if (content == null) continue;
        final xml = utf8.decode(content, allowMalformed: true);
        final document = XmlDocument.parse(xml);
        final cells = <String, String>{};
        final rowNumbers = <int>{};
        final columnNumbers = <int>{};
        for (final row in document.findAllElements('row')) {
          for (final cell in row.findElements('c')) {
            final ref = cell.getAttribute('r') ?? '';
            final coordinate = _cellCoordinate(ref);
            if (coordinate == null) continue;
            final (rowIndex, colIndex) = coordinate;
            rowNumbers.add(rowIndex);
            columnNumbers.add(colIndex);
            final type = cell.getAttribute('t');
            final valueElements = cell.findElements('v');
            final raw = valueElements.isEmpty
                ? ''
                : valueElements.first.innerText;
            final value = switch (type) {
              's' =>
                int.tryParse(raw) != null &&
                        int.parse(raw) < sharedStrings.length
                    ? sharedStrings[int.parse(raw)]
                    : '',
              'inlineStr' =>
                cell.findAllElements('t').map((t) => t.innerText).join(),
              _ => raw,
            };
            cells['$rowIndex:$colIndex'] = value;
          }
        }

        // Expand merged ranges by carrying the top-left cell value into blank cells.
        for (final merged in document.findAllElements('mergeCell')) {
          final range = merged.getAttribute('ref') ?? '';
          final parts = range.split(':');
          if (parts.length != 2) continue;
          final start = _cellCoordinate(parts[0]);
          final end = _cellCoordinate(parts[1]);
          if (start == null || end == null) continue;
          final value = cells['${start.$1}:${start.$2}'] ?? '';
          for (var row = start.$1; row <= end.$1; row++) {
            for (var col = start.$2; col <= end.$2; col++) {
              final key = '$row:$col';
              if ((cells[key] ?? '').isEmpty) cells[key] = value;
              rowNumbers.add(row);
              columnNumbers.add(col);
            }
          }
        }

        if (rowNumbers.isEmpty || columnNumbers.isEmpty) continue;
        final minRow = rowNumbers.reduce((a, b) => a < b ? a : b);
        final maxRow = rowNumbers
            .reduce((a, b) => a > b ? a : b)
            .clamp(minRow, minRow + 300);
        final minCol = columnNumbers.reduce((a, b) => a < b ? a : b);
        final maxCol = columnNumbers
            .reduce((a, b) => a > b ? a : b)
            .clamp(minCol, minCol + 40);
        final rows = <List<String>>[];
        for (var row = minRow; row <= maxRow; row++) {
          final values = <String>[];
          for (var col = minCol; col <= maxCol; col++) {
            var value = cells['$row:$col'] ?? '';
            // Normalize Excel date serials when the column header signals a date.
            if (row > minRow &&
                RegExp(
                  r'date|day',
                  caseSensitive: false,
                ).hasMatch(cells['$minRow:$col'] ?? '')) {
              final serial = double.tryParse(value);
              if (serial != null && serial > 0 && serial < 100000) {
                final date = DateTime(
                  1899,
                  12,
                  30,
                ).add(Duration(days: serial.floor()));
                value =
                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              }
            }
            values.add(value);
          }
          if (values.any((value) => value.trim().isNotEmpty)) rows.add(values);
        }
        if (rows.isNotEmpty) {
          output.add(
            'Sheet ${sheet.name}:\n${rows.map((row) => row.join(' | ')).join('\n')}',
          );
        }
      }
      return output.join('\n\n');
    } catch (error) {
      throw ExamSheetFormatException(
        'This XLSX file is malformed or encrypted: $error',
      );
    }
  }

  static (int, int)? _cellCoordinate(String cell) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cell.toUpperCase());
    if (match == null) return null;
    var col = 0;
    for (final code in match.group(1)!.codeUnits) {
      col = col * 26 + code - 64;
    }
    return (int.parse(match.group(2)!), col);
  }
}
