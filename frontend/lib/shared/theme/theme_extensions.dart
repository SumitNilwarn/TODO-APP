import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic color roles for the app, exposed as a [ThemeExtension] so every
/// component can resolve its palette through `Theme.of(context)` instead of
/// hardcoding constants.
///
/// Components read colors via the `context.appColors` shortcut; the static
/// [AppColors] class remains the single source of truth for token values and
/// is used by the theme itself.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  const AppThemeTokens.light()
    : background = AppColors.background,
      surface = AppColors.surface,
      surfaceElevated = AppColors.surfaceElevated,
      surfaceAlt = AppColors.surfaceAlt,
      primary = AppColors.primary,
      onPrimary = AppColors.onPrimary,
      primaryContainer = AppColors.primaryContainer,
      secondary = AppColors.secondary,
      secondaryContainer = AppColors.secondaryContainer,
      onSecondaryContainer = AppColors.onSecondaryContainer,
      textPrimary = AppColors.textPrimary,
      textSecondary = AppColors.textSecondary,
      textMuted = AppColors.textMuted,
      border = AppColors.border,
      divider = AppColors.divider,
      success = AppColors.success,
      warning = AppColors.warning,
      danger = AppColors.danger,
      info = AppColors.info;

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceAlt;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceAlt,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AppThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;
    return AppThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppThemeTokens &&
            background == other.background &&
            surface == other.surface &&
            surfaceElevated == other.surfaceElevated &&
            surfaceAlt == other.surfaceAlt &&
            primary == other.primary &&
            onPrimary == other.onPrimary &&
            primaryContainer == other.primaryContainer &&
            secondary == other.secondary &&
            secondaryContainer == other.secondaryContainer &&
            onSecondaryContainer == other.onSecondaryContainer &&
            textPrimary == other.textPrimary &&
            textSecondary == other.textSecondary &&
            textMuted == other.textMuted &&
            border == other.border &&
            divider == other.divider &&
            success == other.success &&
            warning == other.warning &&
            danger == other.danger &&
            info == other.info;
  }

  @override
  int get hashCode {
    return Object.hash(
      background,
      surface,
      surfaceElevated,
      surfaceAlt,
      primary,
      onPrimary,
      primaryContainer,
      secondary,
      secondaryContainer,
      onSecondaryContainer,
      textPrimary,
      textSecondary,
      textMuted,
      border,
      divider,
      success,
      warning,
      danger,
      info,
    );
  }
}

/// Convenience accessor for the app's semantic color roles.
extension AppColorsContext on BuildContext {
  AppThemeTokens get appColors =>
      Theme.of(this).extension<AppThemeTokens>() ??
      const AppThemeTokens.light();
}
