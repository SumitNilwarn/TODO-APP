import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/responsive.dart';
import '../../../data/api/api_exception.dart';
import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/motion/app_skeleton.dart';
import '../../../shared/widgets/motion/fade_entrance.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/presentation/authenticated_scaffold.dart';
import '../data/task_api.dart';
import '../domain/task_list_query.dart';
import '../domain/task_models.dart';
import '../domain/task_validators.dart';
import 'task_error_copy.dart';
import 'task_form_page.dart';

/// Debounce interval for search keystrokes (milliseconds).
const int _kSearchDebounceMs = 300;

/// Task list screen: one bounded, filterable, sortable, searchable page of the
/// caller's tasks with create entry-points, pagination and deep links into
/// detail.
///
/// Every fetch is a single backend page (`GET /api/v1/tasks` with the full
/// query-param set); the user id never leaves the client because ownership is
/// resolved server-side. All search/filter/sort operations are server-backed —
/// no local re-filtering of an unbounded list happens.
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TaskApi _api;
  bool _bootstrapped = false;

  bool _loading = true;
  bool _refreshing = false;
  String? _loadError;

  TaskPage? _page;

  /// Single source of truth for the current listing query.
  TaskListQuery _query = const TaskListQuery();

  /// Search debounce timer.
  Timer? _debounceTimer;

  /// Text controller for the search field.
  final _searchController = TextEditingController();

  /// Focus node for the search field.
  final _searchFocusNode = FocusNode();

  /// Monotonically increasing id — stale responses are silently discarded.
  int _requestId = 0;

  /// Client-side validation error for an invalid due-date range.
  String? _dateRangeError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _api = TaskApi(AppScope.apiOf(context));
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _load({bool keepContent = false}) async {
    if (keepContent && _refreshing) return;
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        if (!keepContent) {
          _loading = true;
        } else {
          _refreshing = true;
        }
        _loadError = null;
      });
    }
    try {
      final result = await _api.listTasksFromQuery(_query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _page = result;
        _loading = false;
        _refreshing = false;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (!keepContent) {
          _loadError = TaskErrorCopy.forLoad(error);
        }
      });
      if (keepContent && mounted) {
        AppSnackbar.show(
          context,
          'Refresh failed. ${TaskErrorCopy.forLoad(error)}',
          variant: AppFeedbackVariant.danger,
        );
      }
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (!keepContent) {
          _loadError = 'Could not load your tasks. Please try again.';
        }
      });
      if (keepContent && mounted) {
        AppSnackbar.show(
          context,
          'Refresh failed. Please try again.',
          variant: AppFeedbackVariant.danger,
        );
      }
    }
  }

  Future<void> _refresh() => _load(keepContent: true);

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: _kSearchDebounceMs),
      () {
        final trimmed = value.trim();
        if (trimmed.length > kTaskSearchMaxLength) return;
        if (trimmed == _query.search) return;
        setState(() => _query = _query.copyWith(search: trimmed).resetPage());
        _load();
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    if (_query.search.isEmpty) return;
    setState(() => _query = _query.copyWith(search: '').resetPage());
    _load();
  }

  // ---------------------------------------------------------------------------
  // Filter / sort helpers
  // ---------------------------------------------------------------------------

  void _setStatus(TaskStatus? status) {
    final next = _query.copyWith(status: () => status).resetPage();
    if (next == _query) return;
    setState(() => _query = next);
    _load();
  }

  void _setOverdue(bool value) {
    final next = _query.copyWith(overdue: value).resetPage();
    if (next == _query) return;
    setState(() => _query = next);
    _load();
  }

  void _setSort(TaskSortField field) {
    final next = _query.copyWith(sort: field).resetPage();
    if (next == _query) return;
    setState(() => _query = next);
    _load();
  }

  void _toggleDirection() {
    final next = _query
        .copyWith(direction: _query.direction == 'ASC' ? 'DESC' : 'ASC')
        .resetPage();
    setState(() => _query = next);
    _load();
  }

  void _setDueDateRange(DateTime? from, DateTime? to) {
    String? error;
    if (from != null && to != null && from.isAfter(to)) {
      error = 'Start date must not be after end date.';
    }
    setState(() {
      _dateRangeError = error;
      _query = _query
          .copyWith(dueDateFrom: () => from, dueDateTo: () => to)
          .resetPage();
    });
    if (error == null) _load();
  }

  void _clearFilters() {
    setState(() {
      _query = _query.clearFilters();
      _dateRangeError = null;
      _searchController.clear();
    });
    _load();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> _openDetail(Task task) async {
    final changed = await Navigator.of(context)
        .pushNamed<bool>(AppRouter.taskDetailFor(task.id));
    if (changed == true && mounted) {
      _load(keepContent: true).then((_) {
        final current = _page;
        if (current == null || current.tasks.isNotEmpty) return;
        if (current.page > 0) {
          setState(() => _query = _query.copyWith(page: current.page - 1));
          _load();
        }
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context)
        .push<Task?>(MaterialPageRoute(builder: (_) => const TaskFormPage()));
    if (created == null || !mounted) return;
    setState(() => _query = _query.copyWith(page: 0));
    _load();
    AppSnackbar.show(
      context,
      'Task created.',
      variant: AppFeedbackVariant.success,
    );
  }

  Future<void> _goToPage(int index) async {
    if (index == _query.page || _loading) return;
    setState(() => _query = _query.copyWith(page: index));
    _load();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AuthenticatedScaffold(
      selectedIndex: 1,
      title: 'Tasks',
      subtitle: 'Your to-do list.',
      actions: [
        IconButton(
          key: const Key('tasks-refresh'),
          tooltip: 'Refresh tasks',
          onPressed: _loading || _refreshing ? null : _refresh,
          icon: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        AppButton(
          label: 'Create task',
          icon: Icons.add_rounded,
          onPressed: _loading ? null : _openCreate,
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _page == null) {
      return const TasksSkeleton();
    }

    final page = _page;
    if (_loadError != null && page == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.giant),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeEntrance(
              duration: const Duration(milliseconds: 380),
              child: AppErrorState(
                title: 'Could not load your tasks',
                message: _loadError,
                onRetry: () {
                  setState(() => _query = _query.copyWith(page: 0));
                  _load();
                },
              ),
            ),
          ),
        ),
      );
    }

    if (page == null) {
      return const TasksSkeleton();
    }

    if (page.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.giant),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeEntrance(
              duration: const Duration(milliseconds: 380),
              child: _buildEmptyState(),
            ),
          ),
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            const SizedBox(height: AppSpacing.md),
            FadeEntrance(
              delay: const Duration(milliseconds: 90),
              duration: const Duration(milliseconds: 380),
              child: _TaskControls(
                query: _query,
                dateRangeError: _dateRangeError,
                onStatusChanged: _setStatus,
                onOverdueChanged: _setOverdue,
                onSortChanged: _setSort,
                onDirectionToggled: _toggleDirection,
                onDateRangeChanged: _setDueDateRange,
                onClearFilters: _clearFilters,
              ),
            ),
            if (_refreshing) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: AppSpacing.md),
            // The whole page of tiles cross-fades when the dataset changes
            // (search/filter/sort/page/create/delete), so rows never pop.
            AnimatedSwitcher(
              duration: AppDurations.normal,
              switchInCurve: AppCurves.enter,
              switchOutCurve: AppCurves.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.012),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_listSignature(page)),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < page.tasks.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: AppSpacing.lg,
                            endIndent: AppSpacing.lg,
                          ),
                        _TaskListTile(
                          task: page.tasks[i],
                          onTap: () => _openDetail(page.tasks[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PaginationFooter(
              page: page,
              loading: _loading,
              onPrevious: page.first ? null : () => _goToPage(page.page - 1),
              onNext: page.last ? null : () => _goToPage(page.page + 1),
            ),
          ],
        ),
      ),
    );
  }

  /// Stable identity for the visible list: page number, element count and the
  /// exact row ids. Identical payloads produce no cross-fade.
  String _listSignature(TaskPage page) {
    final ids = page.tasks.map((t) => t.id).join(',');
    return '${page.pageNumber}|${page.totalElements}|$ids';
  }

  Widget _buildEmptyState() {
    final hasFilters = _query.hasActiveFilters;
    final hasSearch = _query.search.trim().isNotEmpty;
    if (hasSearch) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No tasks match your search',
        message: 'Try a different search term or clear your filters.',
        action: AppButton(
          label: 'Clear search',
          variant: AppButtonVariant.outlined,
          onPressed: _clearSearch,
        ),
      );
    }
    if (hasFilters) {
      return AppEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No tasks match your current filters',
        message: 'Try adjusting or clearing your filters.',
        action: AppButton(
          label: 'Clear filters',
          variant: AppButtonVariant.outlined,
          onPressed: _clearFilters,
        ),
      );
    }
    return AppEmptyState(
      icon: Icons.checklist_rounded,
      title: 'You have no tasks yet',
      message: 'Create your first task to get started.',
      action: AppButton(
        label: 'Create task',
        icon: Icons.add_rounded,
        onPressed: _openCreate,
      ),
    );
  }
}

