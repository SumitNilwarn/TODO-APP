import 'package:flutter/widgets.dart';

/// Coherent breakpoint strategy for the Todo App web client.
///
/// Phase 9 targets desktop, laptop and tablet-sized browser widths; compact
/// (mobile) widths are defined now so later mobile work slots in without
/// restructuring, but they are not optimized in this phase.
///
/// The source of truth is a `LayoutBuilder`/constraints (see
/// [ResponseLayout] and `shared/widgets`), never hardcoded screen sizes.
abstract final class AppBreakpoints {
  static const double compact = 0;
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Typical maximum content width before a page becomes a centered column.
  static const double maxContentWidth = 1200;
}

/// The size class of the current viewport.
enum AppScreenSize {
  /// Below [AppBreakpoints.tablet] — mobile (Phase 10+).
  compact,

  /// [AppBreakpoints.tablet] up to (but not including) [AppBreakpoints.desktop].
  tablet,

  /// [AppBreakpoints.desktop] and wider — desktop/laptop.
  desktop;

  static AppScreenSize fromWidth(double width) {
    if (width >= AppBreakpoints.desktop) {
      return AppScreenSize.desktop;
    }
    if (width >= AppBreakpoints.tablet) {
      return AppScreenSize.tablet;
    }
    return AppScreenSize.compact;
  }
}

/// Read-model over the current viewport used by responsive widgets.
///
/// Prefer [ResponseLayout] in widgets so layout decisions flow from the actual
/// constraints; use [screenSizeOf] only for lightweight, presentation-only
/// branches (e.g. padding/switching to an icon in an action bar).
class ResponseLayout {
  const ResponseLayout({required this.maxWidth, required this.size});

  ResponseLayout.fromWidth(double width)
    : maxWidth = width < AppBreakpoints.desktop
          ? width
          : AppBreakpoints.maxContentWidth,
      size = AppScreenSize.fromWidth(width);

  /// The constraints-driven width, capped at [AppBreakpoints.maxContentWidth].
  final double maxWidth;

  /// The viewport size class.
  final AppScreenSize size;

  bool get isTablet => size == AppScreenSize.tablet;
  bool get isDesktop => size == AppScreenSize.desktop;
  bool get isCompact => size == AppScreenSize.compact;
}

/// Resolve the current screen size from `MediaQuery` (handy when no
/// `LayoutBuilder` is available).
AppScreenSize screenSizeOf(BuildContext context) {
  return AppScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
}
