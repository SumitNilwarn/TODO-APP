import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Technical micro-label: a short, uppercase, letter-spaced kicker used as a
/// screen or section eyebrow ("OVERVIEW", "SYSTEM STATUS"…).
///
/// Purely presentational — it carries no keys, tools or semantics that tests
/// depend on, so it can sit above titles across cards, heroes and headers
/// without affecting existing test contracts.
class AppKicker extends StatelessWidget {
  const AppKicker({super.key, required this.label, this.icon, this.color});

  final String label;

  /// Optional small leading glyph (e.g. a tick or chevron).
  final IconData? icon;

  /// Overrides the default muted-gray accent color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final resolved = color ?? tokens.secondary;
    final base = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: resolved),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label.toUpperCase(),
          style: base?.copyWith(
            color: resolved,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
