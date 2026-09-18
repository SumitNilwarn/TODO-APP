import 'package:flutter/material.dart';

import '../../theme/command_design_tokens.dart';
import '../../theme/design_tokens.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/theme_scope.dart';
import 'command_chrome.dart';

/// Segmented WHITE / GRAPHITE theme control.
///
/// Renders nothing when no [ThemeScope] is present (e.g. when a widget is
/// pumped in isolation by a test), so embedding it in shared chrome is safe.
/// The segmented indicator animates with a finite [AnimatedContainer] and
/// respects reduced-motion through the platform's animation settings.
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key, this.expanded = false});

  /// Stretch to fill the available width (used in the sidebar footer).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    if (scope == null) return const SizedBox.shrink();

    final tokens = context.appColors;
    final graphite = scope.graphite;

    final control = Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _Option(
            label: 'White',
            icon: Icons.light_mode_outlined,
            selected: !graphite,
            onTap: () => scope.onChange(false),
            expand: expanded,
          ),
          const SizedBox(width: AppSpacing.xs),
          _Option(
            label: 'Graphite',
            icon: Icons.dark_mode_outlined,
            selected: graphite,
            onTap: () => scope.onChange(true),
            expand: expanded,
          ),
        ],
      ),
    );

    return Semantics(label: 'Theme', container: true, child: control);
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.expand,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final foreground = selected ? tokens.primary : tokens.textMuted;
    final segment = AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      padding: EdgeInsets.symmetric(
        horizontal: expand ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? tokens.surface : Colors.transparent,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: selected ? tokens.border : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: foreground),
          if (expand || selected) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: segment,
      ),
    );

    return expand ? Expanded(child: tappable) : tappable;
  }
}

/// Compact icon-only theme toggle for app bars and dense rows. Also renders
/// nothing without a [ThemeScope].
class ThemeSwitcherButton extends StatelessWidget {
  const ThemeSwitcherButton({super.key, this.tooltip = true});

  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    if (scope == null) return const SizedBox.shrink();

    final graphite = scope.graphite;
    final button = IconButton(
      onPressed: () => scope.onChange(!graphite),
      icon: Icon(
        graphite ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        size: 18,
      ),
      color: context.appColors.textSecondary,
    );
    if (!tooltip) return button;
    return Tooltip(
      message: graphite ? 'Switch to White theme' : 'Switch to Graphite theme',
      child: button,
    );
  }
}

/// A terminal-style identity chip used at the top of the sidebar: a brand mark
/// with a live status dot. Static; decorative only.
class CommandIdentity extends StatelessWidget {
  const CommandIdentity({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.grid_view_rounded,
  });

  final String? title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final command = context.commandTokens;
    return Row(
      children: [
        Container(
          width: AppSizes.brandMark,
          height: AppSizes.brandMark,
          decoration: BoxDecoration(
            color: tokens.primary,
            borderRadius: AppRadius.smAll,
            boxShadow: [
              BoxShadow(
                color: command.glowStrong,
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: tokens.onPrimary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              if (subtitle != null) ...[
                if (title != null) const SizedBox(height: 2),
                TechLabel(subtitle!, letterSpacing: 1.2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
