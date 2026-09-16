import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Single-choice status chip used by the filter bars (tasks, dashboard).
///
/// Centralizes the selected/unselected styling (secondary-container fill,
/// quiet unselected label, no checkmark) so every filter bar renders
/// identically and stays consistent with the design tokens.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  /// Visible (and accessible) chip label.
  final String label;

  final bool selected;

  /// Invoked when the chip is activated.
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: tokens.secondaryContainer,
      labelStyle: TextStyle(
        color: selected ? tokens.onSecondaryContainer : tokens.textSecondary,
      ),
    );
  }
}

/// Toggle chip with an optional semantic accent (e.g. danger for
/// "Overdue only").
///
/// Same base behavior as [AppChoiceChip] but tints the active state with a
/// caller-chosen semantic color instead of the neutral secondary fill.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.activeColor,
  });

  /// Active-state accent color for the fill and label. When `null` the chip
  /// falls back to the neutral secondary-container treatment of
  /// [AppChoiceChip].
  final Color? activeColor;

  /// Visible (and accessible) chip label.
  final String label;

  final bool selected;

  /// Invoked when the chip is toggled.
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final accent = activeColor;
    final (fill, labelColor) = accent == null
        ? (
            tokens.secondaryContainer,
            selected ? tokens.onSecondaryContainer : tokens.textSecondary,
          )
        : (
            accent.withValues(alpha: 0.12),
            selected ? accent : tokens.textSecondary,
          );

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: fill,
      labelStyle: TextStyle(color: labelColor),
    );
  }
}
