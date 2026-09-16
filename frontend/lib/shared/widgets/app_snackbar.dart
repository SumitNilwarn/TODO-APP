import 'package:flutter/material.dart';

/// Semantic tone of a transient feedback message.
enum AppFeedbackVariant { info, success, warning, danger }

/// Transient feedback — the app-wide snackbar wrapper.
///
/// Uses the theme's `snackBarTheme` (floating, rounded, dark neutral ink) and
/// swaps the surface color to the requested [AppFeedbackVariant]. Announced by
/// screen readers via ScaffoldMessenger semantics.
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    AppFeedbackVariant variant = AppFeedbackVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction ?? () {},
                ),
          backgroundColor: switch (variant) {
            AppFeedbackVariant.info => Theme.of(
              context,
            ).snackBarTheme.backgroundColor,
            AppFeedbackVariant.success => const Color(0xFF2F5A33),
            AppFeedbackVariant.warning => const Color(0xFF7A5300),
            AppFeedbackVariant.danger => const Color(0xFF7A1F1A),
          },
        ),
      );
  }
}