// =============================================================================
// Search bar
// =============================================================================

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      hintText: 'Search tasks',
      prefixIcon: Icons.search_rounded,
      maxLength: kTaskSearchMaxLength,
      textInputAction: TextInputAction.search,
      suffix: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) {
          if (value.text.isEmpty) return const SizedBox.shrink();
          return IconButton(
            key: const Key('search-clear'),
            tooltip: 'Clear search',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Controls: status, overdue, sort, due-date range, clear filters
// =============================================================================

class _TaskControls extends StatelessWidget {
  const _TaskControls({
    required this.query,
    required this.dateRangeError,
    required this.onStatusChanged,
    required this.onOverdueChanged,
    required this.onSortChanged,
    required this.onDirectionToggled,
    required this.onDateRangeChanged,
    required this.onClearFilters,
  });

  final TaskListQuery query;
  final String? dateRangeError;
  final ValueChanged<TaskStatus?> onStatusChanged;
  final ValueChanged<bool> onOverdueChanged;
  final ValueChanged<TaskSortField> onSortChanged;
  final VoidCallback onDirectionToggled;
  final void Function(DateTime? from, DateTime? to) onDateRangeChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < AppBreakpoints.tablet;

    if (isCompact) {
      return _buildCompactControls(context, tokens);
    }
    return _buildDesktopControls(context, tokens);
  }

  Widget _buildDesktopControls(BuildContext context, AppThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildStatusChips()),
            const SizedBox(width: AppSpacing.md),
            _buildSortControls(context, tokens),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildOverdueChip(tokens),
            _buildDateRangeChip(context, tokens),
            if (query.hasActiveFilters)
              TextButton(
                key: const Key('clear-filters'),
                onPressed: onClearFilters,
                child: Text(
                  'Clear filters',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
          ],
        ),
        if (dateRangeError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateRangeError!,
            style: TextStyle(
              color: tokens.danger,
              fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactControls(BuildContext context, AppThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusChips(),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildOverdueChip(tokens),
            _buildDateRangeChip(context, tokens),
            _buildSortControls(context, tokens),
          ],
        ),
        if (query.hasActiveFilters) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('clear-filters'),
              onPressed: onClearFilters,
              child: Text(
                'Clear filters',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          ),
        ],
        if (dateRangeError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateRangeError!,
            style: TextStyle(
              color: tokens.danger,
              fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChips() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppChoiceChip(
            label: 'All',
            selected: query.status == null,
            onSelected: () => onStatusChanged(null),
          ),
          for (final status in TaskStatus.values)
            AppChoiceChip(
              label: status.label,
              selected: query.status == status,
              onSelected: () => onStatusChanged(status),
            ),
        ],
      ),
    );
  }

  Widget _buildOverdueChip(AppThemeTokens tokens) {
    return AppFilterChip(
      label: 'Overdue only',
      selected: query.overdue,
      onSelected: onOverdueChanged,
      activeColor: tokens.danger,
    );
  }

  Widget _buildDateRangeChip(BuildContext context, AppThemeTokens tokens) {
    final hasRange = query.dueDateFrom != null || query.dueDateTo != null;
    final label = hasRange ? _formatDateRange() : 'Due date';

    return ActionChip(
      avatar: Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: hasRange ? tokens.primary : tokens.textSecondary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: hasRange ? tokens.primary : tokens.textSecondary,
        ),
      ),
      onPressed: () => _showDateRangeSheet(context),
    );
  }

  String _formatDateRange() {
    final from = query.dueDateFrom;
    final to = query.dueDateTo;
    if (from != null && to != null) {
      return '${_fmtDate(from)} – ${_fmtDate(to)}';
    }
    if (from != null) return 'From ${_fmtDate(from)}';
    return 'To ${_fmtDate(to!)}';
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Future<void> _showDateRangeSheet(BuildContext context) async {
    DateTime? from = query.dueDateFrom;
    DateTime? to = query.dueDateTo;

    final result = await showModalBottomSheet<_DateRangeResult>(
      context: context,
      builder: (context) => _DateRangeSheet(initialFrom: from, initialTo: to),
    );
    if (result != null) {
      onDateRangeChanged(result.from, result.to);
    }
  }

  Widget _buildSortControls(BuildContext context, AppThemeTokens tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<TaskSortField>(
          value: query.sort,
          underline: const SizedBox.shrink(),
          icon: Icon(Icons.arrow_drop_down_rounded, color: tokens.textMuted),
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
          ),
          items: TaskSortField.values.map((field) {
            return DropdownMenuItem(value: field, child: Text(field.label));
          }).toList(),
          onChanged: (field) {
            if (field != null) onSortChanged(field);
          },
        ),
        IconButton(
          key: const Key('sort-direction'),
          tooltip: query.direction == 'ASC'
              ? 'Sort ascending'
              : 'Sort descending',
          onPressed: onDirectionToggled,
          icon: Icon(
            query.direction == 'ASC'
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: tokens.textMuted,
            size: 20,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Date range picker bottom sheet
// =============================================================================

class _DateRangeResult {
  const _DateRangeResult({this.from, this.to});
  final DateTime? from;
  final DateTime? to;
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({required this.initialFrom, required this.initialTo});
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      helpText: 'Due date from',
      cancelText: 'Cancel',
      confirmText: 'Choose',
    );
    if (picked != null) {
      setState(() => _from = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      helpText: 'Due date to',
      cancelText: 'Cancel',
      confirmText: 'Choose',
    );
    if (picked != null) {
      setState(() => _to = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Due date range',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_from != null ? _fmtDate(_from!) : 'From'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_to != null ? _fmtDate(_to!) : 'To'),
                ),
              ),
            ],
          ),
          if (_from != null || _to != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                Navigator.of(context)
                    .pop(const _DateRangeResult(from: null, to: null));
              },
              child: Text(
                'Clear dates',
                style: TextStyle(color: tokens.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Apply',
                onPressed: () {
                  Navigator.of(context)
                      .pop(_DateRangeResult(from: _from, to: _to));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// =============================================================================
// Task tile
// =============================================================================

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Semantics(
      button: true,
      label: '${task.title}. Status ${task.status.label}. ${task.dueLabel}',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        radius: AppRadius.lgAll,
        interactive: true,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.dueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  if ((task.description?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
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
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
          ],
        ),
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

// =============================================================================
// Pagination footer
// =============================================================================

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.page,
    required this.loading,
    this.onPrevious,
    this.onNext,
  });

  final TaskPage page;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    final total = page.totalElements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            AppButton(
              label: 'Previous',
              variant: AppButtonVariant.outlined,
              icon: Icons.chevron_left_rounded,
              onPressed: loading ? null : onPrevious,
            ),
            Text(
              'Page ${page.pageNumber} of ${page.totalPages}',
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
            AppButton(
              label: 'Next',
              variant: AppButtonVariant.outlined,
              icon: Icons.chevron_right_rounded,
              onPressed: loading ? null : onNext,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            '$total ${total == 1 ? 'task' : 'tasks'}',
            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ),
      ],
    );
  }
}
