import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'app_kicker.dart';

/// Consistent page introduction block: optional kicker, title, optional
/// subtitle, a leading element and trailing action row. Used at the top of
/// every routed page so heading hierarchy and vertical rhythm stay uniform.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.kicker,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  /// Technical micro-label rendered above the title (see [AppKicker]).
  final String? kicker;

  /// Page title (rendered with `headlineMedium` — the dominant heading role).
  final String? title;

  /// Supporting description under the title.
  final String? subtitle;

  /// Optional leading widget (avatar, icon, brand mark).
  final Widget? leading;

  /// Optional trailing action widgets (e.g. [AppButton]s).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final textBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker != null) ...[
          AppKicker(label: kicker!),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (title != null) Text(title!, style: textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(
              color: textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );

    final actionsLine = actions == null || actions!.isEmpty
        ? null
        : Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions!,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(child: textBlock),
          if (actionsLine != null) ...[
            const SizedBox(width: AppSpacing.md),
            Flexible(child: actionsLine),
          ],
        ],
      ),
    );
  }
}
