import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../motion/perspective_tilt.dart';
import 'command_chrome.dart';

/// A cinematic 3D surface: a [FloatingPanel] lifted on the theme's deep panel
/// shadow and, by default, tilted subtly in perspective while hovered.
///
/// [PerspectiveTilt] already respects reduced-motion preferences, so the card
/// degrades to a plain elevated panel when animations are disabled. No
/// continuous tickers are involved.
class DepthCard extends StatelessWidget {
  const DepthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.radius = AppRadius.xl,
    this.color,
    this.showGlow = true,
    this.enabled = true,
    this.tilt = true,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  final Color? color;
  final bool showGlow;
  final bool enabled;
  final bool tilt;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget surface = FloatingPanel(
      padding: padding,
      accent: accent,
      radius: radius,
      color: color,
      showGlow: showGlow,
      child: child,
    );
    if (tilt) {
      surface = PerspectiveTilt(angle: 1.6, enabled: enabled, child: surface);
    }
    if (onTap != null) {
      surface = Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(radius),
          child: surface,
        ),
      );
    } else if (semanticLabel != null) {
      surface = Semantics(
        container: true,
        label: semanticLabel,
        child: surface,
      );
    }
    return surface;
  }
}

/// A stage that presents [child] at a fixed three-dimensional angle, with an
/// optional [accentChild] floating in front — used for cinematic hero
/// consoles. The transform is static (no ticker), so it is safe under reduced
/// motion and in tests.
class PerspectiveStage extends StatelessWidget {
  const PerspectiveStage({
    super.key,
    required this.child,
    this.accentChild,
    this.angleY = 0.16,
    this.angleX = 0.05,
    this.perspective = 1400,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Widget? accentChild;
  final double angleY;
  final double angleX;
  final double perspective;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: alignment,
      transform: Matrix4.identity()
        ..setEntry(3, 2, -1 / perspective)
        ..rotateX(angleX)
        ..rotateY(angleY),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (accentChild != null)
            Positioned(
              right: -AppSpacing.lg,
              bottom: -AppSpacing.lg,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, -1 / perspective)
                  ..rotateY(-angleY * 0.6),
                child: accentChild!,
              ),
            ),
        ],
      ),
    );
  }
}
