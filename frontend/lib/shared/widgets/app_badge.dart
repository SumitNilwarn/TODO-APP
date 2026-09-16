import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Semantic tone of an [AppBadge].
enum AppBadgeVariant { neutral, success, warning, danger, info }

/// Compact pill used for status, counts and tags. Kept quiet (tinted container
/// + strong foreground) so status is conveyed by shape/text as well as color.
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.showDot = false,
  });

  final String label;
  final AppBadgeVariant variant;

  /// Optional leading glyph.
  final IconData? icon;

  /// Renders a small status dot before the label.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final (foreground, container) = switch (variant) {
      AppBadgeVariant.neutral => (tokens.textSecondary, tokens.surfaceAlt),
      AppBadgeVariant.success => (
        tokens.success,
        tokens.success.withValues(alpha: 0.12),
      ),
      AppBadgeVariant.warning => (
        tokens.warning,
        tokens.warning.withValues(alpha: 0.12),
      ),
      AppBadgeVariant.danger => (
        tokens.danger,
        tokens.danger.withValues(alpha: 0.12),
      ),
      AppBadgeVariant.info => (
        tokens.info,
        tokens.info.withValues(alpha: 0.12),
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: container,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
