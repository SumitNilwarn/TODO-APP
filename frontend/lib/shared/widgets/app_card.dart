import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Surface presentation of an [AppCard].
enum AppCardVariant {
  /// Flat, calm surface with a hairline border and no shadow.
  standard,

  /// Raised surface with the soft [AppShadows.subtle] elevation.
  elevated,
}

/// A soft, rounded surface — the base container for cards, panels and
/// call-outs.
///
/// [AppCardVariant.standard] is the quiet default; [AppCardVariant.elevated]
/// adds the calm drop shadow. When [interactive] (or [onTap]) is set the card
/// becomes focusable/clickable with a ripple, hover overlay and pointer cursor.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.variant = AppCardVariant.standard,
    this.color = AppColors.surface,
    this.radius = AppRadius.xlAll,
    this.interactive = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;
  final Color color;
  final BorderRadiusGeometry radius;

  /// When `true`, renders on hover/focus states plus a ripple and a pointer
  /// cursor, and the card is announced as a button.
  final bool interactive;

  /// Invoked when a clickable card is activated. `null` with [interactive]
  /// still renders the affordances but performs no action.
  final VoidCallback? onTap;

  /// Overrides the announced label for screen readers on interactive cards.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isInteractive = interactive || onTap != null;
    final boxShadow = switch (variant) {
      AppCardVariant.standard => null,
      AppCardVariant.elevated => AppShadows.subtle,
    };

    final decoration = BoxDecoration(
      color: color,
      borderRadius: radius,
      border: Border.all(color: AppColors.subtleBorder),
      boxShadow: boxShadow,
    );

    final content = Padding(padding: padding, child: child);

    if (!isInteractive) {
      return Container(decoration: decoration, child: content);
    }

    return Semantics(
      button: true,
      focusable: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            mouseCursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return context.appColors.primary.withValues(alpha: 0.04);
              }
              if (states.contains(WidgetState.pressed)) {
                return context.appColors.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return context.appColors.primary.withValues(alpha: 0.06);
              }
              return null;
            }),
            child: content,
          ),
        ),
      ),
    );
  }
}
