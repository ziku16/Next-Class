import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:xml/xml.dart';
import '../data/models/exam_item.dart';

class ExamSheetFormatException implements Exception {
  final String message;
  const ExamSheetFormatException(this.message);
  @override
  String toString() => message;
}

/// Reads XLSX workbook cells locally and uses Gemini for PDF/image extraction.
class ExamSheetParserService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const List<String> _candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
  ];

  static bool isSupportedFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return const {'pdf', 'xlsx', 'jpg', 'jpeg', 'png'}.contains(extension);
  }

  static Future<List<ExamItem>> parse({
    required Uint8List bytes,
    required String fileName,
    required String program,
    required String semester,
    required String section,
    String? scheduleId,
    GenerativeModel? model,
  }) async {
    final extension = fileName.toLowerCase().split('.').last;
    if (extension == 'xls') {
      throw const ExamSheetFormatException(
        'Legacy .xls files are not supported. Please save this sheet as .xlsx or PDF.',
      );
    }
    if (!isSupportedFile(fileName)) {
      throw const ExamSheetFormatException(
        'Unsupported file. Choose a PDF, XLSX, JPG, JPEG, or PNG date sheet.',
      );
    }
    if (bytes.isEmpty) {
      throw const ExamSheetFormatException('The selected file is empty or unreadable.');
    }

    final content = <Part>[];
    if (extension == 'xlsx') {
      final workbookText = xlsxToText(bytes);
      if (workbookText.trim().isEmpty) {
        throw const ExamSheetFormatException('No readable rows were found in this Excel file.');
      }
      content.add(TextPart('Workbook cells (read locally):\n$workbookText'));
    } else {
      final mimeType = switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
      content.add(DataPart(mimeType, bytes));
    }

    if (model == null && _apiKey.isEmpty) {
      throw const ExamSheetFormatException(
        'AI extraction is not configured. Set GEMINI_API_KEY and try again.',
      );
    }

    final prompt = '''
Extract examination entries from this date sheet and return only JSON:
{"exams":[{"subject":"Course","date":"YYYY-MM-DD","startTime":"HH:MM or null","endTime":"HH:MM or null","program":"or null","semester":"or null","section":"or null","venue":"or null","examType":"or null"}]}
Student selection: program="$program", semester="$semester", section="$section".
Include only exams explicitly associated with this selection. Exclude entries with a different explicit program, semester, or section. A shared course may be included only if its row/heading supports this section. Do not infer missing values; return null. Normalize dates and times only when supported by the source. Preserve headings that apply to following rows.
''';
    final requestParts = <Part>[TextPart(prompt), ...content];
    String? responseText;
    Object? lastError;
    if (model != null) {
      responseText = (await model.generateContent([Content.multi(requestParts)])).text;
    } else {
      for (final modelName in _candidateModels) {
        try {
          final candidate = GenerativeModel(
            model: modelName,
            apiKey: _apiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0,
            ),
          );
          responseText = (await candidate
                  .generateContent([Content.multi(requestParts)])
                  .timeout(const Duration(seconds: 40)))
              .text;
          if (responseText != null && responseText.trim().isNotEmpty) break;
        } catch (error) {
          lastError = error;
        }
      }
    }
    if (responseText == null || responseText.trim().isEmpty) {
      throw ExamSheetFormatException(lastError == null
          ? 'The AI service returned no examination entries.'
          : 'Could not read this date sheet. Check your connection and try again.');
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
        if (subject.isEmpty || date == null || !_matchesIdentity(row, program, semester, section)) {
          continue;
        }
        final explicitFields = [row['program'], row['semester'], row['section']];
        parsed.add(ExamItem(
          id: 'exam_${DateTime.now().microsecondsSinceEpoch}_${parsed.length}',
          scheduleId: scheduleId ?? 'pending',
          subject: subject,
          examDate: date,
          startTime: _normalizeTime(row['startTime']?.toString()),
          endTime: _normalizeTime(row['endTime']?.toString()),
          venue: _optionalText(row['venue']),
          examType: _optionalText(row['examType']),
          isAiUnsure: explicitFields.any((value) => _optionalText(value) == null),
        ));
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
      throw ExamSheetFormatException('Could not parse the extracted exam data: $error');
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
      return value == null || _normalizeIdentity(value) == _normalizeIdentity(selected);
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
    if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'n/a') return null;
    return text;
  }

  static DateTime? _parseDate(String raw) {
    final value = raw.trim();
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$').firstMatch(value);
    if (match == null) return null;
    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += year < 70 ? 2000 : 1900;
    // Ambiguous slash dates are treated as day/month/year, common on university sheets.
    final day = first;
    final month = second;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) return null;
    return parsed;
  }

  static String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (value.isEmpty || value == 'NULL') return null;
    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$').firstMatch(value);
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
              .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
              .toList();
      final sheets = archive.files
          .where((file) => file.isFile &&
              RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name))
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
            final raw = valueElements.isEmpty ? '' : valueElements.first.innerText;
            final value = switch (type) {
              's' => int.tryParse(raw) != null && int.parse(raw) < sharedStrings.length
                  ? sharedStrings[int.parse(raw)]
                  : '',
              'inlineStr' => cell.findAllElements('t').map((t) => t.innerText).join(),
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
        final maxRow = rowNumbers.reduce((a, b) => a > b ? a : b).clamp(minRow, minRow + 300);
        final minCol = columnNumbers.reduce((a, b) => a < b ? a : b);
        final maxCol = columnNumbers.reduce((a, b) => a > b ? a : b).clamp(minCol, minCol + 40);
        final rows = <List<String>>[];
        for (var row = minRow; row <= maxRow; row++) {
          final values = <String>[];
          for (var col = minCol; col <= maxCol; col++) {
            var value = cells['$row:$col'] ?? '';
            // Normalize Excel date serials when the column header signals a date.
            if (row > minRow && RegExp(r'date|day', caseSensitive: false).hasMatch(cells['$minRow:$col'] ?? '')) {
              final serial = double.tryParse(value);
              if (serial != null && serial > 0 && serial < 100000) {
                final date = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
                value = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              }
            }
            values.add(value);
          }
          if (values.any((value) => value.trim().isNotEmpty)) rows.add(values);
        }
        if (rows.isNotEmpty) {
          output.add('Sheet ${sheet.name}:\n${rows.map((row) => row.join(' | ')).join('\n')}');
        }
      }
      return output.join('\n\n');
    } catch (error) {
      throw ExamSheetFormatException('This XLSX file is malformed or encrypted: $error');
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
