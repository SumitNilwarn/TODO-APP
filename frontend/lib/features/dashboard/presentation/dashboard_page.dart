import 'package:flutter/material.dart';

import '../../../core/utils/responsive.dart';
import '../../../data/api/api_exception.dart';
import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_kicker.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/motion/app_skeleton.dart';
import '../../../shared/widgets/motion/fade_entrance.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/presentation/authenticated_scaffold.dart';
import '../data/dashboard_api.dart';
import '../domain/dashboard_models.dart';

/// Dashboard screen: owner-scoped statistics plus bounded, filterable task
/// previews.
///
/// Data comes exclusively from the authenticated backend endpoints
/// (`GET /api/v1/dashboard` for the aggregate counters, `GET /api/v1/tasks`
/// for the preview lists) driven through the authenticated [ApiClient], so
/// ownership and every counter are resolved server-side — no user id is ever
/// sent by the client and no unbounded task fetch happens.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardApi _api;
  bool _bootstrapped = false;

  bool _loading = true;
  bool _refreshing = false;
  String? _loadError;

  /// Set when a refresh (e.g. from a filter change) arrives while another
  /// refresh is already running, so the newer request is not silently dropped.
  bool _refreshQueued = false;

  DashboardSummary? _summary;
  List<DashboardTask> _recentTasks = const [];
  List<DashboardTask> _overdueTasks = const [];
  List<DashboardTask> _upcomingTasks = const [];

  /// Active status filter (`null` = all statuses).
  DashboardTaskStatus? _statusFilter;

  /// When `true`, the recent list only shows overdue tasks.
  bool _overdueOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The authenticated client lives on AppScope, so grab it here (the first
    // build that has the dependency available) rather than in initState.
    if (!_bootstrapped) {
      _bootstrapped = true;
      _api = DashboardApi(AppScope.apiOf(context));
      // Defer the initial fetch to after the first build so the loading state
      // is shown without any setState during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _fetchAll();
      if (!mounted) return;
      setState(() {
        _summary = data.summary;
        _recentTasks = data.recent;
        _overdueTasks = data.overdue;
        _upcomingTasks = data.upcoming;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _friendlyLoadError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your dashboard. Please try again.';
      });
    }
  }

  /// Re-fetches everything while keeping the current screen visible.
  Future<void> _refresh() async {
    if (_loading) return;
    if (_refreshing) {
      // A refresh is already in flight; remember that a newer dataset (e.g. a
      // filter change applied mid-refresh) is wanted so it runs right after.
      _refreshQueued = true;
      return;
    }
    setState(() => _refreshing = true);
    try {
      final data = await _fetchAll();
      if (!mounted) return;
      setState(() {
        _summary = data.summary;
        _recentTasks = data.recent;
        _overdueTasks = data.overdue;
        _upcomingTasks = data.upcoming;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Refresh failed. ${_friendlyRefreshError(error)}',
        variant: AppFeedbackVariant.danger,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Refresh failed. Please try again.',
        variant: AppFeedbackVariant.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        if (_refreshQueued) {
          _refreshQueued = false;
          _refresh();
        }
      }
    }
  }

  Future<_DashboardData> _fetchAll() async {
    final today = _todayUtc();
    // Four bounded, parallel, owner-scoped requests. `Future.wait` is used
    // instead of the record `.wait` extension because the latter wraps errors
    // in a ParallelWaitError, which would mask the ApiException and defeat the
    // safe error mapping below.
    final results = await Future.wait<Object>([
      _api.getSummary(),
      _api.getTasks(
        size: 10,
        sort: 'createdAt',
        direction: 'DESC',
        status: _statusFilter,
        overdue: _overdueOnly,
      ),
      _api.getTasks(size: 5, overdue: true, sort: 'dueDate', direction: 'ASC'),
      _api.getTasks(
        size: 5,
        dueDateFrom: today,
        sort: 'dueDate',
        direction: 'ASC',
      ),
    ], eagerError: true);
    return _DashboardData(
      summary: results[0] as DashboardSummary,
      recent: (results[1] as DashboardTaskPage).tasks,
      overdue: (results[2] as DashboardTaskPage).tasks,
      upcoming: (results[3] as DashboardTaskPage).tasks,
    );
  }

  void _applyFilter({DashboardTaskStatus? status, bool? overdue}) {
    setState(() {
      if (status != null) _statusFilter = status;
      if (overdue != null) _overdueOnly = overdue;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedScaffold(
      selectedIndex: 0,
      kicker: 'Workspace',
      title: 'Dashboard',
      subtitle: 'Overview of your tasks and progress',
      actions: [
        IconButton(
          key: const Key('dashboard-refresh'),
          tooltip: 'Refresh dashboard',
          onPressed: _loading || _refreshing ? null : _refresh,
          icon: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const DashboardSkeleton();
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.giant),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeEntrance(
              duration: const Duration(milliseconds: 380),
              child: AppErrorState(
                title: 'Could not load your dashboard',
                message: _loadError,
                onRetry: _loadInitial,
              ),
            ),
          ),
        ),
      );
    }

    final summary = _summary!;
    return ResponsiveContainer(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeEntrance(child: _MetricTiles(summary: summary)),
            const SizedBox(height: AppSpacing.lg),
            FadeEntrance(
              delay: const Duration(milliseconds: 120),
              duration: const Duration(milliseconds: 420),
              child: _StatusBreakdown(summary: summary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeEntrance(
              delay: const Duration(milliseconds: 190),
              duration: const Duration(milliseconds: 420),
              child: _OverdueSection(tasks: _overdueTasks),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeEntrance(
              delay: const Duration(milliseconds: 260),
              duration: const Duration(milliseconds: 440),
              child: _TasksSection(
                recent: _recentTasks,
                upcoming: _upcomingTasks,
                statusFilter: _statusFilter,
                overdueOnly: _overdueOnly,
                refreshing: _refreshing,
                onFilterChanged: _applyFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime(now.year, now.month, now.day);
  }

  static String _friendlyLoadError(ApiException error) {
    return _safeStatusMessage(error) ??
        (error.message?.isNotEmpty == true
            ? error.message!
            : 'Could not load your dashboard. Please try again.');
  }

  static String _friendlyRefreshError(ApiException error) {
    return _safeStatusMessage(error) ??
        (error.message?.isNotEmpty == true
            ? error.message!
            : 'Please try again.');
  }

  /// Maps transport and HTTP-status failures to safe, user-facing copy.
  ///
  /// A 401 is normally recovered by the authenticated transport (refresh →
  /// retry); when one still reaches this screen the session could not be
  /// restored. 403/404/5xx are translated so no backend detail ever leaks;
  /// 4xx validation errors (400/422) fall through to the server message
  /// because they carry user-relevant information.
  static String? _safeStatusMessage(ApiException error) {
    if (error.isNetworkError) {
      return 'Could not reach the server. Please check your connection.';
    }
    if (error.isTimeout) {
      return 'The request timed out. Please try again.';
    }
    final status = error.statusCode;
    if (status != null && status >= 500) {
      return 'An unexpected server error occurred. Please try again.';
    }
    return switch (status) {
      401 => 'Your session has expired. Please sign in again.',
      403 => "You don't have permission to view this dashboard.",
      404 => 'This dashboard could not be found.',
      _ => null,
    };
  }
}

class _DashboardData {
  const _DashboardData({
    required this.summary,
    required this.recent,
    required this.overdue,
    required this.upcoming,
  });

  final DashboardSummary summary;
  final List<DashboardTask> recent;
  final List<DashboardTask> overdue;
  final List<DashboardTask> upcoming;
}

/// Responsive bento grid of the six summary metrics.
///
/// The total tile reads as a hero (spanning two columns on a dark ink panel);
/// [DashboardTaskStatus.todo] slots beside it, the three mid metrics fill the
/// next row, and the overdue metric spans the full width as an alert strip.
class _MetricTiles extends StatelessWidget {
  const _MetricTiles({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.desktop
            ? 3
            : constraints.maxWidth >= AppBreakpoints.tablet
            ? 2
            : 1;
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;
        final fullWidth = tileWidth * columns + (columns - 1) * AppSpacing.md;
        double span(int cells) =>
            cells * tileWidth + (cells - 1) * AppSpacing.md;

        final tiles = <Widget>[
          SizedBox(
            width: columns > 1 ? span(2) : fullWidth,
            child: _TotalHero(count: summary.totalTasks),
          ),
          SizedBox(
            width: tileWidth,
            child: _MetricTile(
              label: 'To do',
              count: summary.todoTasks,
              icon: Icons.event_note_outlined,
              accent: context.appColors.secondary,
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: _MetricTile(
              label: 'In progress',
              count: summary.inProgressTasks,
              icon: Icons.pending_actions_outlined,
              accent: context.appColors.info,
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: _MetricTile(
              label: 'Completed',
              count: summary.completedTasks,
              icon: Icons.check_circle_outline,
              accent: context.appColors.success,
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: _MetricTile(
              label: 'Cancelled',
              count: summary.cancelledTasks,
              icon: Icons.block_outlined,
              accent: context.appColors.textMuted,
            ),
          ),
          SizedBox(
            width: fullWidth,
            child: _MetricTile(
              label: 'Overdue',
              count: summary.overdueTasks,
              icon: Icons.error_outline_rounded,
              accent: summary.hasOverdue
                  ? context.appColors.danger
                  : context.appColors.textMuted,
              wide: true,
              caption: summary.hasOverdue
                  ? 'Past due and still open.'
                  : 'Nothing past due, nice.',
            ),
          ),
        ];

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (var i = 0; i < tiles.length; i++)
              FadeEntrance(
                delay: Duration(milliseconds: (i * 32).clamp(0, 320)),
                duration: const Duration(milliseconds: 360),
                offset: const Offset(0, 10),
                child: tiles[i],
              ),
          ],
        );
      },
    );
  }
}

/// The "Total" hero: a two-column-wide ink panel announcing the workspace
/// headline count.
class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Total, $count',
      // The inner Text/Icon already announce the value visually; dropping
      // their semantics keeps screen readers from reading the count twice.
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: AppRadius.extraLargeAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Stack(
            children: [
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Icon(
                  Icons.fact_check_outlined,
                  size: 84,
                  color: tokens.onPrimary.withValues(alpha: 0.10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.onPrimary.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$count',
                    style: textTheme.displayLarge?.copyWith(
                      color: tokens.onPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Total',
                    style: textTheme.titleMedium?.copyWith(
                      color: tokens.onPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'All tasks across your workspace.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.onPrimary.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    this.wide = false,
    this.caption,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;

  /// One-shot full-width strip layout (the overdue alert cell).
  final bool wide;

  /// Optional trailing microcopy shown only on [wide] tiles.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label, $count',
      // The child Text/Icon already announce the value visually; dropping
      // their semantics keeps screen readers from reading the count twice.
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, size: 22, color: accent),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
            if (wide && caption != null) ...[
              const Spacer(),
              Flexible(
                child: Text(
                  caption!,
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card with four native status bars (label + count + proportional fill).
class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'Status',
            subtitle: 'Your tasks by status',
            eyebrow: 'Analytics',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!summary.hasTasks)
            const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No tasks yet',
              message: 'Create tasks to see a live breakdown here.',
            )
          else
            for (final status in DashboardTaskStatus.values) ...[
              _StatusBar(
                label: status.label,
                count: summary.countFor(status),
                fraction: summary.fractionFor(status),
                color: _accentFor(status, context),
              ),
              if (status != DashboardTaskStatus.values.last)
                const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  static Color _accentFor(DashboardTaskStatus status, BuildContext context) {
    final tokens = context.appColors;
    return switch (status) {
      DashboardTaskStatus.todo => tokens.secondary,
      DashboardTaskStatus.inProgress => tokens.info,
      DashboardTaskStatus.completed => tokens.success,
      DashboardTaskStatus.cancelled => tokens.textMuted,
    };
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int count;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: textTheme.labelLarge)),
            Text(
              '$count',
              style: textTheme.labelLarge?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(color: tokens.primaryContainer),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Overdue alert card with a danger-tinted header and task rows.
class _OverdueSection extends StatelessWidget {
  const _OverdueSection({required this.tasks});

  final List<DashboardTask> tasks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return AppCard(
      color: tasks.isEmpty
          ? tokens.surface
          : tokens.danger.withValues(alpha: 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppKicker(label: 'Alerts', color: tokens.danger),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: tokens.danger),
              const SizedBox(width: AppSpacing.tight),
              Expanded(child: Text('Overdue', style: textTheme.titleMedium)),
              _CountBadge(
                count: tasks.length,
                background: tokens.danger.withValues(alpha: 0.12),
                foreground: tokens.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tasks.isEmpty
                ? "You're all caught up."
                : 'Past their due date and still open.',
            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _TaskList(tasks: tasks),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            const AppEmptyState(
              icon: Icons.check_circle_outline,
              title: "You're all caught up",
              message: 'No tasks are past their due date.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Recent + upcoming task previews with status/overdue filters.
class _TasksSection extends StatelessWidget {
  const _TasksSection({
    required this.recent,
    required this.upcoming,
    required this.statusFilter,
    required this.overdueOnly,
    required this.refreshing,
    required this.onFilterChanged,
  });

  final List<DashboardTask> recent;
  final List<DashboardTask> upcoming;
  final DashboardTaskStatus? statusFilter;
  final bool overdueOnly;
  final bool refreshing;
  final void Function({DashboardTaskStatus? status, bool? overdue})
  onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isFiltered = statusFilter != null || overdueOnly;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: AppKicker(label: 'Queue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Text('Tasks', style: textTheme.titleMedium),
              AppButton(
                label: 'View all tasks',
                variant: AppButtonVariant.text,
                icon: Icons.arrow_circle_right_outlined,
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(AppRouter.tasks);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Preview and filter your most recent tasks.',
            style: textTheme.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterControls(
            statusFilter: statusFilter,
            overdueOnly: overdueOnly,
            onFilterChanged: onFilterChanged,
          ),
          if (refreshing) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Recent', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (recent.isEmpty)
            AppEmptyState(
              icon: isFiltered
                  ? Icons.filter_alt_off_outlined
                  : Icons.inbox_outlined,
              title: isFiltered
                  ? 'No tasks match this filter'
                  : 'You have no tasks yet',
              message: isFiltered
                  ? 'Try another status or turn off Overdue only.'
                  : 'Tasks you add will show up here.',
            )
          else
            _TaskList(tasks: recent),
          const SizedBox(height: AppSpacing.lg),
          Text('Coming up', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (upcoming.isEmpty)
            const AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled',
              message: 'No tasks are due today or later.',
            )
          else
            _TaskList(tasks: upcoming),
        ],
      ),
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.statusFilter,
    required this.overdueOnly,
    required this.onFilterChanged,
  });

  final DashboardTaskStatus? statusFilter;
  final bool overdueOnly;
  final void Function({DashboardTaskStatus? status, bool? overdue})
  onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppChoiceChip(
          label: 'All',
          selected: statusFilter == null && !overdueOnly,
          onSelected: () => onFilterChanged(status: null, overdue: null),
        ),
        for (final status in DashboardTaskStatus.values)
          AppChoiceChip(
            label: status.label,
            selected: statusFilter == status,
            onSelected: () => onFilterChanged(status: status, overdue: null),
          ),
        AppFilterChip(
          label: 'Overdue only',
          selected: overdueOnly,
          onSelected: (selected) => onFilterChanged(overdue: selected),
          activeColor: tokens.danger,
        ),
      ],
    );
  }
}

/// A compact list of task rows separated by hairline dividers.
///
/// The content cross-fades when the underlying data set changes (filter
/// applied, refresh landed), so rows never pop in/out abruptly. Changing back
/// to an identical set produces no visible motion.
class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<DashboardTask> tasks;

  @override
  Widget build(BuildContext context) {
    final signature = tasks.map((t) => t.id).join(',');
    return AnimatedSwitcher(
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
        key: ValueKey(signature),
        child: Column(
          children: [
            for (var i = 0; i < tasks.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _TaskRow(task: tasks[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final DashboardTask task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _StatusIcon(status: task.status),
          ),
          const SizedBox(width: AppSpacing.md),
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
                const SizedBox(height: 2),
                Text(
                  '${task.status.label} · ${task.dueLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
                if (task.description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (task.overdue) ...[
            const SizedBox(width: AppSpacing.sm),
            _OverdueBadge(),
          ],
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final DashboardTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final (icon, color) = switch (status) {
      DashboardTaskStatus.todo => (
        Icons.radio_button_unchecked,
        tokens.secondary,
      ),
      DashboardTaskStatus.inProgress => (
        Icons.play_circle_outline_rounded,
        tokens.info,
      ),
      DashboardTaskStatus.completed => (
        Icons.check_circle_outline_rounded,
        tokens.success,
      ),
      DashboardTaskStatus.cancelled => (Icons.block_rounded, tokens.textMuted),
    };
    return Semantics(
      label: status.label,
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Semantics(
      label: 'Overdue',
      // The inner label text stays visible; excludeSemantics prevents a
      // doubled "Overdue Overdue" announcement for screen readers.
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.12),
          borderRadius: AppRadius.pillAll,
        ),
        child: Text(
          'Overdue',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: tokens.danger, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.background,
    required this.foreground,
  });

  final int count;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.eyebrow});

  final String title;
  final String? subtitle;

  /// Optional technical eyebrow rendered above the title.
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eyebrow != null) ...[
          AppKicker(label: eyebrow!),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(title, style: textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ],
      ],
    );
  }
}
