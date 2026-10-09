import 'package:flutter/material.dart';
import '../../core/theme/next_class_colors.dart';
import '../../data/models/class_item.dart';

/// Modal bottom sheet for adding or editing an individual timetable class.
class EditClassSheet extends StatefulWidget {
  final ClassItem? initialClass;
  final String? defaultDay;
  final int? suggestedColorIndex;

  const EditClassSheet({
    super.key,
    this.initialClass,
    this.defaultDay,
    this.suggestedColorIndex,
  });

  /// Displays the EditClassSheet modal bottom sheet and returns the updated or created ClassItem.
  static Future<ClassItem?> show(
    BuildContext context, {
    ClassItem? initialClass,
    String? defaultDay,
    int? suggestedColorIndex,
  }) {
    final nc = context.ncColors;
    return showModalBottomSheet<ClassItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: nc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: nc.border, width: 3.5),
      ),
      builder: (ctx) => EditClassSheet(
        initialClass: initialClass,
        defaultDay: defaultDay,
        suggestedColorIndex: suggestedColorIndex,
      ),
    );
  }

  @override
  State<EditClassSheet> createState() => _EditClassSheetState();
}

class _EditClassSheetState extends State<EditClassSheet> {
  late String _selectedDay;
  late TextEditingController _subjectController;
  late TextEditingController _roomController;
  late TextEditingController _teacherController;

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialClass;

    _selectedDay = item?.dayOfWeek ??
        widget.defaultDay ??
        ClassItem.daysOfWeek.first;

    _subjectController = TextEditingController(text: item?.subject ?? '');
    _roomController = TextEditingController(text: item?.room ?? '');
    _teacherController = TextEditingController(text: item?.teacher ?? '');

    _startTime = item != null
        ? _parseTimeString(item.startTime)
        : const TimeOfDay(hour: 8, minute: 30);

    _endTime = item != null
        ? _parseTimeString(item.endTime)
        : const TimeOfDay(hour: 9, minute: 20);

    _subjectController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool get _isTimeValid => _toMinutes(_endTime) > _toMinutes(_startTime);

  bool get _isSubjectValid => _subjectController.text.trim().isNotEmpty;

  bool get _canSave => _isSubjectValid && _isTimeValid;

  @override
  void dispose() {
    _subjectController.removeListener(_onFieldChanged);
    _subjectController.dispose();
    _roomController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  String _formatDisplayTimeWithoutPeriod(TimeOfDay time) {
    final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final h = hourOfPeriod.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _toggleStartPeriod() {
    setState(() {
      _startTime = TimeOfDay(
        hour: (_startTime.hour + 12) % 24,
        minute: _startTime.minute,
      );
    });
  }

  void _toggleEndPeriod() {
    setState(() {
      _endTime = TimeOfDay(
        hour: (_endTime.hour + 12) % 24,
        minute: _endTime.minute,
      );
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _saveClass() {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_canSave) return;

    final item = ClassItem(
      id: widget.initialClass?.id ??
          'cls_${DateTime.now().millisecondsSinceEpoch}',
      subject: _subjectController.text.trim(),
      subjectColorIndex: widget.initialClass?.subjectColorIndex ??
          widget.suggestedColorIndex ??
          (_subjectController.text.trim().hashCode.abs() % 8),
      dayOfWeek: _selectedDay,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      room: _roomController.text.trim().isNotEmpty
          ? _roomController.text.trim()
          : null,
      teacher: _teacherController.text.trim().isNotEmpty
          ? _teacherController.text.trim()
          : null,
      isAiUnsure: false, // User confirmed and saved
    );

    Navigator.of(context).pop(item);
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialClass != null;
    final nc = context.ncColors;

    final showSubjectError =
        _hasAttemptedSubmit && _subjectController.text.trim().isEmpty;
    final showTimeError = !_isTimeValid;

    return Container(
      color: nc.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Center drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: nc.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit class' : 'Add class',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: nc.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: nc.border, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: nc.shadow,
                            offset: const Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, size: 18, color: nc.icon),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Day Dropdown
              Text(
                'Day',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: nc.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDay,
                  dropdownColor: nc.surface,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: nc.inputBackground,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 3.0),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                  items: ClassItem.daysOfWeek.map((day) {
                    return DropdownMenuItem(
                      value: day,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700,
                          color: nc.inputText,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDay = val);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Subject name field
              Text(
                'Subject',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: nc.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _subjectController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    color: nc.inputText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Mathematics, Physics',
                    hintStyle: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: nc.textSecondary,
                    ),
                    errorText: showSubjectError ? 'Add a subject name' : null,
                    filled: true,
                    fillColor: nc.inputBackground,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 3.0),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Start & End Time Pickers Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Starts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Starts',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: nc.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          key: const Key('start_time_tile'),
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: nc.surface,
                              border: Border.all(color: nc.border, width: 2.5),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: nc.shadow,
                                  offset: const Offset(2.5, 2.5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: nc.icon,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDisplayTimeWithoutPeriod(_startTime),
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: nc.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  key: const Key('start_period_btn'),
                                  onTap: _toggleStartPeriod,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE500),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: nc.border, width: 1.5),
                                    ),
                                    child: Text(
                                      _startTime.period == DayPeriod.am ? 'AM' : 'PM',
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Ends
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ends',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: nc.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          key: const Key('end_time_tile'),
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: nc.surface,
                              border: Border.all(
                                color: showTimeError
                                    ? const Color(0xFFFF1744)
                                    : nc.border,
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: nc.shadow,
                                  offset: const Offset(2.5, 2.5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: showTimeError
                                          ? const Color(0xFFFF1744)
                                          : nc.icon,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDisplayTimeWithoutPeriod(_endTime),
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: showTimeError
                                            ? const Color(0xFFFF1744)
                                            : nc.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  key: const Key('end_period_btn'),
                                  onTap: _toggleEndPeriod,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: showTimeError
                                          ? const Color(0xFFFFCDD2)
                                          : const Color(0xFFFFE500),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: nc.border, width: 1.5),
                                    ),
                                    child: Text(
                                      _endTime.period == DayPeriod.am ? 'AM' : 'PM',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: showTimeError
                                            ? const Color(0xFFFF1744)
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showTimeError) ...[
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Color(0xFFFF1744),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Must be after start',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF1744),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Room (optional)
              Text(
                'Room (optional)',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: nc.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _roomController,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    color: nc.inputText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Room B-12, Lab 2',
                    hintStyle: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: nc.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.meeting_room_outlined, size: 20, color: nc.icon),
                    filled: true,
                    fillColor: nc.inputBackground,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 3.0),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Teacher (optional)
              Text(
                'Teacher (optional)',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: nc.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nc.shadow,
                      offset: const Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _teacherController,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    color: nc.inputText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Ms. Sara, Dr. John',
                    hintStyle: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: nc.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.person_outline, size: 20, color: nc.icon),
                    filled: true,
                    fillColor: nc.inputBackground,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 3.0),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: nc.border, width: 2.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Save class button (disabled until subject is non-empty and End > Start)
              Container(
                decoration: BoxDecoration(
                  boxShadow: _canSave
                      ? [
                          BoxShadow(
                            color: nc.shadow,
                            offset: const Offset(3.5, 3.5),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _canSave ? _saveClass : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _canSave
                          ? const Color(0xFFFF5500)
                          : const Color(0xFFDCE2E6),
                      foregroundColor:
                          _canSave ? Colors.white : nc.textSecondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: _canSave ? nc.border : nc.border.withValues(alpha: 0.3),
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      'Save class',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: _canSave ? Colors.white : nc.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
