import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';
import '../../data/models/quiz_item.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/timetable_repository.dart';
import '../../domain/services/notification_service.dart';
import '../../state/quiz_provider.dart';
import '../shared/bounceable.dart';
import '../shared/nc_banner.dart';
import '../shared/undo_snackbar.dart';

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
      backgroundColor: context.ncColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: context.ncColors.border, width: 3.5),
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

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialQuiz?.title ?? '');
    _noteController =
        TextEditingController(text: widget.initialQuiz?.note ?? '');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = DateTime(today.year, today.month, today.day);

    _selectedClassId = widget.initialQuiz?.classId ?? widget.preselectedClassId;

    _selectedDate = widget.initialQuiz?.dueDate ?? today;

    _resolveClasses();
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
    _normalizeDateForSelectedClass();
  }

  ClassItem? get _selectedClass => _availableClasses.cast<ClassItem?>().firstWhere(
        (item) => item?.id == _selectedClassId,
        orElse: () => null,
      );

  DateTime _nextOccurrence(ClassItem item, DateTime from) {
    var date = DateTime(from.year, from.month, from.day);
    while (date.weekday != item.dayIndex + 1) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  void _normalizeDateForSelectedClass() {
    final selected = _selectedClass;
    if (selected == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (_selectedDate.weekday != selected.dayIndex + 1 || pickedDate.isBefore(today)) {
      _selectedDate = _nextOccurrence(selected, today);
    } else {
      _selectedDate = pickedDate;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedClass = _selectedClass;
    if (selectedClass == null) return;
    final validInitialDate = _selectedDate.weekday == selectedClass.dayIndex + 1 && !_selectedDate.isBefore(today)
        ? _selectedDate
        : _nextOccurrence(selectedClass, today);

    final picked = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      selectableDayPredicate: (date) => date.weekday == selectedClass.dayIndex + 1,
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

    final selectedClass = _selectedClass;
    if (selectedClass == null) return;

    setState(() => _isSaving = true);

    final startParts = selectedClass.startTime.split(':');
    final dueAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.tryParse(startParts.first) ?? 8,
      startParts.length > 1 ? int.tryParse(startParts[1]) ?? 0 : 0,
    );

    final quiz = QuizItem(
      id: widget.initialQuiz?.id ??
          'q_${DateTime.now().millisecondsSinceEpoch}',
      classId: selectedClass.id,
      subject: selectedClass.subject,
      title: _titleController.text.trim(),
      dueDate: dueAt,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      isCompleted: widget.initialQuiz?.isCompleted ?? false,
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
          await NotificationService().rescheduleAll();
        } catch (_) {}
      }

      widget.onSaved?.call(quiz);

      if (mounted) {
        Navigator.of(context).pop(quiz);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        UndoSnackBar.showError(
          context,
          message: 'Failed to save quiz: $e',
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
                    color: ncColors.border,
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
                          border: Border.all(color: ncColors.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: ncColors.shadow,
                              offset: const Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.quiz_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit quiz' : 'Add quiz',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                          color: ncColors.textPrimary,
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
                        color: ncColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ncColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: ncColors.shadow,
                            offset: const Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, size: 18, color: ncColors.textPrimary),
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
                          border: Border.all(color: ncColors.border, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: ncColors.shadow,
                              offset: const Offset(3, 3),
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
                          color: ncColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: ncColors.shadow,
                        offset: const Offset(3, 3),
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
                          side: BorderSide(color: ncColors.border, width: 2.5),
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
                      Text(
                        'Class',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: ncColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: ncColors.shadow,
                              offset: const Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          key: const Key('quiz_class_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedClassId,
                          dropdownColor: ncColors.surface,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            color: ncColors.inputText,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ncColors.inputBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Icon(Icons.class_outlined, color: ncColors.textPrimary, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
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
                                      border: Border.all(color: ncColors.border, width: 1.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.subject} (${item.dayOfWeek} ${item.startTime})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w700,
                                        color: ncColors.textPrimary,
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
                              _normalizeDateForSelectedClass();
                            });
                          },
                          validator: (val) =>
                              val == null ? 'Please select a class' : null,
                        ),
                      ),
                      if (_selectedClass != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Class occurrence time: ${_selectedClass!.startTime}–${_selectedClass!.endTime}',
                            key: const Key('quiz_inherited_class_time'),
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: ncColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Quiz Topic / Title (Required)
                      Text(
                        'Quiz Topic / Title',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: ncColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: ncColors.shadow,
                              offset: const Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: const Key('quiz_title_field'),
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            color: ncColors.inputText,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Unit 3, Ch. 4–5, Midterm 1',
                            hintStyle: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: ncColors.textSecondary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: ncColors.inputBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Icon(Icons.edit_note_rounded, color: ncColors.textPrimary, size: 22),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
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
                      Text(
                        'Due Date',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: ncColors.textPrimary,
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
                            color: ncColors.inputBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ncColors.border, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: ncColors.shadow,
                                offset: const Offset(2.5, 2.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: ncColors.textPrimary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(_selectedDate),
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    color: ncColors.inputText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: ncColors.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Note
                      Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: ncColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: ncColors.shadow,
                              offset: const Offset(2.5, 2.5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          key: const Key('quiz_note_field'),
                          controller: _noteController,
                          maxLines: 2,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w600,
                            color: ncColors.inputText,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Bring a calculator, formula sheet allowed',
                            hintStyle: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              color: ncColors.textSecondary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: ncColors.inputBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Icon(Icons.notes_rounded, color: ncColors.textPrimary, size: 20),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 3.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: ncColors.border, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      Bounceable(
                        onTap: _isSaving ? null : _handleSave,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: ncColors.shadow,
                                offset: const Offset(3.5, 3.5),
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
                                  side: BorderSide(color: ncColors.border, width: 2.5),
                                ),
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
