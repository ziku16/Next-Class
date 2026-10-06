import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../domain/services/alarm_scheduler.dart';
import '../../state/quiz_provider.dart';
import '../shared/nc_banner.dart';

/// Modal bottom sheet for adding or editing a quiz (Flow 6).
/// Features:
/// - 28 dp top radius modal container
/// - Timetable Guard: displays warning banner and blocks creation when zero classes exist
/// - Class dropdown populated from timetable with optional pre-selection
/// - Required Topic / Title input
/// - Date picker constrained to today onward
/// - Optional note field
/// - Persists quiz and triggers evening-before alarm scheduling
class AddEditQuizSheet extends StatefulWidget {
  final QuizItem? initialQuiz;
  final String? preselectedClassId;
  final List<ClassItem>? classes;
  final TimetableRepository? timetableRepository;
  final QuizProvider? quizProvider;
  final VoidCallback? onUploadTimetable;
  final ValueChanged<QuizItem>? onSaved;

  const AddEditQuizSheet({
    super.key,
    this.initialQuiz,
    this.preselectedClassId,
    this.classes,
    this.timetableRepository,
    this.quizProvider,
    this.onUploadTimetable,
    this.onSaved,
  });

  /// Displays the AddEditQuizSheet in a revo-brutalist modal sheet
  static Future<QuizItem?> show(
    BuildContext context, {
    QuizItem? initialQuiz,
    String? preselectedClassId,
    List<ClassItem>? classes,
    TimetableRepository? timetableRepository,
    QuizProvider? quizProvider,
    VoidCallback? onUploadTimetable,
    ValueChanged<QuizItem>? onSaved,
  }) {
    return showModalBottomSheet<QuizItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF6EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: Colors.black, width: 3.5),
      ),
      builder: (ctx) => AddEditQuizSheet(
        initialQuiz: initialQuiz,
        preselectedClassId: preselectedClassId,
        classes: classes,
        timetableRepository: timetableRepository,
        quizProvider: quizProvider,
        onUploadTimetable: onUploadTimetable,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddEditQuizSheet> createState() => _AddEditQuizSheetState();
}

