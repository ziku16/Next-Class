import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/class_item.dart';
import '../../domain/services/notification_service.dart';
import '../../state/timetable_provider.dart';
import '../main_navigation_screen.dart';
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
      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_onboarding', true);
        });
        NotificationService().rescheduleAll();
      } catch (_) {}

      UndoSnackBar.showMessage(
        context,
        message: 'Timetable saved. Chalo!',
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              (route) => false,
            );
          }
        }
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
            backgroundColor: const Color(0xFFFAF6EE),
            appBar: AppBar(
              backgroundColor: const Color(0xFFFAF6EE),
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: const Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                tooltip: 'Back',
                onPressed: _handleBack,
              ),
              title: const Text(
                'Check your classes',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE500),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(color: Colors.black, width: 2.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: _provider.isSaving ? null : _handleSave,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
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

                // "Hide empty days" Toggle Control Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hide empty days',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        Switch(
                          value: _provider.hideEmptyDays,
                          activeThumbColor: Colors.black,
                          activeTrackColor: const Color(0xFFFF5500),
                          inactiveThumbColor: Colors.black,
                          inactiveTrackColor: const Color(0xFFDCE2E6),
                          trackOutlineColor: WidgetStateProperty.all(Colors.black),
                          trackOutlineWidth: WidgetStateProperty.all(2.0),
                          onChanged: (val) => _provider.setHideEmptyDays(val),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 2, thickness: 2, color: Colors.black),

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
              decoration: const BoxDecoration(
                color: Color(0xFFFAF6EE),
                border: Border(
                  top: BorderSide(
                    color: Colors.black,
                    width: 3.0,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Container(
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
                    child: FilledButton(
                      onPressed:
                          _provider.isSaving ? null : _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5500),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.black, width: 2.5),
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
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
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
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => _handleAddClass(day),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE500),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.black,
                  width: 2.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2.5, 2.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'Nothing here yet',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
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
