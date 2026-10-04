import 'package:flutter/material.dart';
import '../../data/models/class_item.dart';
import '../../state/timetable_provider.dart';
import '../shared/class_card.dart';
import '../shared/nc_banner.dart';
import '../shared/undo_snackbar.dart';
import 'discard_dialog.dart';
import 'edit_class_sheet.dart';

/// Screen for reviewing, verifying, and editing extracted or manually created timetable classes.
class ReviewScreen extends StatefulWidget {
  final List<ClassItem>? initialClasses;
  final TimetableProvider? timetableProvider;
  final VoidCallback? onSaved;
  final VoidCallback? onDiscard;

  const ReviewScreen({
    super.key,
    this.initialClasses,
    this.timetableProvider,
    this.onSaved,
    this.onDiscard,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late TimetableProvider _provider;
  bool _showAiWarning = true;

  @override
  void initState() {
    super.initState();
    _provider = widget.timetableProvider ??
        TimetableProvider(initialClasses: widget.initialClasses ?? []);
  }

  Future<void> _handleBack() async {
    if (_provider.hasUnsavedChanges) {
      final shouldDiscard = await DiscardDialog.show(context);
      if (shouldDiscard && mounted) {
        if (widget.onDiscard != null) {
          widget.onDiscard!();
        } else {
          Navigator.of(context).pop(false);
        }
      }
    } else {
      if (widget.onDiscard != null) {
        widget.onDiscard!();
      } else {
        Navigator.of(context).pop(false);
      }
    }
  }

  Future<void> _handleSave() async {
    final success = await _provider.saveTimetable();
    if (!mounted) return;

    if (success) {
      UndoSnackBar.showMessage(
        context,
        message: 'Timetable saved. Chalo!',
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save timetable. Try again.')),
      );
    }
  }

  Future<void> _handleAddClass(String day) async {
    final newClass = await EditClassSheet.show(
      context,
      defaultDay: day,
      suggestedColorIndex: _provider.classes.length % 8,
    );
    if (newClass != null && mounted) {
      _provider.addClass(newClass);
    }
  }

  Future<void> _handleEditClass(ClassItem item) async {
    final updatedClass = await EditClassSheet.show(
      context,
      initialClass: item,
    );
    if (updatedClass != null && mounted) {
      _provider.updateClass(updatedClass);
    }
  }

  void _handleDeleteClass(ClassItem item) {
    _provider.deleteClass(item.id);

    UndoSnackBar.show(
      context,
      message: 'Class deleted',
      onUndo: () {
        _provider.restoreClass(item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleBack();
          },
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: _handleBack,
              ),
              title: const Text('Check your classes'),
              centerTitle: false,
              actions: [
                TextButton(
                  onPressed: _provider.isSaving ? null : _handleSave,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                // Top AI Confidence Warning Banner
                if (_provider.hasAiUnsureClasses && _showAiWarning) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: NcBanner.aiWarning(
                      onDismiss: () => setState(() => _showAiWarning = false),
                    ),
                  ),
                ],

                // "Hide empty days" Toggle Switch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hide empty days',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Switch(
                        value: _provider.hideEmptyDays,
                        onChanged: (val) => _provider.setHideEmptyDays(val),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Grouped Day-by-Day List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      for (final day in ClassItem.daysOfWeek)
                        _buildDaySection(context, day),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        _provider.isSaving ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _provider.isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save timetable',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDaySection(BuildContext context, String day) {
    final theme = Theme.of(context);
    final dayClasses = _provider.getClassesForDay(day);

    if (_provider.hideEmptyDays && dayClasses.isEmpty) {
      return const SizedBox.shrink();
    }

    final countLabel = dayClasses.length == 1
        ? '1 class'
        : '${dayClasses.length} classes';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header with counter & Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$day · $countLabel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Add class to $day',
                onPressed: () => _handleAddClass(day),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day items or empty placeholder
          if (dayClasses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Text(
                'Nothing here yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...dayClasses.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClassCard(
                  classItem: item,
                  state: ClassCardState.editable,
                  enableSwipeToDelete: true,
                  onEdit: () => _handleEditClass(item),
                  onDelete: () => _handleDeleteClass(item),
                ),
              );
            }),
        ],
      ),
    );
  }
}
