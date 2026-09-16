import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Horizontal rule consistent with the theme's `dividerTheme`, optionally
/// carrying a short label between two hairlines.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.label, this.height = AppSpacing.lg});

  /// Optional caption centered between the lines.
  final String? label;

  /// Total height consumed by the divider (adds leading/trailing whitespace).
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (label == null) {
      return Divider(height: height, color: theme.dividerTheme.color);
    }

    final style = theme.textTheme.labelMedium?.copyWith(
      color: context.appColors.textMuted,
    );

    return SizedBox(
      height: height,
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: AppSpacing.md),
          Text(label!, style: style),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
