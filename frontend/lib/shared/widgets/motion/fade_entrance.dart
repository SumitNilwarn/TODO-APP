import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Fades (and gently slides) a subtree into view once on mount.
///
/// Built entirely on a single finite [AnimationController] — the optional
/// [delay] is folded into the easing curve (`Interval`), so there are no timers
/// or repeating animations to leak or keep a frame pump busy. When the user
/// opts out of animations (`MediaQuery.disableAnimations`) the child renders
/// immediately without any motion.
class FadeEntrance extends StatefulWidget {
  const FadeEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.slow,
    this.offset = const Offset(0, 12),
    this.curve = AppCurves.enter,
  });

  final Widget child;

  /// Optional leading pause before the entrance starts (used for stagger).
  final Duration delay;

  /// Duration of the fade/slide once it starts.
  final Duration duration;

  /// Start distance the child travels (fades out of — `zero` disables slide).
  final Offset offset;

  final Curve curve;

  @override
  State<FadeEntrance> createState() => _FadeEntranceState();
}

class _FadeEntranceState extends State<FadeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionReduced = false;
  bool _started = false;

  Duration get _total => widget.delay + widget.duration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _motionReduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Reduced motion renders the child immediately; the animation is a
    // one-shot entrance so it is simply skipped.
    if (!_motionReduced) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_motionReduced) {
      return widget.child;
    }
    final total = _total;
    final begin = total.inMicroseconds == 0
        ? 0.0
        : (widget.delay.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1.0, curve: widget.curve),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
