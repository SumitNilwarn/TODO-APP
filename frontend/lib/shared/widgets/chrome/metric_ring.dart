import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/theme_extensions.dart';
import 'command_chrome.dart';

/// A circular gauge used by the command center to visualize a single
/// proportion (e.g. completion rate).
///
/// Animates the arc once on mount with a finite tween; when the platform
/// disables animations the final arc renders immediately, so reduced-motion
/// users see no sweep and tests can settle.
class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.value,
    this.label,
    this.size = 128,
    this.strokeWidth = 9,
    this.color,
    this.center,
    this.trackColor,
  });

  /// Progress in the range 0..1 (clamped).
  final double value;
  final String? label;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? center;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final tint = color ?? tokens.primary;
    final track = trackColor ?? tokens.surfaceAlt;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: reduced ? Duration.zero : AppDurations.slow,
      curve: AppCurves.decelerate,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animated,
              tint: tint,
              track: track,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child:
                  center ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TechReadout(
                        '${(target * 100).round()}%',
                        color: tokens.textPrimary,
                      ),
                      if (label != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TechLabel(label!),
                      ],
                    ],
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.tint,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color tint;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;
    final arcPaint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.tint != tint ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

/// A slim horizontal proportion bar — the compact companion to [MetricRing]
/// for per-status breakdowns.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
    this.radius = AppRadius.pill,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor ?? tokens.surfaceAlt),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? tokens.primary),
            ),
          ],
        ),
      ),
    );
  }
}
