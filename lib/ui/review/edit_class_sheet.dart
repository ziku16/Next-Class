import 'package:flutter/material.dart';
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
    return showModalBottomSheet<ClassItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialClass != null;

    final showSubjectError =
        _hasAttemptedSubmit && _subjectController.text.trim().isEmpty;
    final showTimeError = !_isTimeValid;

    return Padding(
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
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Day Dropdown
            Text(
              'Day',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedDay,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ClassItem.daysOfWeek.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(day),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDay = val);
              },
            ),
            const SizedBox(height: 16),

            // Subject name field
            Text(
              'Subject',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _subjectController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Mathematics, Physics',
                errorText: showSubjectError ? 'Add a subject name' : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('start_time_tile'),
                        onTap: _pickStartTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimeOfDay(_startTime),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('end_time_tile'),
                        onTap: _pickEndTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: showTimeError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 18,
                                color: showTimeError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimeOfDay(_endTime),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: showTimeError
                                      ? theme.colorScheme.error
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showTimeError) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Must be after start',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
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
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                hintText: 'e.g. Room B-12, Lab 2',
                prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teacher (optional)
            Text(
              'Teacher (optional)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _teacherController,
              decoration: InputDecoration(
                hintText: 'e.g. Ms. Sara, Dr. John',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save class button (disabled until subject is non-empty and End > Start)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _canSave ? _saveClass : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save class'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
