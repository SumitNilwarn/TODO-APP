import 'package:flutter/material.dart';

import '../../theme/command_design_tokens.dart';
import '../../theme/design_tokens.dart';
import '../../theme/theme_extensions.dart';

/// A monospaced, wide-tracked, upper-cased technical label — the command
/// center's "readout" voice for overlines, field codes and metadata.
class TechLabel extends StatelessWidget {
  const TechLabel(
    this.label, {
    super.key,
    this.icon,
    this.color,
    this.trailing,
    this.letterSpacing = 1.4,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final style = CommandText.label(
      context,
      color: color,
    ).copyWith(letterSpacing: letterSpacing);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: style.color),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// A monospaced numeric/readout value with optional leading glyph and
/// trailing unit — pairs with [TechLabel] for data displays.
class TechReadout extends StatelessWidget {
  const TechReadout(this.value, {super.key, this.icon, this.color, this.unit});

  final String value;
  final IconData? icon;
  final Color? color;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final style = CommandText.value(context, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: style.color),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(value, style: style),
        if (unit != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            unit!,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 15) - 3,
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// A floating chrome surface — the elevated plane used for hero panels,
/// readout consoles and command cards.
///
/// Draws the theme's deep panel shadow, a hairline technical frame and an
/// optional ambient glow wash. Static by design (no tickers), so it is safe
/// in tests and with reduced motion.
class FloatingPanel extends StatelessWidget {
  const FloatingPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.radius = AppRadius.xl,
    this.color,
    this.showGlow = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  final Color? color;
  final bool showGlow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final command = context.commandTokens;
    final tint = accent ?? command.frame;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? tokens.border.withValues(alpha: 0.9),
        ),
        boxShadow: command.panelShadow,
      ),
      child: Stack(
        children: [
          if (showGlow)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.withValues(alpha: tint.a * 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A technical frame with HUD-style corner brackets drawn over [child].
///
/// Purely decorative chrome; the content stays fully interactive.
class CommandFrame extends StatelessWidget {
  const CommandFrame({
    super.key,
    required this.child,
    this.color,
    this.length = 18,
    this.strokeWidth = 1.4,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color? color;
  final double length;
  final double strokeWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.commandTokens.frame;
    return CustomPaint(
      painter: _CornerFramePainter(
        color: resolved,
        length: length,
        strokeWidth: strokeWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  _CornerFramePainter({
    required this.color,
    required this.length,
    required this.strokeWidth,
  });

  final Color color;
  final double length;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final l = length.clamp(0.0, size.shortestSide / 2).toDouble();
    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, l),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - l)
        ..lineTo(0, size.height)
        ..lineTo(l, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) =>
      old.color != color ||
      old.length != length ||
      old.strokeWidth != strokeWidth;
}

/// A numbered section marker for the design system laboratory — an index, a
/// short caption and a trailing rule.
class SectionMarker extends StatelessWidget {
  const SectionMarker({
    super.key,
    required this.index,
    required this.label,
    this.color,
  });

  final String index;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.commandTokens;
    final tint = color ?? context.appColors.textMuted;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(color: tokens.frame),
          ),
          child: Text(
            index.toUpperCase(),
            style: CommandText.label(context, color: tint),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: CommandText.label(context, color: tint),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Container(height: 1, color: tokens.frame)),
      ],
    );
  }
}
