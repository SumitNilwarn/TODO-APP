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
abstract final class AppTypography {
  static TextTheme light() {
    return const TextTheme(
      /// Hero / landing / brand display text.
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: AppColors.textPrimary,
      ),

      /// Large page titles — the single dominant heading of a screen.
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),

      /// Page titles (kept for compatibility) — dominant heading of a screen.
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),

      /// Sub-section emphasis within a page.
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),

      /// Section titles within a page.
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      /// Card / subsection headers.
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      /// Compact sub-headers and list-item titles.
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      /// Primary body text.
      bodyLarge: TextStyle(
        fontSize: 17,
        height: 1.5,
        color: AppColors.textPrimary,
      ),

      /// Secondary body text.
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: AppColors.textPrimary,
      ),

      /// Helper text, metadata and captions.
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: AppColors.textMuted,
      ),

      /// Emphasized action labels (buttons).
      labelLarge: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),

      /// Input labels and compact action labels.
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),

      /// Legal/copyright microtext.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.textMuted,
      ),
    );
  }
}
