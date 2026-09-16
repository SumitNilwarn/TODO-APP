import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Semantic tone of an inline alert banner.
enum AppInlineAlertVariant { danger, info }

/// Non-blocking inline message banner (errors, notices) shown inside a card or
/// form.
///
/// The single sanctioned banner for inline validation messages: still
/// themed through the design tokens, announced by screen readers as a live
/// region, and always rendered with a leading glyph. Prefer this over bespoke
/// per-screen banner containers.
class AppInlineAlert extends StatelessWidget {
  const AppInlineAlert({
    super.key,
    required this.message,
    this.variant = AppInlineAlertVariant.danger,
  });

  final String message;
  final AppInlineAlertVariant variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    final (tone, icon) = switch (variant) {
      AppInlineAlertVariant.danger => (
        tokens.danger,
        Icons.error_outline_rounded,
      ),
      AppInlineAlertVariant.info => (tokens.info, Icons.info_outline_rounded),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: tone.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tone),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
