import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'design_tokens.dart';
import 'theme_extensions.dart';

/// Application-wide theme following the Todo App design direction:
/// minimal, calm, soft neutral surfaces, rounded geometry and a dark primary
/// CTA.
///
/// Architecturally, the theme is composed from:
/// - raw tokens (`design_tokens.dart`, `app_colors.dart`),
/// - semantic roles (`AppThemeTokens` theme extension),
/// - assembled Material component themes below.
/// Components read colors through `context.appColors` and geometry through the
/// static token classes so nothing is hardcoded inline.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onPrimary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceAlt,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          error: AppColors.danger,
          onError: AppColors.onPrimary,
          surfaceTint: Colors.transparent,
        );
    final textTheme = AppTypography.light();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      focusColor: AppColors.accent.withValues(alpha: 0.45),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const [AppThemeTokens.light()],
      inputDecorationTheme: _inputDecorationTheme(textTheme),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(textTheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(textTheme),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle(textTheme)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AppColors.muted.withValues(alpha: 0.5),
        ),
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(AppRadius.full),
      ),
      cardTheme: _cardTheme(textTheme),
      dialogTheme: _dialogTheme(textTheme),
      snackBarTheme: _snackBarTheme(textTheme),
      chipTheme: _chipTheme(textTheme),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.onInk,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }

  static CardThemeData _cardTheme(TextTheme _) {
    return CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: const BorderSide(color: AppColors.subtleBorder),
      ),
    );
  }

  static DialogThemeData _dialogTheme(TextTheme textTheme) {
    return DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(TextTheme textTheme) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF26282B),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.onInk),
      actionTextColor: AppColors.onInk,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      elevation: 0,
    );
  }

  static ChipThemeData _chipTheme(TextTheme textTheme) {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.secondaryContainer,
      labelStyle: textTheme.labelMedium,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tight),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(TextTheme textTheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.danger),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.ink),
      prefixIconColor: AppColors.textMuted,
      suffixIconColor: AppColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.input,
        vertical: AppSpacing.md,
      ),
      border: _outline(AppRadius.md, borderSide: BorderSide.none),
      enabledBorder: _outline(AppRadius.md, borderSide: BorderSide.none),
      focusedBorder: _outline(
        AppRadius.md,
        borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
      ),
      errorBorder: _outline(
        AppRadius.md,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: _outline(
        AppRadius.md,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  static OutlineInputBorder _outline(double radius, {BorderSide? borderSide}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: borderSide ?? BorderSide.none,
    );
  }

  static ButtonStyle _filledButtonStyle(TextTheme textTheme) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.onInk,
      disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.16),
      disabledForegroundColor: AppColors.ink.withValues(alpha: 0.38),
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      textStyle: textTheme.labelLarge?.copyWith(color: AppColors.onInk),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.onInk.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.onInk.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _outlinedButtonStyle(TextTheme textTheme) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      disabledForegroundColor: AppColors.ink.withValues(alpha: 0.38),
      backgroundColor: AppColors.surface,
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      side: const BorderSide(color: AppColors.divider),
      textStyle: textTheme.labelLarge,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.ink.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.ink.withValues(alpha: 0.06);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _textButtonStyle(TextTheme textTheme) {
    return TextButton.styleFrom(
      foregroundColor: AppColors.ink,
      disabledForegroundColor: AppColors.ink.withValues(alpha: 0.38),
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      textStyle: textTheme.labelLarge,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.ink.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.ink.withValues(alpha: 0.06);
        }
        return null;
      }),
    );
  }
}
