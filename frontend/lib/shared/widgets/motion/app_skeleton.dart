import 'package:flutter/material.dart';

import '../../../core/utils/responsive.dart';
import '../../theme/design_tokens.dart';
import '../../theme/theme_extensions.dart';
import '../app_card.dart';
import '../responsive_container.dart';

/// A quiet, pulsing placeholder box used by skeleton loading states.
///
/// The pulse is a gentle opacity wave on a neutral fill — no layout shifts, no
/// text, no fake data. When the user opts out of animations the box renders
/// statically at its resting opacity.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = AppSpacing.md,
    this.radius = AppRadius.sm,
    this.circle = false,
    this.color,
  });

  /// Fixed width; `null` stretches to the parent.
  final double? width;

  /// Pill height (defaults to 16).
  final double height;

  /// Corner radius; ignored when [circle] is `true`.
  final double radius;

  /// Renders a perfect circle of size [height] x [height].
  final bool circle;

  /// Optional override of the neutral fill.
  final Color? color;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionReduced = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _motionReduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Reduced motion renders the box statically; otherwise a gentle pulse runs
    // for as long as the placeholder is mounted.
    if (!_motionReduced) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.color ?? tokens.surfaceAlt,
        borderRadius: widget.circle
            ? AppRadius.pillAll
            : BorderRadius.circular(widget.radius),
      ),
    );
    if (_motionReduced) {
      return Opacity(opacity: 0.55, child: box);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          Opacity(opacity: 1.0 - 0.45 * _controller.value, child: box),
    );
  }
}

/// Skeleton placeholder for the dashboard first load.
///
/// Mirrors the real layout loosely (metric grid, status card, overdue card,
/// tasks card) so the page "boots" into the same shape it will hold.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _MetricGridSkeleton(),
            SizedBox(height: AppSpacing.lg),
            _CardSkeleton(header: true, bars: true, height: 250),
            SizedBox(height: AppSpacing.lg),
            _CardSkeleton(height: 112),
            SizedBox(height: AppSpacing.lg),
            _CardSkeleton(rows: 4, height: 340),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder for the tasks list first load.
///
/// Mirrors the search bar, filter row and the task list card shape.
class TasksSkeleton extends StatelessWidget {
  const TasksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return ResponsiveContainer(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSkeleton(
              height: AppSizes.inputHeight,
              radius: AppRadius.md,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                AppSkeleton(width: 84, height: 32, radius: AppRadius.full),
                AppSkeleton(width: 120, height: 32, radius: AppRadius.full),
                AppSkeleton(width: 96, height: 32, radius: AppRadius.full),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _CardSkeleton(rows: 4, height: 360),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              children: [
                AppSkeleton(
                  width: 120,
                  height: AppSizes.buttonHeight,
                  radius: AppRadius.lg,
                ),
                AppSkeleton(
                  width: 90,
                  height: AppSpacing.md,
                  radius: AppRadius.sm,
                  color: tokens.surfaceAlt.withValues(alpha: 0.6),
                ),
                AppSkeleton(
                  width: 120,
                  height: AppSizes.buttonHeight,
                  radius: AppRadius.lg,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid of six metric tiles, matching the dashboard's column logic.
class _MetricGridSkeleton extends StatelessWidget {
  const _MetricGridSkeleton();

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
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: tileWidth,
                child: const AppSkeleton(height: 72, radius: AppRadius.md),
              ),
          ],
        );
      },
    );
  }
}

/// Card-shaped skeleton block composed of placeholder lines and bars.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({
    this.header = false,
    this.bars = false,
    this.rows = 0,
    this.height,
  });

  final bool header;
  final bool bars;

  /// Number of full-width placeholder rows (task rows).
  final int rows;

  final double? height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return SizedBox(
      height: height,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header) ...[
              const AppSkeleton(width: 96, height: 18, radius: AppRadius.sm),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (bars) ...[
              for (var i = 0; i < 4; i++) ...[
                Row(
                  children: [
                    const AppSkeleton(width: 120, height: 14),
                    const Spacer(),
                    const AppSkeleton(width: 20, height: 14),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const AppSkeleton(height: 10, radius: AppRadius.pill),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            if (rows > 0)
              for (var i = 0; i < rows; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const AppSkeleton(circle: true, height: 30, width: 30),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.82 : 0.64,
                              child: const AppSkeleton(height: 14),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const AppSkeleton(width: 140, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < rows - 1) Divider(height: 1, color: tokens.divider),
              ],
          ],
        ),
      ),
    );
  }
}
