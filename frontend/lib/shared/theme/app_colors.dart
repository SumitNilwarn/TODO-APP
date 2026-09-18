import 'package:flutter/material.dart';

/// Central design tokens for the Todo App visual language.
///
/// A restrained, monochrome neutral palette sits at the heart of the system:
/// cool gray surfaces, near-black ink CTAs, generous whitespace and rounded
/// geometry define the calm, premium appearance. Raw colors should be
/// referenced through [AppColors] (light) / [AppColorsDark] (dark) — never
/// scattered inline.
abstract final class AppColors {
  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Neutral, cool-gray app background.
  static const Color background = Color(0xFFF7F7F8);

  /// Default elevated surface (cards, inputs).
  static const Color surface = Color(0xFFFFFFFF);

  /// Silent surface used when a slightly brighter plane sits above [surface]
  /// (hover rails, popovers, elevated menus).
  static const Color surfaceElevated = Color(0xFFFCFCFD);

  /// Slightly tinted surface for secondary fills and hover states.
  static const Color surfaceAlt = Color(0xFFEDEDF0);

  /// Interactive hover plane (nav items, rows, button surfaces).
  static const Color hoverSurface = Color(0xFFF1F1F4);

  /// Pressed/selected plane (active nav item, selected list rows).
  static const Color selectedSurface = Color(0xFFE9E9ED);

  // ── Primary action ───────────────────────────────────────────────────────
  /// The brand/primary ink — dark CTA color and strongest text.
  static const Color primary = Color(0xFF17171B);

  /// Text/icon on the [primary] CTA.
  static const Color onPrimary = Colors.white;

  /// Soft container for the primary emphasis (selected nav, tinted bars).
  static const Color primaryContainer = Color(0xFFE7E7EB);

  // ── Secondary accent ─────────────────────────────────────────────────────
  /// Restrained neutral-gray accent for focus and secondary emphasis.
  static const Color secondary = Color(0xFF5F5F6A);

  /// Text/icon on the [secondary] accent.
  static const Color onSecondary = Colors.white;

  /// Tint container for secondary selections (selected nav item, chips).
  static const Color secondaryContainer = Color(0xFFECECF0);

  /// Text on [secondaryContainer].
  static const Color onSecondaryContainer = Color(0xFF303036);

  // ── Text & icon roles ────────────────────────────────────────────────────
  /// Primary craft: headings and strong text. Same value as [primary].
  static const Color textPrimary = Color(0xFF17171B);

  /// Secondary text — descriptions, meta, unselected nav.
  static const Color textSecondary = Color(0xFF55555E);

  /// Muted/quiet text for captions, hints and placeholders.
  static const Color textMuted = Color(0xFF797983);

  /// Calm ink used on the [primary] CTA. Same value as [onPrimary].
  static const Color onInk = Colors.white;

  // ── Lines & separators ───────────────────────────────────────────────────
  /// Hairline border on cards and outlined surfaces.
  static const Color border = Color(0xFFE4E4E8);

  /// Hairline subtle border (legacy alias, used on interactive cards).
  static const Color subtleBorder = Color(0x0C17171B);

  /// Hairline divider between stacked content.
  static const Color divider = Color(0x14000000);

  /// Dimmed plane behind modals, sheets and overlays.
  static const Color scrim = Color(0x66000000);

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

  /// Calm neutral-gray accent (alias of [secondary]).
  static const Color accent = secondary;

  /// Secondary/secondary-information text (alias of [textMuted] — keep
  /// `muted` for exact historical values).
  static const Color muted = textMuted;
}

/// Dark-mode mirror of [AppColors]: the same semantic roles, re-mapped so the
/// UI stays equally calm and readable on deep neutral surfaces. The primary
/// ink inverts to a near-white CTA for strong, premium contrast in dark mode.
abstract final class AppColorsDark {
  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0F0F12);

  static const Color surface = Color(0xFF17171B);

  static const Color surfaceElevated = Color(0xFF1D1D22);

  static const Color surfaceAlt = Color(0xFF232329);

  static const Color hoverSurface = Color(0xFF1C1C21);

  static const Color selectedSurface = Color(0xFF26262D);

  // ── Primary action ───────────────────────────────────────────────────────
  static const Color primary = Color(0xFFF4F4F6);

  static const Color onPrimary = Color(0xFF16161A);

  static const Color primaryContainer = Color(0xFF292930);

  // ── Secondary accent ─────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFB0B0BA);

  static const Color onSecondary = Color(0xFF16161A);

  static const Color secondaryContainer = Color(0xFF2B2B33);

  static const Color onSecondaryContainer = Color(0xFFDCDCE2);

  // ── Text & icon roles ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F3);

  static const Color textSecondary = Color(0xFFB6B6BF);

  static const Color textMuted = Color(0xFF8B8B95);

  static const Color onInk = Color(0xFF16161A);

  // ── Lines & separators ───────────────────────────────────────────────────
  static const Color border = Color(0xFF26262C);

  static const Color subtleBorder = Color(0x26FFFFFF);

  static const Color divider = Color(0x2EFFFFFF);

  static const Color scrim = Color(0x99000000);

  // ── Feedback semantics (brighter for dark surfaces) ──────────────────────
  static const Color danger = Color(0xFFE57373);

  static const Color warning = Color(0xFFE3B34C);

  static const Color success = Color(0xFF66BB6A);

  static const Color info = Color(0xFF90CAF9);

  // ── Legacy aliases ───────────────────────────────────────────────────────
  static const Color ink = primary;

  static const Color accent = secondary;

  static const Color muted = textMuted;
}