class _AddEditQuizSheetState extends State<AddEditQuizSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  List<ClassItem> _availableClasses = [];
  bool _isLoadingClasses = true;

  String? _selectedClassId;
  late DateTime _selectedDate;
  bool _isSaving = false;

  late String _reminderType;
  late TimeOfDay _reminderTime;
  String _customDay = 'day_of';

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialQuiz?.title ?? '');
    _noteController =
        TextEditingController(text: widget.initialQuiz?.note ?? '');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = widget.initialQuiz?.dueDate ?? today;

    _selectedClassId = widget.initialQuiz?.classId ?? widget.preselectedClassId;

    final initialReminderType =
        widget.initialQuiz?.reminderType ?? 'evening_before';
    _reminderType = (initialReminderType == 'morning_of' ||
            initialReminderType == 'day_of')
        ? 'morning_of'
        : (initialReminderType == 'custom' ? 'custom' : 'evening_before');
    if (initialReminderType == 'day_of') {
      _customDay = 'day_of';
    }

    if (widget.initialQuiz?.reminderTime != null &&
        widget.initialQuiz!.reminderTime!.isNotEmpty) {
      final parts = widget.initialQuiz!.reminderTime!.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      _reminderTime = _reminderType == 'morning_of'
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 20, minute: 0);
    }

    _resolveClasses();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _resolveClasses() async {
    if (widget.classes != null) {
      _availableClasses = widget.classes!;
      _finalizeClassSelection();
      setState(() => _isLoadingClasses = false);
      return;
    }

    if (widget.quizProvider != null &&
        widget.quizProvider!.classes.isNotEmpty) {
      _availableClasses = widget.quizProvider!.classes;
      _finalizeClassSelection();
      setState(() => _isLoadingClasses = false);
      return;
    }

    try {
      final repo = widget.timetableRepository ?? TimetableRepository();
      final items = await repo.getAllClasses();
      if (mounted) {
        setState(() {
          _availableClasses = items;
          _finalizeClassSelection();
          _isLoadingClasses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    }
  }

  void _finalizeClassSelection() {
    if (_availableClasses.isEmpty) {
      _selectedClassId = null;
      return;
    }

    // If preselected or current exists in classes list, keep it
    final exists = _availableClasses.any((c) => c.id == _selectedClassId);
    if (!exists) {
      _selectedClassId = _availableClasses.first.id;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) return;

    final selectedClass =
        _availableClasses.firstWhere((c) => c.id == _selectedClassId);

    setState(() => _isSaving = true);

    final timeStr =
        '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
    final effectiveReminderType =
        _reminderType == 'custom' ? _customDay : _reminderType;

    final quiz = QuizItem(
      id: widget.initialQuiz?.id ??
          'q_${DateTime.now().millisecondsSinceEpoch}',
      classId: selectedClass.id,
      subject: selectedClass.subject,
      title: _titleController.text.trim(),
      dueDate: _selectedDate,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      isCompleted: widget.initialQuiz?.isCompleted ?? false,
      reminderTime: timeStr,
      reminderType: effectiveReminderType,
    );

    try {
      if (widget.quizProvider != null) {
        if (widget.initialQuiz != null) {
          await widget.quizProvider!.updateQuiz(quiz);
        } else {
          await widget.quizProvider!.addQuiz(quiz);
        }
      } else if (widget.timetableRepository != null) {
        try {
          final repo = QuizRepository();
          if (widget.initialQuiz != null) {
            await repo.updateQuiz(quiz);
          } else {
            await repo.insertQuiz(quiz);
          }
          await AlarmScheduler().rescheduleAll();
        } catch (_) {}
      }

      widget.onSaved?.call(quiz);

      if (mounted) {
        Navigator.of(context).pop(quiz);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quiz: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ncColors = context.ncColors;
    final isEditing = widget.initialQuiz != null;

    final hasClasses = _availableClasses.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brutalist Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5500),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.quiz_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit quiz' : 'Add quiz',
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Timetable Guard: If no classes exist, show warning banner and upload action
              if (!_isLoadingClasses && !hasClasses) ...[
                NcBanner(
                  kind: NcBannerKind.warning,
                  title: 'Add your timetable first',
                  message:
                      "Quizzes belong to a class, and you haven't added any yet.",
                  actionLabel: 'Upload timetable',
                  onAction: () {
                    Navigator.of(context).pop();
                    widget.onUploadTimetable?.call();
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE500),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.school_outlined, size: 36, color: Colors.black),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Upload your timetable to link quizzes directly to your classes.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onUploadTimetable?.call();
                      },
                      icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                      label: const Text(
                        'Upload timetable',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5500),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.black, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (_isLoadingClasses) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else ...[
                // Normal Quiz Creation / Edit Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class Dropdown Selector
                      const Text(
                        'Class',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          key: const Key('quiz_class_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedClassId,
                          dropdownColor: const Color(0xFFFAF6EE),
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.class_outlined, color: Colors.black, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                          ),
                          items: _availableClasses.map((item) {
                            final color =
                                ncColors.getSubjectColor(item.subjectColorIndex);
                            return DropdownMenuItem<String>(
                              value: item.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.subject} (${item.dayOfWeek} ${item.startTime})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedClassId = val;
                            });
                          },
                          validator: (val) =>
                              val == null ? 'Please select a class' : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quiz Topic / Title (Required)
                      const Text(
                        'Quiz Topic / Title',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: const Key('quiz_title_field'),
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Unit 3, Ch. 4–5, Midterm 1',
                            hintStyle: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.black, size: 22),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a quiz topic or title';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Due Date Picker Tile
                      const Text(
                        'Due Date',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('quiz_date_picker_tile'),
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2.5, 2.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(_selectedDate),
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Note
                      const Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: const Key('quiz_note_field'),
                          controller: _noteController,
                          maxLines: 2,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Bring a calculator, formula sheet allowed',
                            hintStyle: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.notes_rounded, color: Colors.black, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reminder Timing Section
                      const Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Segmented Button: Night before, Morning of quiz, Specific time
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            key: const Key('quiz_reminder_type_segmented'),
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: const BorderSide(color: Colors.black, width: 2.5),
                                ),
                              ),
                              side: WidgetStateProperty.all(
                                const BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                            segments: const [
                              ButtonSegment<String>(
                                value: 'evening_before',
                                label: Text('Night before', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                icon: Icon(Icons.nights_stay_rounded, size: 16),
                              ),
                              ButtonSegment<String>(
                                value: 'morning_of',
                                label: Text('Morning', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                icon: Icon(Icons.wb_sunny_rounded, size: 16),
                              ),
                              ButtonSegment<String>(
                                value: 'custom',
                                label: Text('Specific time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                icon: Icon(Icons.access_time_filled_rounded,
                                    size: 16),
                              ),
                            ],
                            selected: {_reminderType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _reminderType = newSelection.first;
                                if (_reminderType == 'morning_of') {
                                  _reminderTime =
                                      const TimeOfDay(hour: 8, minute: 0);
                                } else if (_reminderType == 'evening_before') {
                                  _reminderTime =
                                      const TimeOfDay(hour: 20, minute: 0);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // If Specific time chosen, show toggle for Day of Quiz vs Night Before
                      if (_reminderType == 'custom') ...[
                        Row(
                          children: [
                            const Text(
                              'Remind on:',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Day of quiz'),
                              selected: _customDay == 'day_of',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _customDay = 'day_of');
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Night before'),
                              selected: _customDay == 'evening_before',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _customDay = 'evening_before');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Interactive Reminder Time Card with Edit Button
                      InkWell(
                        key: const Key('quiz_reminder_time_picker_button'),
                        onTap: _pickReminderTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE500),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.black,
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2.5, 2.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 22,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _reminderType == 'morning_of'
                                          ? 'Morning of quiz at ${_formatTimeOfDay(_reminderTime)}'
                                          : (_reminderType == 'evening_before'
                                              ? 'Night before quiz at ${_formatTimeOfDay(_reminderTime)}'
                                              : 'Reminder set for ${_formatTimeOfDay(_reminderTime)} (${_customDay == 'day_of' ? 'Day of quiz' : 'Night before'})'),
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tap to change time',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimeOfDay(_reminderTime),
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined,
                                        size: 14,
                                        color: Colors.black),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      Container(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(3.5, 3.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            key: const Key('save_quiz_button'),
                            onPressed: _isSaving ? null : _handleSave,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, color: Colors.white),
                            label: Text(
                              isEditing ? 'Save changes' : 'Save quiz',
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5500),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: const BorderSide(color: Colors.black, width: 2.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
