import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic color roles for the app, exposed as a [ThemeExtension] so every
/// component can resolve its palette through `Theme.of(context)` instead of
/// hardcoding constants.
///
/// Components read colors via the `context.appColors` shortcut; the static
/// [AppColors] / [AppColorsDark] classes remain the single source of truth for
/// token values and are used by the theme itself.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceAlt,
    required this.hoverSurface,
    required this.selectedSurface,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.subtleBorder,
    required this.divider,
    required this.scrim,
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
      hoverSurface = AppColors.hoverSurface,
      selectedSurface = AppColors.selectedSurface,
      primary = AppColors.primary,
      onPrimary = AppColors.onPrimary,
      primaryContainer = AppColors.primaryContainer,
      secondary = AppColors.secondary,
      onSecondary = AppColors.onSecondary,
      secondaryContainer = AppColors.secondaryContainer,
      onSecondaryContainer = AppColors.onSecondaryContainer,
      textPrimary = AppColors.textPrimary,
      textSecondary = AppColors.textSecondary,
      textMuted = AppColors.textMuted,
      border = AppColors.border,
      subtleBorder = AppColors.subtleBorder,
      divider = AppColors.divider,
      scrim = AppColors.scrim,
      success = AppColors.success,
      warning = AppColors.warning,
      danger = AppColors.danger,
      info = AppColors.info;

  const AppThemeTokens.dark()
    : background = AppColorsDark.background,
      surface = AppColorsDark.surface,
      surfaceElevated = AppColorsDark.surfaceElevated,
      surfaceAlt = AppColorsDark.surfaceAlt,
      hoverSurface = AppColorsDark.hoverSurface,
      selectedSurface = AppColorsDark.selectedSurface,
      primary = AppColorsDark.primary,
      onPrimary = AppColorsDark.onPrimary,
      primaryContainer = AppColorsDark.primaryContainer,
      secondary = AppColorsDark.secondary,
      onSecondary = AppColorsDark.onSecondary,
      secondaryContainer = AppColorsDark.secondaryContainer,
      onSecondaryContainer = AppColorsDark.onSecondaryContainer,
      textPrimary = AppColorsDark.textPrimary,
      textSecondary = AppColorsDark.textSecondary,
      textMuted = AppColorsDark.textMuted,
      border = AppColorsDark.border,
      subtleBorder = AppColorsDark.subtleBorder,
      divider = AppColorsDark.divider,
      scrim = AppColorsDark.scrim,
      success = AppColorsDark.success,
      warning = AppColorsDark.warning,
      danger = AppColorsDark.danger,
      info = AppColorsDark.info;

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceAlt;
  final Color hoverSurface;
  final Color selectedSurface;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color subtleBorder;
  final Color divider;
  final Color scrim;
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
    Color? hoverSurface,
    Color? selectedSurface,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? subtleBorder,
    Color? divider,
    Color? scrim,
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
      hoverSurface: hoverSurface ?? this.hoverSurface,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      divider: divider ?? this.divider,
      scrim: scrim ?? this.scrim,
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
      hoverSurface: Color.lerp(hoverSurface, other.hoverSurface, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
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
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
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
            hoverSurface == other.hoverSurface &&
            selectedSurface == other.selectedSurface &&
            primary == other.primary &&
            onPrimary == other.onPrimary &&
            primaryContainer == other.primaryContainer &&
            secondary == other.secondary &&
            onSecondary == other.onSecondary &&
            secondaryContainer == other.secondaryContainer &&
            onSecondaryContainer == other.onSecondaryContainer &&
            textPrimary == other.textPrimary &&
            textSecondary == other.textSecondary &&
            textMuted == other.textMuted &&
            border == other.border &&
            subtleBorder == other.subtleBorder &&
            divider == other.divider &&
            scrim == other.scrim &&
            success == other.success &&
            warning == other.warning &&
            danger == other.danger &&
            info == other.info;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      background,
      surface,
      surfaceElevated,
      surfaceAlt,
      hoverSurface,
      selectedSurface,
      primary,
      onPrimary,
      primaryContainer,
      secondary,
      onSecondary,
      secondaryContainer,
      onSecondaryContainer,
      textPrimary,
      textSecondary,
      textMuted,
      border,
      subtleBorder,
      divider,
      scrim,
      success,
      warning,
      danger,
      info,
    ]);
  }
}

/// Convenience accessor for the app's semantic color roles.
extension AppColorsContext on BuildContext {
  AppThemeTokens get appColors =>
      Theme.of(this).extension<AppThemeTokens>() ??
      const AppThemeTokens.light();
}
