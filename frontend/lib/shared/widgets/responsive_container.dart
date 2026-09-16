import 'package:flutter/widgets.dart';

import '../../core/utils/responsive.dart';
import '../theme/design_tokens.dart';

/// Layouts its child responsively:
///
/// - resolves the current screen size from actual `LayoutBuilder` constraints
///   (never hardcoded dimensions),
/// - applies a horizontal gutter that grows with the size class
///   ([AppSpacing.page] on tablet/compact, [AppSpacing.xl] on desktop),
/// - caps content width to [maxWidth] and centers it, so wide screens do not
///   stretch prose/surfaces across the whole viewport.
///
/// Breakpoints live in [AppBreakpoints] (see `core/utils/responsive.dart`).
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.horizontalPadding,
  });

  final Widget child;

  /// Content cap; defaults to [AppBreakpoints.maxContentWidth].
  final double maxWidth;

  /// Optional fixed horizontal gutter, overriding the breakpoint-based one.
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ResponseLayout.fromWidth(constraints.maxWidth);
        final padding =
            horizontalPadding ??
            (layout.isDesktop ? AppSpacing.xl : AppSpacing.page);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
