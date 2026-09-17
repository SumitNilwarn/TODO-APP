import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Calm, centered placeholder for "nothing to show yet".
///
/// Used by the routing placeholders today and by feature empty states (e.g. an
/// empty task list) in later phases.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Optional action widget (e.g. an [AppButton]).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: AppRadius.xxlAll,
              ),
              child: Icon(icon, size: 30, color: tokens.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
