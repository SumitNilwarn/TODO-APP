import 'package:flutter/material.dart';

/// Spacing scale — every gap and padding derives from these tokens instead of
/// arbitrary numbers. Base unit is 4 logical pixels.
///
/// Full scale (Phase 10): `4, 8, 12, 16, 20, 24, 32, 40, 48, 64`.
/// Legacy aliases (`sm`, `md`, `lg`, `xl`, `xxl`) are retained verbatim so
/// existing consumers keep compiling; new work should prefer the documented
/// scale names below.
abstract final class AppSpacing {
  // ── Scale ────────────────────────────────────────────────────────────────
  /// 4 — minimum breathing gap between dense elements.
  static const double xs = 4;

  /// 8 — default gutter inside tight row groupings.
  static const double sm = 8;

  /// 12 — comfortable gap between a label and its value.
  static const double tight = 12;

  /// 16 — standard gap between sibling content blocks.
  static const double md = 16;

  /// 20 — roomy gap for grouped content (e.g. card internals).
  static const double roomy = 20;

  /// 24 — section-level spacing / page gutter.
  static const double lg = 24;

  /// 32 — separation between large page regions.
  static const double xl = 32;

  /// 40 — extra separation for tall, scroll-heavy pages.
  static const double huge = 40;

  /// 48 — generous whitespace around hero/empty/error states.
  static const double xxl = 48;

  /// 64 — maximum visual breathing room (landing/feature heroes).
  static const double giant = 64;

  // ── Semantic aliases ─────────────────────────────────────────────────────
  /// Default horizontal padding for page content (24).
  static const double page = lg;

  /// Padding inside a card surface (20).
  static const double card = roomy;

  /// Horizontal padding inside an input control (16).
  static const double input = md;

  /// Vertical rhythm between a section heading and its content.
  static const double section = lg;
}

/// Corner radius scale — semantic levels: small / medium / large /
/// extraLarge / pill.
///
/// Rounding stays restrained (8–20) so the UI feels calm and premium rather
/// than playful; `pill` is reserved for badges, chips and avatars.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;

  // ── Semantic aliases ─────────────────────────────────────────────────────
  /// Buttons, inputs, focus rings.
  static const double small = sm;

  /// Default card corners.
  static const double medium = md;

  /// Dialogs, large cards, menus.
  static const double large = lg;

  /// Feature/hero surfaces and state tiles.
  static const double extraLarge = xl;

  /// Badges, chips, segmented controls, avatars.
  static const double pill = full;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// `BorderRadius` equivalents of the semantic levels.
  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius extraLargeAll = BorderRadius.all(
    Radius.circular(extraLarge),
  );

  static BorderRadius all(double radius) =>
      BorderRadius.all(Radius.circular(radius));
}

/// Component sizing tokens.
abstract final class AppSizes {
  /// Minimum interactive target (touch/click area) per accessibility guidance.
  static const double touchTarget = 48;

  /// Height of the primary action buttons.
  static const double buttonHeight = 52;

  /// Minimum width for buttons that are not full-width.
  static const double buttonMinWidth = 64;

  /// Logical width of the loading indicator inside a button.
  static const double buttonSpinner = 20;

  /// Brand mark (logo tile) in the sidebar / app bar.
  static const double brandMark = 34;

  /// Width of the fixed sidebar on tablet/desktop.
  static const double sidebarWidth = 264;

  /// Height of a single sidebar navigation item.
  static const double navItemHeight = 44;

  /// Standard input field height (fills to this where the decoration allows).
  static const double inputHeight = 52;

  /// Avatar/user slot size in the sidebar footer.
  static const double avatar = 36;
}

/// Elevation system — semantic levels: `none` / `subtle` / `raised` /
/// `floating`.
///
/// Shadows are kept deliberately restrained: soft, wide and low-offset so
/// surfaces feel calm and premium instead of boxy.
abstract final class AppShadows {
  /// No elevation.
  static const List<BoxShadow> none = [];

  /// The calm, subtle drop shadow carried by standard cards and surfaces.
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 28, offset: Offset(0, 10)),
  ];

  /// Slightly stronger shadow for elevated cards and hover-focus feedback.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// The most pronounced shadow — floating dialogs, menus, popovers.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1B000000),
      blurRadius: 40,
      offset: Offset(0, 18),
      spreadRadius: -6,
    ),
  ];

  // ── Backwards-compatible aliases ─────────────────────────────────────────
  static const List<BoxShadow> soft = subtle;
}

/// Micro-interaction durations.
///
/// Every animation in the app derives from these tokens: fast hovers/scales,
/// normal cross-fades, slow larger entrances, `page` route transitions and
/// `micro` pressed-state feedback.
abstract final class AppDurations {
  /// Pressed feedback, tiny state toggles (100ms).
  static const Duration micro = Duration(milliseconds: 100);

  /// Hover states, focus rings, subtle decorations (150ms).
  static const Duration fast = Duration(milliseconds: 150);

  /// Cross-fades, list content swaps, card elevation (250ms).
  static const Duration normal = Duration(milliseconds: 250);

  /// Staggered entrances and larger reveals (400ms).
  static const Duration slow = Duration(milliseconds: 400);

  /// Route page transitions (280ms).
  static const Duration page = Duration(milliseconds: 280);
}

/// Easing curves for the motion language.
///
/// Curves stay restrained and consistent — no bouncy springs or exaggerated
/// overshoot — so the interface feels calm, premium and predictable.
abstract final class AppCurves {
  /// Default easing for most transitions (gently decelerating).
  static const Curve standard = Curves.easeOutCubic;

  /// Entrance/positioning animations — content arrives with confidence.
  static const Curve enter = Curves.easeOutCubic;

  /// Exit animations resolve quickly and quietly.
  static const Curve exit = Curves.easeInCubic;

  /// Sharp deceleration for anything leaving the screen.
  static const Curve decelerate = Curves.easeOutExpo;
}
