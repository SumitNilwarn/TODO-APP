import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';
import 'app_button.dart';

/// Friendly full-state placeholder when something goes wrong.
///
/// Generic on purpose — feature screens pass their own title/message and an
/// optional retry callback. Never renders error internals.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

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
          _StateIcon(icon: icon, color: tokens.danger),
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
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: retryLabel,
              variant: AppButtonVariant.outlined,
              expanded: true,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared round icon tile used by state widgets.
class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.appColors.surfaceAlt,
          borderRadius: AppRadius.xxlAll,
        ),
        child: Icon(icon, size: 30, color: color),
      ),
    );
  }
}
