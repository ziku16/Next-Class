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

  /// Displays the AddEditQuizSheet in a 28 dp rounded modal sheet
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit quiz' : 'Add quiz',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
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
                      Icon(
                        Icons.school_outlined,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload your timetable to link quizzes directly to your classes.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onUploadTimetable?.call();
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload timetable'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                      Text(
                        'Class',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: const Key('quiz_class_dropdown'),
                        isExpanded: true,
                        initialValue: _selectedClassId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.class_outlined),
                        ),
                        items: _availableClasses.map((item) {
                          final color =
                              ncColors.getSubjectColor(item.subjectColorIndex);
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.subject} (${item.dayOfWeek} ${item.startTime})',
                                    overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 16),

                      // Quiz Topic / Title (Required)
                      Text(
                        'Quiz Topic / Title',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('quiz_title_field'),
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'e.g. Unit 3, Ch. 4–5, Midterm 1',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a quiz topic or title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Due Date Picker Tile
                      Text(
                        'Due Date',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('quiz_date_picker_tile'),
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(_selectedDate),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Note
                      Text(
                        'Notes (optional)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('quiz_note_field'),
                        controller: _noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Bring a calculator, formula sheet allowed',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reminder Timing Section
                      Text(
                        'Reminder Time',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Segmented Button: Night before, Morning of quiz, Specific time
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          key: const Key('quiz_reminder_type_segmented'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<String>(
                              value: 'evening_before',
                              label: Text('Night before'),
                              icon: Icon(Icons.nights_stay_rounded, size: 16),
                            ),
                            ButtonSegment<String>(
                              value: 'morning_of',
                              label: Text('Morning'),
                              icon: Icon(Icons.wb_sunny_rounded, size: 16),
                            ),
                            ButtonSegment<String>(
                              value: 'custom',
                              label: Text('Specific time'),
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
                      const SizedBox(height: 10),

                      // If Specific time chosen, show toggle for Day of Quiz vs Night Before
                      if (_reminderType == 'custom') ...[
                        Row(
                          children: [
                            Text(
                              'Remind on:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
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
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.tertiary
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 20,
                                color: theme.colorScheme.tertiary,
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
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme
                                            .colorScheme.onTertiaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to change time',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onTertiaryContainer
                                            .withValues(alpha: 0.8),
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
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimeOfDay(_reminderTime),
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit_outlined,
                                        size: 14,
                                        color: theme.colorScheme.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
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
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            isEditing ? 'Save changes' : 'Save quiz',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
