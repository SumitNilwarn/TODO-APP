import 'package:flutter/material.dart';

import '../../../data/api/api_exception.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/presentation/authenticated_scaffold.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';
import 'task_error_copy.dart';
import 'task_form_page.dart';

/// Task detail screen (`/tasks/{taskId}`).
///
/// Loads the task from the backend, presents its full state, and hosts the
/// lifecycle actions (start / complete / cancel), plus edit and delete. Status
/// transitions go through the dedicated endpoints so the backend enforces the
/// lifecycle and owns `completedAt`.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

/// Identifies the currently in-flight action so each button can disable itself
/// and show its own spinner, preventing duplicate submissions.
enum _DetailAction { start, complete, cancel, delete }

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final TaskApi _api;
  bool _bootstrapped = false;

  bool _loading = true;
  String? _loadError;

  Task? _task;
  _DetailAction? _busyAction;
  bool _mutated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _api = TaskApi(AppScope.apiOf(context));
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final task = await _api.getTask(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = TaskErrorCopy.forLoad(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load this task. Please try again.';
      });
    }
  }

  /// Applies the returned version of the task after a successful write,
  /// records that a mutation happened (so the list refreshes on back), and
  /// shows success feedback.
  void _applyMutation(Task updated, String message) {
    setState(() {
      _task = updated;
      _busyAction = null;
      _mutated = true;
    });
    AppSnackbar.show(context, message, variant: AppFeedbackVariant.success);
  }

  void _showSaveError(ApiException error) {
    final message = TaskErrorCopy.forSave(error);
    final recoverable =
        error.code == 'OPTIMISTIC_LOCK_CONFLICT' ||
        error.code == 'INVALID_TRANSITION';
    AppSnackbar.show(
      context,
      message,
      variant: AppFeedbackVariant.danger,
      actionLabel: recoverable ? 'Refresh' : null,
      onAction: recoverable ? _load : null,
    );
  }

  Future<void> _run(
    _DetailAction action,
    Future<Task> Function() operation,
    String successMessage,
  ) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      final updated = await operation();
      if (!mounted) return;
      _applyMutation(updated, successMessage);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      _showSaveError(error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      if (mounted) {
        AppSnackbar.show(
          context,
          'Something went wrong. Please try again.',
          variant: AppFeedbackVariant.danger,
        );
      }
    }
  }

  Future<void> _start() => _run(
    _DetailAction.start,
    () => _api.updateTaskStatus(widget.taskId, TaskStatus.inProgress),
    'Task started.',
  );

  Future<void> _complete() => _run(
    _DetailAction.complete,
    () => _api.completeTask(widget.taskId),
    'Task completed.',
  );

  Future<void> _cancel() async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'Cancel task',
      message:
          'This task will be marked as cancelled. You can still edit or '
          'delete it later.',
      confirmLabel: 'Cancel task',
      icon: Icons.block_rounded,
    );
    if (!confirmed || !mounted) return;
    await _run(
      _DetailAction.cancel,
      () => _api.cancelTask(widget.taskId),
      'Task cancelled.',
    );
  }

  Future<void> _delete() async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'Delete task',
      message:
          'This permanently deletes the task and its history. '
          'This action cannot be undone.',
      confirmLabel: 'Delete task',
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyAction = _DetailAction.delete);
    try {
      await _api.deleteTask(widget.taskId);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Task deleted.',
        variant: AppFeedbackVariant.success,
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      _showSaveError(error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      if (mounted) {
        AppSnackbar.show(
          context,
          'The task could not be deleted. Please try again.',
          variant: AppFeedbackVariant.danger,
        );
      }
    }
  }

  Future<void> _edit() async {
    final task = _task;
    if (task == null || _busyAction != null) return;
    final updated = await Navigator.of(
      context,
    ).push<Task?>(MaterialPageRoute(builder: (_) => TaskFormPage(task: task)));
    if (updated == null || !mounted) return;
    _applyMutation(updated, 'Task updated.');
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedScaffold(
      selectedIndex: 1,
      kicker: 'Details',
      title: 'Task',
      subtitle: _task?.title ?? 'Details',
      actions: [
        AppButton(
          label: 'Back to tasks',
          variant: AppButtonVariant.text,
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(_mutated),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const AppLoading(label: 'Loading task…');
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.giant),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppErrorState(
              title: 'Could not load this task',
              message: _loadError,
              onRetry: _load,
            ),
          ),
        ),
      );
    }
    final task = _task;
    if (task == null) {
      return const AppLoading(label: 'Loading task…');
    }

    return ResponsiveContainer(
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TaskHeaderCard(task: task),
            const SizedBox(height: AppSpacing.md),
            _DetailActions(
              task: task,
              busyAction: _busyAction,
              onStart: _start,
              onComplete: _complete,
              onCancel: _cancel,
              onEdit: _edit,
              onDelete: _delete,
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailMetadataCard(task: task),
          ],
        ),
      ),
    );
  }
}

