import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Standard app dialog: a rounded surface, header title, content and an action
/// row. Wraps `AlertDialog` so the theme's `dialogTheme` is the single source
/// of geometry and the app raisers stay out of feature code.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.icon,
  });

  final String title;
  final Widget content;

  /// Action widgets (e.g. [AppButton]s). Rendered right-aligned.
  final List<Widget>? actions;

  /// Optional leading glyph in the header.
  final IconData? icon;

  /// Convenience launcher for a simple content string.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget>? actions,
    IconData? icon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    return AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, size: 24, color: tokens.textSecondary),
      title: Text(title, style: textTheme.titleLarge),
      content: content,
      actions: actions,
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.tight,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    );
  }
}
