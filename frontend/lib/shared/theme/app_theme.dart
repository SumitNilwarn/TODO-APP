import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'design_tokens.dart';
import 'theme_extensions.dart';

/// Application-wide theme following the Todo App design direction: minimal,
/// calm, monochrome neutral surfaces, rounded geometry and an ink CTA that
/// adapts to the brightness (near-black in light, near-white in dark).
///
/// Architecturally, the theme is composed from:
/// - raw tokens (`design_tokens.dart`, `app_colors.dart`),
/// - semantic roles (`AppThemeTokens` theme extension),
/// - assembled Material component themes below.
/// Components read colors through `context.appColors` and geometry through the
/// static token classes so nothing is hardcoded inline.
abstract final class AppTheme {
  static ThemeData light() {
    return _build(
      brightness: Brightness.light,
      tokens: const AppThemeTokens.light(),
      textTheme: AppTypography.light(),
      snackbarBackground: const Color(0xFF26262B),
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      tokens: const AppThemeTokens.dark(),
      textTheme: AppTypography.dark(),
      // In dark mode the snackbar is an elevated plane with a hairline edge
      // rather than an opaque black bar sitting on already-dark surfaces.
      snackbarBackground: const Color(0xFF1D1D22),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppThemeTokens tokens,
    required TextTheme textTheme,
    required Color snackbarBackground,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: tokens.secondary,
          brightness: brightness,
          surface: tokens.surface,
        ).copyWith(
          primary: tokens.primary,
          onPrimary: tokens.onPrimary,
          primaryContainer: tokens.primaryContainer,
          onPrimaryContainer: tokens.textPrimary,
          secondary: tokens.secondary,
          onSecondary: tokens.onSecondary,
          secondaryContainer: tokens.secondaryContainer,
          onSecondaryContainer: tokens.onSecondaryContainer,
          surface: tokens.surface,
          onSurface: tokens.textPrimary,
          surfaceContainerHighest: tokens.surfaceAlt,
          onSurfaceVariant: tokens.textSecondary,
          outline: tokens.border,
          outlineVariant: tokens.border,
          error: tokens.danger,
          onError: tokens.onPrimary,
          surfaceTint: Colors.transparent,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      textTheme: textTheme,
      focusColor: tokens.secondary.withValues(alpha: 0.45),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens],
      inputDecorationTheme: _inputDecorationTheme(textTheme, tokens),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(textTheme, tokens),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(textTheme, tokens),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _textButtonStyle(textTheme, tokens),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.primary),
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          tokens.textMuted.withValues(alpha: 0.5),
        ),
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(AppRadius.full),
      ),
      cardTheme: _cardTheme(tokens),
      dialogTheme: _dialogTheme(textTheme, tokens),
      snackBarTheme: _snackBarTheme(
        textTheme,
        tokens,
        background: snackbarBackground,
      ),
      chipTheme: _chipTheme(textTheme, tokens),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.primaryContainer,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: tokens.primary,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: tokens.primary, size: 22),
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }

  static CardThemeData _cardTheme(AppThemeTokens tokens) {
    return CardThemeData(
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: tokens.subtleBorder),
      ),
    );
  }

  static DialogThemeData _dialogTheme(
    TextTheme textTheme,
    AppThemeTokens tokens,
  ) {
    return DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: tokens.border),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: tokens.textSecondary,
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(
    TextTheme textTheme,
    AppThemeTokens tokens, {
    required Color background,
  }) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: background,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.onPrimary),
      actionTextColor: tokens.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smallAll,
        side: BorderSide(color: tokens.border),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      elevation: 0,
    );
  }

  static ChipThemeData _chipTheme(TextTheme textTheme, AppThemeTokens tokens) {
    return ChipThemeData(
      backgroundColor: tokens.surfaceAlt,
      selectedColor: tokens.secondaryContainer,
      labelStyle: textTheme.labelMedium,
      side: BorderSide(color: tokens.border),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tight),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    TextTheme textTheme,
    AppThemeTokens tokens,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: tokens.danger),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(
        color: tokens.primary,
      ),
      prefixIconColor: tokens.textMuted,
      suffixIconColor: tokens.textMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.input,
        vertical: AppSpacing.md,
      ),
      border: _outline(AppRadius.md, borderSide: BorderSide.none),
      enabledBorder: _outline(
        AppRadius.md,
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: _outline(
        AppRadius.md,
        borderSide: BorderSide(color: tokens.primary, width: 1.5),
      ),
      errorBorder: _outline(
        AppRadius.md,
        borderSide: BorderSide(color: tokens.danger),
      ),
      focusedErrorBorder: _outline(
        AppRadius.md,
        borderSide: BorderSide(color: tokens.danger, width: 1.5),
      ),
    );
  }

  static OutlineInputBorder _outline(double radius, {BorderSide? borderSide}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: borderSide ?? BorderSide.none,
    );
  }

  static ButtonStyle _filledButtonStyle(
    TextTheme textTheme,
    AppThemeTokens tokens,
  ) {
    return FilledButton.styleFrom(
      backgroundColor: tokens.primary,
      foregroundColor: tokens.onPrimary,
      disabledBackgroundColor: tokens.primary.withValues(alpha: 0.16),
      disabledForegroundColor: tokens.onPrimary.withValues(alpha: 0.38),
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      textStyle: textTheme.labelLarge?.copyWith(color: tokens.onPrimary),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.onPrimary.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.onPrimary.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _outlinedButtonStyle(
    TextTheme textTheme,
    AppThemeTokens tokens,
  ) {
    return OutlinedButton.styleFrom(
      foregroundColor: tokens.primary,
      disabledForegroundColor: tokens.primary.withValues(alpha: 0.38),
      backgroundColor: tokens.surface,
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      side: BorderSide(color: tokens.border),
      textStyle: textTheme.labelLarge,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.primary.withValues(alpha: 0.06);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _textButtonStyle(
    TextTheme textTheme,
    AppThemeTokens tokens,
  ) {
    return TextButton.styleFrom(
      foregroundColor: tokens.primary,
      disabledForegroundColor: tokens.primary.withValues(alpha: 0.38),
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
          return tokens.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.primary.withValues(alpha: 0.06);
        }
        return null;
      }),
    );
  }
}
