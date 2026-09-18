import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Lifts a surface with a subtle three-dimensional perspective tilt while the
/// pointer rests over it.
///
/// The motion is strictly hover-driven and one-shot: entering tilts the child
/// in over [duration], leaving reverses it — there are no repeating or
/// continuous animations, so `pumpAndSettle` settles exactly as with a static
/// subtree. When the user opts out of animations
/// (`MediaQuery.disableAnimations`) the child renders plainly (with the hover
/// scale still applied so the affordance is not lost entirely).
class PerspectiveTilt extends StatefulWidget {
  const PerspectiveTilt({
    super.key,
    required this.child,
    this.angle = 2.25,
    this.perspective = 1100,
    this.duration = AppDurations.normal,
    this.curve = AppCurves.standard,
    this.enabled = true,
  });

  final Widget child;

  /// Maximum tilt in degrees applied while hovering (kept ≤ 3 for calm feel).
  final double angle;

  /// Viewer distance for the perspective transform — smaller = more extreme.
  final double perspective;

  /// Time for the tilt to reach full travel.
  final Duration duration;

  final Curve curve;

  /// Disables the tilt entirely while keeping the child as-is.
  final bool enabled;

  @override
  State<PerspectiveTilt> createState() => _PerspectiveTiltState();
}

class _PerspectiveTiltState extends State<PerspectiveTilt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drive;
  bool _motionReduced = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
    );
    _drive = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionReduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter(PointerEnterEvent _) {
    if (!widget.enabled || _hovering || !mounted) return;
    _hovering = true;
    if (_motionReduced) return;
    _controller.forward();
  }

  void _exit(PointerExitEvent _) {
    if (!_hovering || !mounted) return;
    _hovering = false;
    if (_motionReduced) return;
    _controller.reverse();
  }

  Matrix4 _matrix(double t) {
    final radians = widget.angle * t * 0.0174533;
    final m = Matrix4.identity()
      ..setEntry(3, 2, -1 / widget.perspective)
      ..rotateX(radians * 0.35)
      ..rotateY(-radians)
      ..translateByDouble(0, 0, widget.perspective * 0.5 * t * 0.004, 1.0);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final reduced = _motionReduced;
    return MouseRegion(
      onEnter: _enter,
      onExit: _exit,
      cursor: MouseCursor.defer,
      child: reduced
          ? AnimatedScale(
              scale: _hovering ? 1.01 : 1,
              duration: widget.duration,
              curve: widget.curve,
              child: widget.child,
            )
          : AnimatedBuilder(
              animation: _drive,
              builder: (context, child) => Transform(
                transform: _matrix(_drive.value),
                alignment: Alignment.center,
                child: child,
              ),
              child: widget.child,
            ),
    );
  }
}
