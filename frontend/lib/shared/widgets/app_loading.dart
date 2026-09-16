import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Centered loading indicator with an optional label.
///
/// Exposed as a live region for screen readers so assistive technology
/// announces progress instead of silence.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label, this.size = 32, this.color});

  /// Optional caption shown under the spinner.
  final String? label;

  /// Logical width/height of the spinner in px (default 32).
  final double size;

  /// Overrides the spinner color (defaults to the theme's progress color).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final progressColor =
        color ?? Theme.of(context).progressIndicatorTheme.color;
    return Semantics(
      liveRegion: true,
      label: label ?? 'Loading',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: progressColor,
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
