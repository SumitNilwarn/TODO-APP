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

/// GRAPHITE palette — the default "command center" theme.
///
/// A cinematic, futuristic mirror of [AppColors]: deep blue-steel graphene
/// surfaces, near-white steel ink CTAs and a cool, faint glow used by the
/// architectural grid and chrome framing. Where the light palette is calm
/// paper, GRAPHITE is machined steel — the same semantic roles, re-mapped for
/// a darker, denser command-room presence.
abstract final class AppColorsDark {
  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Deep graphene base — the page sits a step below every surface.
  static const Color background = Color(0xFF0A0B0D);

  /// Default elevated surface (cards, inputs) — machined steel.
  static const Color surface = Color(0xFF131519);

  /// Silent surface raised above [surface] (rails, popovers, menus).
  static const Color surfaceElevated = Color(0xFF171A1F);

  /// Slightly tinted surface for secondary fills and hover states.
  static const Color surfaceAlt = Color(0xFF1C2026);

  /// Interactive hover plane (nav items, rows, button surfaces).
  static const Color hoverSurface = Color(0xFF191C21);

  /// Pressed/selected plane (active nav item, selected list rows).
  static const Color selectedSurface = Color(0xFF22262E);

  // ── Primary action ───────────────────────────────────────────────────────
  /// The brand/primary CTA — near-white cool steel, high-contrast on graphite.
  static const Color primary = Color(0xFFE4E8EF);

  static const Color onPrimary = Color(0xFF0C0E11);

  /// Soft container for the primary emphasis (selected nav, tinted bars).
  static const Color primaryContainer = Color(0xFF262B33);

  // ── Secondary accent ─────────────────────────────────────────────────────
  /// Cool blue-steel accent for focus and secondary emphasis.
  static const Color secondary = Color(0xFF97A1B3);

  static const Color onSecondary = Color(0xFF0C0E11);

  /// Tint container for secondary selections (selected nav item, chips).
  static const Color secondaryContainer = Color(0xFF262932);

  /// Text on [secondaryContainer].
  static const Color onSecondaryContainer = Color(0xFFD3DAE4);

  // ── Text & icon roles ────────────────────────────────────────────────────
  /// Primary craft: headings and strong text — cool silver-white.
  static const Color textPrimary = Color(0xFFE8EAF0);

  /// Secondary text — descriptions, meta, unselected nav.
  static const Color textSecondary = Color(0xFFA8B0BD);

  /// Muted/quiet text for captions, hints and placeholders.
  static const Color textMuted = Color(0xFF6F7684);

  /// Calm ink used on the [primary] CTA. Same value as [onPrimary].
  static const Color onInk = Color(0xFF0C0E11);

  // ── Lines & separators ───────────────────────────────────────────────────
  /// Hairline border on cards and outlined surfaces.
  static const Color border = Color(0xFF262A32);

  /// Hairline subtle border (legacy alias, used on interactive cards).
  static const Color subtleBorder = Color(0x1EFFFFFF);

  /// Hairline divider between stacked content.
  static const Color divider = Color(0x24FFFFFF);

  /// Dimmed plane behind modals, sheets and overlays.
  static const Color scrim = Color(0xAD000000);

  // ── Feedback semantics (brighter for dark surfaces) ──────────────────────
  /// Danger / destructive (errors, destructive actions).
  static const Color danger = Color(0xFFF0756B);

  /// Warning / caution (attention without blocking).
  static const Color warning = Color(0xFFE6BE6A);

  /// Positive / success.
  static const Color success = Color(0xFF74CE9A);

  /// Informational emphasis (contact-support, tips).
  static const Color info = Color(0xFF82B4E8);

  // ── Legacy aliases ───────────────────────────────────────────────────────
  static const Color ink = primary;

  static const Color accent = secondary;

  static const Color muted = textMuted;
}