class _TaskHeaderCard extends StatelessWidget {
  const _TaskHeaderCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    final description = task.description?.trim();
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusBadge(status: task.status),
              if (task.overdue)
                const AppBadge(
                  'Overdue',
                  variant: AppBadgeVariant.danger,
                  icon: Icons.error_outline_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            task.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: textTheme.bodyLarge?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (variant, icon) = switch (status) {
      TaskStatus.todo => (
        AppBadgeVariant.neutral,
        Icons.radio_button_unchecked,
      ),
      TaskStatus.inProgress => (
        AppBadgeVariant.info,
        Icons.play_circle_outline_rounded,
      ),
      TaskStatus.completed => (
        AppBadgeVariant.success,
        Icons.check_circle_outline_rounded,
      ),
      TaskStatus.cancelled => (AppBadgeVariant.neutral, Icons.block_rounded),
    };
    return AppBadge(status.label, variant: variant, icon: icon);
  }
}

/// Lifecycle + management actions. Lifecycle actions disappear on terminal
/// tasks; edit/delete always remain (the backend still permits them).
class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.task,
    required this.busyAction,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final _DetailAction? busyAction;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final busy = busyAction != null;

    final lifecycle = <Widget>[
      if (task.canStart)
        AppButton(
          key: const ValueKey('detail-action-start'),
          label: 'Start',
          variant: AppButtonVariant.outlined,
          icon: Icons.play_arrow_rounded,
          loading: busyAction == _DetailAction.start,
          onPressed: busy ? null : onStart,
        ),
      if (task.canComplete)
        AppButton(
          key: const ValueKey('detail-action-complete'),
          label: 'Complete',
          icon: Icons.check_rounded,
          loading: busyAction == _DetailAction.complete,
          onPressed: busy ? null : onComplete,
        ),
      if (task.canCancel)
        AppButton(
          key: const ValueKey('detail-action-cancel'),
          label: 'Cancel task',
          variant: AppButtonVariant.outlined,
          icon: Icons.block_rounded,
          loading: busyAction == _DetailAction.cancel,
          onPressed: busy ? null : onCancel,
        ),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...lifecycle,
        AppButton(
          key: const ValueKey('detail-action-edit'),
          label: 'Edit',
          variant: AppButtonVariant.outlined,
          icon: Icons.edit_outlined,
          onPressed: busy ? null : onEdit,
        ),
        AppButton(
          key: const ValueKey('detail-action-delete'),
          label: 'Delete',
          variant: AppButtonVariant.destructive,
          icon: Icons.delete_outline_rounded,
          loading: busyAction == _DetailAction.delete,
          onPressed: busy ? null : onDelete,
        ),
      ],
    );
  }
}

/// Read-only metadata rows: due date, created/updated/completed timestamps.
class _DetailMetadataCard extends StatelessWidget {
  const _DetailMetadataCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tokens.textMuted),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            Icons.event_outlined,
            'Due date',
            task.dueDate == null
                ? 'No due date'
                : formatTaskDate(task.dueDate!),
          ),
          const Divider(height: 1),
          row(Icons.playlist_add_check_rounded, 'Status', task.status.label),
          const Divider(height: 1),
          row(
            Icons.add_circle_outline_rounded,
            'Created',
            formatTaskInstant(task.createdAt),
          ),
          const Divider(height: 1),
          row(
            Icons.update_rounded,
            'Updated',
            formatTaskInstant(task.updatedAt),
          ),
          if (task.completedAt != null) ...[
            const Divider(height: 1),
            row(
              Icons.task_alt_rounded,
              'Completed',
              formatTaskInstant(task.completedAt!),
            ),
          ],
        ],
      ),
    );
  }
}
