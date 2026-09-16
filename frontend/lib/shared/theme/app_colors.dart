import 'package:flutter/material.dart';

/// Central design tokens for the Todo App visual language.
///
/// Soft neutral/pastel surfaces, dark CTA ink, generous whitespace and
/// rounded geometry define the calm, premium appearance. Raw colors should be
/// referenced through [AppColors] — never scattered inline.
///
/// Phase 10 introduces the semantic color set (surfaces, primary/secondary,
/// text roles, borders and feedback colors). Legacy identifiers such as
/// [ink], `accent`, [muted] and `surfaceAlt` are retained as aliases so
/// existing consumers keep compiling.
abstract final class AppColors {
  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Warm, paper-like app background.
  static const Color background = Color(0xFFF6F5F2);

  /// Default elevated surface (cards, inputs).
  static const Color surface = Color(0xFFFFFFFF);

  /// Silent surface used when a slightly warmer plane sits above [surface]
  /// (hover rails, popovers, elevated menus).
  static const Color surfaceElevated = Color(0xFFFCFBF9);

  /// Slightly tinted surface for secondary fills and hover states.
  static const Color surfaceAlt = Color(0xFFF1F0EC);

  // ── Primary action ───────────────────────────────────────────────────────
  /// The brand/primary ink — dark CTA color and strongest text.
  static const Color primary = Color(0xFF191919);

  /// Text/icon on the [primary] CTA.
  static const Color onPrimary = Colors.white;

  /// Soft container for the primary emphasis (selected nav, tinted bars).
  static const Color primaryContainer = Color(0xFFEDEDEA);

  // ── Secondary accent ─────────────────────────────────────────────────────
  /// Calm steel-blue accent used for focus and secondary emphasis.
  static const Color secondary = Color(0xFF6E7B96);

  /// Tint container for secondary selections (selected nav item, chips).
  static const Color secondaryContainer = Color(0xFFE9EDF4);

  /// Text on [secondaryContainer].
  static const Color onSecondaryContainer = Color(0xFF3C4657);

  // ── Text & icon roles ────────────────────────────────────────────────────
  /// Primary craft: headings and strong text. Same value as [primary].
  static const Color textPrimary = Color(0xFF191919);

  /// Secondary text — descriptions, meta, unselected nav.
  static const Color textSecondary = Color(0xFF5F6670);

  /// Muted/quiet text for captions, hints and placeholders.
  static const Color textMuted = Color(0xFF8A8F98);

  /// Calm ink used on the [primary] CTA. Same value as [onPrimary].
  static const Color onInk = Colors.white;

  // ── Lines & separators ───────────────────────────────────────────────────
  /// Hairline border on cards and outlined surfaces.
  static const Color border = Color(0xFFEAE8E2);

  /// Hairline subtle border (legacy alias, used on interactive cards).
  static const Color subtleBorder = Color(0x0A191919);

  /// Hairline divider between stacked content.
  static const Color divider = Color(0x14000000);

  // ── Feedback semantics ───────────────────────────────────────────────────
  /// Danger / destructive (errors, destructive actions).
  static const Color danger = Color(0xFFB3261E);

  /// Warning / caution (attention without blocking).
  static const Color warning = Color(0xFF9A6B00);

  /// Positive / success.
  static const Color success = Color(0xFF2E7D32);

  /// Informational emphasis (contact-support, tips).
  static const Color info = Color(0xFF37577E);

  // ── Legacy aliases ───────────────────────────────────────────────────────
  /// Primary ink — text and the dark CTA color (alias of [primary]).
  static const Color ink = primary;

  /// Calm steel-blue accent (alias of [secondary]).
  static const Color accent = secondary;

  /// Secondary/secondary-information text (alias of [textMuted] — keep
  /// `muted` for exact historical values).
  static const Color muted = textMuted;
}
