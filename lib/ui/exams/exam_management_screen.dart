import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/next_class_colors.dart';
import '../../data/models/exam_item.dart';
import '../../data/models/exam_schedule.dart';
import '../../state/exam_provider.dart';
import '../../services/exam_sheet_parser_service.dart';

class ExamManagementScreen extends StatefulWidget {
  final ExamProvider provider;
  final Future<void> Function()? onScheduleChanged;

  const ExamManagementScreen({
    super.key,
    required this.provider,
    this.onScheduleChanged,
  });

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  static const _picker = MethodChannel('com.nextclass.app/device_info');
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_refresh);
    widget.provider.loadData();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _importSheet() async {
    setState(() => _isImporting = true);
    try {
      final selected = await _picker.invokeMapMethod<Object?, Object?>(
        'pickExamDocument',
      );
      if (selected == null) return;
      final fileName = selected['name']?.toString() ?? '';
      final raw = selected['bytes'];
      if (!ExamSheetParserService.isSupportedFile(fileName)) {
        throw const ExamSheetFormatException(
          'Choose a PDF, XLSX, JPG, JPEG, or PNG date sheet. Legacy .xls files are not supported.',
        );
      }
      if (raw is! Uint8List) {
        throw const ExamSheetFormatException(
          'Could not read the selected file.',
        );
      }
      final identity = await _showIdentityDialog();
      if (identity == null || !mounted) return;
      final schedule = ExamSchedule(
        id: 'schedule_${DateTime.now().microsecondsSinceEpoch}',
        program: identity.$1,
        semester: identity.$2,
        section: identity.$3,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final exams = await ExamSheetParserService.parse(
        bytes: raw,
        fileName: fileName,
        program: schedule.program,
        semester: schedule.semester,
        section: schedule.section,
        scheduleId: schedule.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamReviewScreen(
            schedule: schedule,
            initialExams: exams,
            onConfirm: (reviewed) async {
              await widget.provider.saveConfirmedSchedule(schedule, reviewed);
              await widget.onScheduleChanged?.call();
            },
          ),
        ),
      );
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Unable to open the document picker.');
    } on ExamSheetFormatException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not import the examination sheet: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<(String, String, String)?> _showIdentityDialog({
    ExamSchedule? initial,
  }) async {
    final program = TextEditingController(text: initial?.program ?? '');
    final semester = TextEditingController(text: initial?.semester ?? '');
    final section = TextEditingController(text: initial?.section ?? '');
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.ncColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: context.ncColors.border, width: 3),
        ),
        title: const Text('Your student group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _identityField(program, 'Degree program', 'e.g. BSCS'),
            const SizedBox(height: 10),
            _identityField(semester, 'Semester', 'e.g. Semester 3'),
            const SizedBox(height: 10),
            _identityField(section, 'Section', 'e.g. BCS-3'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (program.text.trim().isEmpty ||
                  semester.text.trim().isEmpty ||
                  section.text.trim().isEmpty)
                return;
              Navigator.pop(dialogContext, (
                program.text.trim(),
                semester.text.trim(),
                section.text.trim(),
              ));
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    program.dispose();
    semester.dispose();
    section.dispose();
    return result;
  }

  Widget _identityField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _addManualExam() async {
    ExamSchedule? schedule = widget.provider.activeSchedule;
    if (schedule == null) {
      final identity = await _showIdentityDialog();
      if (identity == null) return;
      schedule = ExamSchedule(
        id: 'schedule_${DateTime.now().microsecondsSinceEpoch}',
        program: identity.$1,
        semester: identity.$2,
        section: identity.$3,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    final exam = await _editExamDialog(null, schedule.id);
    if (exam == null) return;
    if (widget.provider.activeSchedule == null) {
      await widget.provider.saveConfirmedSchedule(schedule, [exam]);
    } else {
      await widget.provider.saveManualExam(exam);
    }
    await widget.onScheduleChanged?.call();
  }

  Future<ExamItem?> _editExamDialog(
    ExamItem? initial,
    String scheduleId,
  ) async {
    final subject = TextEditingController(text: initial?.subject ?? '');
    final start = TextEditingController(text: initial?.startTime ?? '');
    final end = TextEditingController(text: initial?.endTime ?? '');
    final venue = TextEditingController(text: initial?.venue ?? '');
    final type = TextEditingController(text: initial?.examType ?? '');
    var date = initial?.examDate ?? DateTime.now();
    final exam = await showDialog<ExamItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.ncColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.ncColors.border, width: 3),
          ),
          title: Text(initial == null ? 'Add exam' : 'Edit exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _identityField(subject, 'Subject', 'Course name'),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Exam date'),
                  subtitle: Text(DateFormat('EEE, d MMM yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                _identityField(start, 'Start time (optional)', 'HH:MM'),
                const SizedBox(height: 8),
                _identityField(end, 'End time (optional)', 'HH:MM'),
                const SizedBox(height: 8),
                _identityField(venue, 'Venue (optional)', 'Room / hall'),
                const SizedBox(height: 8),
                _identityField(type, 'Exam type (optional)', 'Final / midterm'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (subject.text.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  ExamItem(
                    id:
                        initial?.id ??
                        'exam_${DateTime.now().microsecondsSinceEpoch}',
                    scheduleId: scheduleId,
                    subject: subject.text.trim(),
                    examDate: DateTime(date.year, date.month, date.day),
                    startTime: start.text.trim().isEmpty
                        ? null
                        : start.text.trim(),
                    endTime: end.text.trim().isEmpty ? null : end.text.trim(),
                    venue: venue.text.trim().isEmpty ? null : venue.text.trim(),
                    examType: type.text.trim().isEmpty
                        ? null
                        : type.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    start.dispose();
    end.dispose();
    venue.dispose();
    type.dispose();
    return exam;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;
    final schedule = widget.provider.activeSchedule;
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        title: const Text(
          'Exams',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (widget.provider.schedules.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Switch active exam schedule',
              onSelected: (id) => widget.provider.activateSchedule(id),
              itemBuilder: (_) => widget.provider.schedules
                  .map(
                    (item) => PopupMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.program} · ${item.semester} · ${item.section}${item.isActive ? ' ✓' : ''}',
                      ),
                    ),
                  )
                  .toList(),
              icon: const Icon(Icons.swap_horiz),
            ),
        ],
      ),
      body: widget.provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (schedule != null)
                  _ScheduleBanner(
                    schedule: schedule,
                    isExamMode: widget.provider.isExamMode(DateTime.now()),
                  ),
                const SizedBox(height: 14),
                _ActionButton(
                  key: const Key('import_exam_sheet'),
                  label: _isImporting
                      ? 'Reading date sheet…'
                      : 'Import exam date sheet',
                  icon: Icons.upload_file_rounded,
                  onPressed: _isImporting ? null : _importSheet,
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  label: 'Add exam manually',
                  icon: Icons.add_rounded,
                  onPressed: _addManualExam,
                ),
                const SizedBox(height: 20),
                Text(
                  'Upcoming exams',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.provider.activeExams.isEmpty)
                  const _EmptyExams()
                else
                  ...widget.provider.activeExams.map(
                    (exam) => Card(
                      color: nc.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: nc.border, width: 2),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE500),
                            border: Border.all(color: nc.border, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            DateFormat('d\nMMM').format(exam.examDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                        title: Text(
                          exam.subject,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            if (exam.startTime != null)
                              '${exam.startTime}${exam.endTime == null ? '' : '–${exam.endTime}'}',
                            if (exam.venue != null) exam.venue!,
                            if (exam.isAiUnsure) 'Check section match',
                          ].join(' · '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'delete') {
                              await widget.provider.deleteExam(exam.id);
                            } else if (action == 'edit') {
                              final updated = await _editExamDialog(
                                exam,
                                exam.scheduleId,
                              );
                              if (updated != null)
                                await widget.provider.saveManualExam(updated);
                            }
                            await widget.onScheduleChanged?.call();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class ExamReviewScreen extends StatefulWidget {
  final ExamSchedule schedule;
  final List<ExamItem> initialExams;
  final Future<void> Function(List<ExamItem>) onConfirm;

  const ExamReviewScreen({
    super.key,
    required this.schedule,
    required this.initialExams,
    required this.onConfirm,
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  late List<ExamItem> _exams;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _exams = List.of(widget.initialExams);
  }

  Future<void> _confirm() async {
    if (_exams.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirm(_exams);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save exams: $error')));
      }
    }
  }

  Future<void> _edit(int index) async {
    final exam = _exams[index];
    final subject = TextEditingController(text: exam.subject);
    final venue = TextEditingController(text: exam.venue ?? '');
    final start = TextEditingController(text: exam.startTime ?? '');
    final end = TextEditingController(text: exam.endTime ?? '');
    var date = exam.examDate;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Review exam details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEE, d MMM yyyy').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Start time (optional)',
                  ),
                ),
                TextField(
                  controller: end,
                  decoration: const InputDecoration(
                    labelText: 'End time (optional)',
                  ),
                ),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(
                    labelText: 'Venue (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (subject.text.trim().isEmpty) return;
                setState(
                  () => _exams[index] = exam.copyWith(
                    subject: subject.text.trim(),
                    examDate: date,
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                    venue: venue.text.trim(),
                    clearStartTime: start.text.trim().isEmpty,
                    clearEndTime: end.text.trim().isEmpty,
                    clearVenue: venue.text.trim().isEmpty,
                    isAiUnsure: false,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    venue.dispose();
    start.dispose();
    end.dispose();
  }

  Future<void> _addMissing() async {
    final subject = TextEditingController();
    var date = DateTime.now();
    final result = await showDialog<ExamItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add missing exam'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEE, d MMM yyyy').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (subject.text.trim().isNotEmpty)
                  Navigator.pop(
                    dialogContext,
                    ExamItem(
                      id: 'exam_${DateTime.now().microsecondsSinceEpoch}',
                      scheduleId: widget.schedule.id,
                      subject: subject.text.trim(),
                      examDate: date,
                    ),
                  );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    if (result != null) setState(() => _exams.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        title: const Text('Review exams'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.schedule.program} · ${widget.schedule.semester} · ${widget.schedule.section}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check every subject, date, time and venue before saving.',
          ),
          const SizedBox(height: 12),
          ..._exams.asMap().entries.map(
            (entry) => Card(
              color: entry.value.isAiUnsure
                  ? const Color(0xFFFFF59D)
                  : nc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: nc.border, width: 2),
              ),
              child: ListTile(
                title: Text(
                  entry.value.subject,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${DateFormat('EEE, d MMM yyyy').format(entry.value.examDate)}${entry.value.startTime == null ? '' : ' · ${entry.value.startTime}'}${entry.value.venue == null ? '' : ' · ${entry.value.venue}'}${entry.value.isAiUnsure ? ' · Check section' : ''}',
                ),
                onTap: () => _edit(entry.key),
                trailing: IconButton(
                  tooltip: 'Remove exam',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _exams.removeAt(entry.key)),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addMissing,
            icon: const Icon(Icons.add),
            label: const Text('Add missing exam'),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: _saving ? 'Saving…' : 'Confirm and save schedule',
            icon: Icons.check,
            onPressed: _saving || _exams.isEmpty ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

class _ScheduleBanner extends StatelessWidget {
  final ExamSchedule schedule;
  final bool isExamMode;
  const _ScheduleBanner({required this.schedule, required this.isExamMode});
  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExamMode ? const Color(0xFFFFE500) : nc.surface,
        border: Border.all(color: nc.border, width: 2.5),
        boxShadow: [BoxShadow(color: nc.shadow, offset: const Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isExamMode ? 'EXAM MODE ACTIVE' : 'ACTIVE EXAM SCHEDULE',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${schedule.program} · ${schedule.semester} · ${schedule.section}',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final nc = context.ncColors;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        style: FilledButton.styleFrom(
          backgroundColor: nc.accent,
          foregroundColor: nc.buttonText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: nc.border, width: 2.5),
          ),
        ),
      ),
    );
  }
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.ncColors.surface,
      border: Border.all(color: context.ncColors.border, width: 2.5),
      boxShadow: [
        BoxShadow(color: context.ncColors.shadow, offset: const Offset(3, 3)),
      ],
    ),
    child: const Column(
      children: [
        Icon(Icons.event_busy_outlined, size: 34),
        SizedBox(height: 8),
        Text(
          'No exams saved yet',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        Text('Import a date sheet or add an exam manually.'),
      ],
    ),
  );
}
