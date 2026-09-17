import 'package:flutter/material.dart';

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
/// adds the calm drop shadow (in dark mode the elevation is expressed as a
/// crisp hairline edge instead, since shadows vanish on dark surfaces). When
/// [interactive] (or [onTap]) is set the card becomes focusable/clickable with
/// a ripple, hover overlay and pointer cursor — plus a gentle lift: the border
/// and shadow deepen smoothly on hover.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.variant = AppCardVariant.standard,
    this.color,
    this.radius = AppRadius.xlAll,
    this.interactive = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;

  /// Surface color; defaults to the theme's [AppThemeTokens.surface] so cards
  /// adapt automatically to the light/dark palette.
  final Color? color;

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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  bool get _isInteractive => widget.interactive || widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.appColors;
    final color = widget.color ?? tokens.surface;

    final restShadow = switch (widget.variant) {
      AppCardVariant.standard => null,
      AppCardVariant.elevated => isDark ? null : AppShadows.subtle,
    };
    final raisedShadow = switch (widget.variant) {
      AppCardVariant.standard => AppShadows.none,
      AppCardVariant.elevated => isDark ? null : AppShadows.raised,
    };

    BoxDecoration decoration({required bool raised}) {
      return BoxDecoration(
        color: color,
        borderRadius: widget.radius,
        border: Border.all(color: raised ? tokens.border : tokens.subtleBorder),
        boxShadow: raised ? raisedShadow : restShadow,
      );
    }

    final content = Padding(padding: widget.padding, child: widget.child);

    if (!_isInteractive) {
      return Container(decoration: decoration(raised: false), child: content);
    }

    // AnimatedBoxDecoration lerps the hairline border and shadow while the
    // pointer hovers, so the card "lifts" without any layout shift.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        focusable: true,
        label: widget.semanticLabel,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: widget.radius),
          clipBehavior: Clip.antiAlias,
          child: TweenAnimationBuilder<BoxDecoration>(
            tween: Tween<BoxDecoration>(
              begin: decoration(raised: false),
              end: decoration(raised: _hovered),
            ),
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            builder: (context, animated, _) => Ink(
              decoration: animated,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: RoundedRectangleBorder(
                  borderRadius: widget.radius,
                ),
                mouseCursor: widget.onTap == null
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return tokens.primary.withValues(alpha: 0.04);
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return tokens.primary.withValues(alpha: 0.08);
                  }
                  if (states.contains(WidgetState.focused)) {
                    return tokens.primary.withValues(alpha: 0.06);
                  }
                  return null;
                }),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
