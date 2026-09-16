import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/features/home/presentation/home_page.dart';
import 'package:todo_app/shared/theme/app_colors.dart';
import 'package:todo_app/shared/theme/app_theme.dart';
import 'package:todo_app/shared/theme/theme_extensions.dart';

void main() {
  testWidgets('the app applies the light Todo App theme', (tester) async {
    await tester.pumpWidget(const TodoApp());

    final context = tester.element(find.byType(HomePage));
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.error, AppColors.danger);

    // Typography hierarchy is defined with semantic roles.
    expect(theme.textTheme.headlineMedium, isNotNull);
    expect(theme.textTheme.titleLarge, isNotNull);
    expect(theme.textTheme.titleMedium, isNotNull);
    expect(theme.textTheme.bodyLarge, isNotNull);
    expect(theme.textTheme.bodyMedium, isNotNull);
    expect(theme.textTheme.bodySmall, isNotNull);
    expect(theme.textTheme.labelLarge, isNotNull);

    // Inputs are filled, rounded and get an ink focus border.
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.focusedBorder, isA<OutlineInputBorder>());
    expect(theme.inputDecorationTheme.contentPadding, isNotNull);

    // The primary CTA is the dark ink surface.
    final filledStyle = theme.filledButtonTheme.style;
    expect(filledStyle, isNotNull);
  });

  test('AppTheme.light exposes a coherent hierarchy and tokens', () {
    final theme = AppTheme.light();

    expect(theme.textTheme.headlineMedium?.fontSize, 30);
    expect(theme.textTheme.headlineMedium?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodySmall?.color, AppColors.muted);
    expect(theme.filledButtonTheme.style, isNotNull);
    expect(theme.inputDecorationTheme.focusedBorder, isA<OutlineInputBorder>());

    // Phase 10: the full display/heading/label ladder is defined.
    expect(theme.textTheme.displayLarge, isNotNull);
    expect(theme.textTheme.headlineLarge, isNotNull);
    expect(theme.textTheme.headlineSmall, isNotNull);
    expect(theme.textTheme.labelLarge?.fontSize, 16);
    expect(theme.textTheme.labelMedium, isNotNull);
    expect(theme.textTheme.labelSmall, isNotNull);

    // Semantic color roles resolve to the shared palette.
    final tokens = theme.extension<AppThemeTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.primary, AppColors.primary);
    expect(tokens.secondary, AppColors.secondary);
    expect(tokens.textPrimary, AppColors.textPrimary);
    expect(tokens.textMuted, AppColors.textMuted);
    expect(tokens.danger, AppColors.danger);
    expect(tokens.background, AppColors.background);

    // Component themes are wired through ThemeData.
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.appBarTheme.backgroundColor, AppColors.background);
    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.dialogTheme.backgroundColor, AppColors.surface);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.shape, isNotNull);
    expect(theme.chipTheme.shape, isNotNull);
    expect(theme.progressIndicatorTheme.color, AppColors.ink);
  });
}
