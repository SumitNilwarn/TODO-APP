import 'package:flutter/material.dart';

import '../../../data/api/api_exception.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_inline_alert.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/presentation/authenticated_scaffold.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';
import '../domain/task_validators.dart';
import 'task_error_copy.dart';

/// Task create/edit form.
///
/// With no [task] the screen creates a task (`POST /api/v1/tasks`), letting
/// status default to `TODO` server-side. With a [task] it edits via a partial
/// PATCH that sends only the changed fields — strings set, explicit `null`
/// clears the optional fields, untouched fields are omitted entirely. The
/// status is never edited here; lifecycle changes go through the detail
/// screen's dedicated endpoints.
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, this.task});

  /// The task being edited, or `null` to create a new one.
  final Task? task;

  bool get isEditing => task != null;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  late final TaskApi _api;
  bool _bootstrapped = false;

  DateTime? _dueDate;
  bool _submitting = false;

  /// General submit failure shown above the actions (never backend internals).
  String? _submitError;

  /// Field-level errors surfaced from server validation (400 with details).
  String? _titleError;
  String? _descriptionError;

  Task? get _editingTask => widget.task;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _api = TaskApi(AppScope.apiOf(context));
      final task = _editingTask;
      if (task != null) {
        _title.text = task.title;
        _description.text = task.description ?? '';
        _dueDate = task.dueDate;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_formKey.currentState?.validate() != true) return;

    final title = _title.text.trim();
    final description = _description.text.trim();
    final backing = _editingTask; // Captured before any await completes.

    setState(() {
      _submitting = true;
      _submitError = null;
      _titleError = null;
      _descriptionError = null;
    });

    try {
      final Task saved;
      if (backing == null) {
        // A blank description is rejected by the backend's @NotBlankOrNull, so
        // the client normalizes it to null instead of sending whitespace.
        saved = await _api.createTask(
          CreateTaskRequest(
            title: title,
            description: description.isEmpty ? null : description,
            dueDate: _dueDate,
          ),
        );
      } else {
        final changes = _buildPatch(backing, title, description);
        if (changes.isEmpty) {
          if (mounted) {
            setState(() => _submitting = false);
            AppSnackbar.show(
              context,
              'No changes to save.',
              variant: AppFeedbackVariant.info,
            );
          }
          return;
        }
        saved = await _api.patchTask(backing.id, TaskPatchRequest(changes));
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        final title = _fieldError(error, 'title');
        final description = _fieldError(error, 'description');
        _titleError = title;
        _descriptionError = description;
        // Inline field errors render on their own fields; anything else
        // (including due-date validation) surfaces as the general banner.
        if (title == null && description == null) {
          _submitError = TaskErrorCopy.forSave(error);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'We couldn\'t save your changes. Please try again.';
      });
    }
  }

  /// Computes a PATCH body containing only the changed fields. Optional fields
  /// that were cleared map to explicit `null` (the clear marker), matching the
  /// backend's patch protocol of omitted vs explicit null vs value.
  Map<String, dynamic> _buildPatch(
    Task original,
    String title,
    String description,
  ) {
    final changes = <String, dynamic>{};
    if (title != original.title) {
      changes['title'] = title;
    }
    final newDescription = description.isEmpty ? null : description;
    if (newDescription != original.description) {
      changes['description'] = newDescription;
    }
    if (_dueDate != original.dueDate &&
        !_sameCalendarDay(_dueDate, original.dueDate)) {
      changes['dueDate'] = _dueDate;
    }
    return changes;
  }

  /// Two `YYYY-MM-DD`-style calendar days are compared on y/m/d only, so a
  /// dotted time component (added by the date picker) never falsely counts as
  /// a change.
  static bool _sameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Maps server validation details onto the matching field. `dueDate`
  /// problems surface as a general error (there is no inline date field).
  static String? _fieldError(ApiException error, String field) {
    for (final detail in error.details) {
      if (detail.field == field) return detail.message;
    }
    return null;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      helpText: 'Pick a due date',
      cancelText: 'Cancel',
      confirmText: 'Choose',
    );
    if (selected == null || !mounted) return;
    setState(
      () => _dueDate = DateTime(selected.year, selected.month, selected.day),
    );
  }

  void _clearDueDate() {
    if (_submitting) return;
    setState(() => _dueDate = null);
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedScaffold(
      selectedIndex: 1,
      kicker: 'Editor',
      title: widget.isEditing ? 'Edit task' : 'Create task',
      subtitle: widget.isEditing
          ? 'Update the details of your task.'
          : 'Add a new task to your list.',
      actions: [
        AppButton(
          label: 'Back',
          variant: AppButtonVariant.text,
          icon: Icons.arrow_back_rounded,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ResponsiveContainer(
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: AppCard(
            variant: AppCardVariant.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleField(
                  controller: _title,
                  errorText: _titleError,
                  enabled: !_submitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DescriptionField(
                  controller: _description,
                  errorText: _descriptionError,
                  enabled: !_submitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DueDateField(
                  dueDate: _dueDate,
                  enabled: !_submitting,
                  onPick: _pickDueDate,
                  onClear: _clearDueDate,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppInlineAlert(message: _submitError!),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.text,
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    AppButton(
                      label: widget.isEditing ? 'Save changes' : 'Create task',
                      icon: widget.isEditing
                          ? Icons.save_outlined
                          : Icons.add_rounded,
                      loading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.errorText,
    required this.enabled,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: kTaskTitleMaxLength,
      textCapitalization: TextCapitalization.sentences,
      autofocus: true,
      validator: validateTaskTitle,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Title',
        hintText: 'What needs to be done?',
        helperText: 'A short, clear name for your task.',
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.errorText,
    required this.enabled,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: kTaskDescriptionMaxLength,
      maxLines: 5,
      minLines: 3,
      textCapitalization: TextCapitalization.sentences,
      validator: validateTaskDescription,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: 'Optional details, notes or context',
        helperText: 'Leave empty if your task needs no explanation.',
        alignLabelWithHint: true,
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}

/// Calendar-day selector with an explicit clear affordance.
class _DueDateField extends StatelessWidget {
  const _DueDateField({
    required this.dueDate,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? dueDate;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Due date', style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              label: dueDate == null
                  ? 'Set a due date'
                  : formatTaskDate(dueDate!),
              variant: AppButtonVariant.outlined,
              icon: Icons.calendar_today_outlined,
              onPressed: enabled ? onPick : null,
            ),
            if (dueDate != null)
              AppButton(
                label: 'Clear date',
                variant: AppButtonVariant.text,
                icon: Icons.close_rounded,
                onPressed: enabled ? onClear : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optional. Your task is due at the start of this day.',
          style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
        ),
      ],
    );
  }
}
