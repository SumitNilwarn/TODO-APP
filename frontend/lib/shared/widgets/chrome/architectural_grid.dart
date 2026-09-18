import 'package:flutter/material.dart';

import '../../theme/command_design_tokens.dart';
import '../../theme/design_tokens.dart';

/// A cinematic, architectural grid backdrop.
///
/// Paints a faint technical grid (a brighter major line every few steps) and
/// an optional soft radial glow behind [child]. Everything is static — no
/// tickers — so it never affects `pumpAndSettle` and costs nothing to leave
/// mounted behind scrollable content.
class ArchitecturalGrid extends StatelessWidget {
  const ArchitecturalGrid({
    super.key,
    required this.child,
    this.showGlow = true,
    this.glowAlignment = Alignment.topRight,
    this.step = CommandGrid.step,
    this.majorEvery = CommandGrid.majorEvery,
    this.gridOpacity = 1,
  });

  /// Content rendered above the backdrop.
  final Widget child;

  /// Whether the soft ambient glow is painted.
  final bool showGlow;

  /// Anchor of the radial glow within the painted bounds.
  final Alignment glowAlignment;

  /// Spacing between minor grid lines.
  final double step;

  /// Draw a major (brighter) line every Nth step.
  final int majorEvery;

  /// Multiplier applied to line/glow opacity (0 hides the grid).
  final double gridOpacity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.commandTokens;
    return CustomPaint(
      painter: _GridPainter(
        line: tokens.gridLine,
        major: tokens.gridMajor,
        glow: tokens.glow,
        glowAlignment: glowAlignment,
        step: step,
        majorEvery: majorEvery,
        showGlow: showGlow,
        opacity: gridOpacity.clamp(0, 1),
      ),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.line,
    required this.major,
    required this.glow,
    required this.glowAlignment,
    required this.step,
    required this.majorEvery,
    required this.showGlow,
    required this.opacity,
  });

  final Color line;
  final Color major;
  final Color glow;
  final Alignment glowAlignment;
  final double step;
  final int majorEvery;
  final bool showGlow;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (showGlow && glow.a > 0) {
      final center = glowAlignment.alongSize(size);
      final radius = size.shortestSide * 0.95;
      final shader = RadialGradient(
        colors: [
          glow.withValues(alpha: glow.a * opacity),
          glow.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    }

    if (step <= 0 || opacity <= 0) return;
    final minorPaint = Paint()
      ..color = line.withValues(alpha: line.a * opacity)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = major.withValues(alpha: major.a * opacity)
      ..strokeWidth = 1;

    var index = 0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % majorEvery == 0 ? majorPaint : minorPaint,
      );
      index++;
    }
    index = 0;
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % majorEvery == 0 ? majorPaint : minorPaint,
      );
      index++;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) {
    return old.line != line ||
        old.major != major ||
        old.glow != glow ||
        old.glowAlignment != glowAlignment ||
        old.step != step ||
        old.majorEvery != majorEvery ||
        old.showGlow != showGlow ||
        old.opacity != opacity;
  }
}

/// A soft radial glow orb, useful as an ambient light source behind hero
/// panels without painting a full grid.
class GlowOrb extends StatelessWidget {
  const GlowOrb({
    super.key,
    this.size = 420,
    this.color,
    this.intensity = 1,
    this.child,
  });

  final double size;
  final Color? color;
  final double intensity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final glow = color ?? context.commandTokens.glow;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              glow.withValues(alpha: (glow.a * intensity).clamp(0, 1)),
              glow.withValues(alpha: 0),
            ],
          ),
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

/// Thin technical rule with a terminal-style end cap — used to separate
/// regions of the command center.
class CommandRule extends StatelessWidget {
  const CommandRule({super.key, this.height = AppSpacing.lg, this.accent});

  final double height;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.commandTokens;
    final color = accent ?? tokens.frame;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Container(width: 10, height: 2, color: color),
          Expanded(child: Container(height: 1, color: color)),
        ],
      ),
    );
  }
}
