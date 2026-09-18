import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography hierarchy for the Todo App.
///
/// Every text in the application should pick a semantic role from this theme
/// (via `Theme.of(context).textTheme`) instead of ad-hoc `TextStyle` values.
///
/// Semantic roles (Phase 10):
/// - display / hero titles  → `displayLarge`
/// - page titles (screens)  → `headlineLarge` / `headlineMedium`
/// - section headings       → `headlineSmall` / `titleLarge`
/// - card / subsection      → `titleMedium`, `titleSmall`
/// - body text              → `bodyLarge`, `bodyMedium`
/// - captions / metadata    → `bodySmall`
/// - labels & navigation    → `labelLarge`, `labelMedium`, `labelSmall`
///
/// The ladder leans editorial: tight heights, a slightly condensed display
/// step and wide-tracked labels so screens read like a crafted publication
/// rather than a generic web app. The terminal role set (`headlineMedium`
/// 30/w700, `labelLarge` 16 …) is contract-stable and must not change.
abstract final class AppTypography {
  /// White ("paper") text hierarchy — calm, cool, high contrast.
  static TextTheme white() => _textTheme(
    textPrimaryColor: AppColors.textPrimary,
    textMutedColor: AppColors.textMuted,
  );

  /// GRAPHITE ("command center") text hierarchy — silver-white ink on steel.
  static TextTheme graphite() => _textTheme(
    textPrimaryColor: AppColorsDark.textPrimary,
    textMutedColor: AppColorsDark.textMuted,
  );

  /// Backwards-compatible alias for [white].
  static TextTheme light() => white();

  /// Backwards-compatible alias for [graphite].
  static TextTheme dark() => graphite();

  static TextTheme _textTheme({
    required Color textPrimaryColor,
    required Color textMutedColor,
  }) {
    return TextTheme(
      /// Hero / landing / brand display text. Large, tight and confident —
      /// the loudest single role in the system.
      displayLarge: TextStyle(
        fontSize: 56,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        color: textPrimaryColor,
      ),

      /// Large page titles — the single dominant heading of a screen.
      headlineLarge: TextStyle(
        fontSize: 36,
        height: 1.14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: textPrimaryColor,
      ),

      /// Page titles (kept for compatibility) — dominant heading of a screen.
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimaryColor,
      ),

      /// Sub-section emphasis within a page.
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimaryColor,
      ),

      /// Section titles within a page.
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textPrimaryColor,
      ),

      /// Card / subsection headers.
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),

      /// Compact sub-headers and list-item titles.
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),

      /// Primary body text.
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: textPrimaryColor),

      /// Secondary body text.
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: textPrimaryColor),

      /// Helper text, metadata and captions.
      bodySmall: TextStyle(fontSize: 13, height: 1.45, color: textMutedColor),

      /// Emphasized action labels (buttons).
      labelLarge: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textPrimaryColor,
      ),

      /// Input labels and compact action labels.
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textPrimaryColor,
      ),

      /// Legal/copyright microtext.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textMutedColor,
      ),
    );
  }
}
