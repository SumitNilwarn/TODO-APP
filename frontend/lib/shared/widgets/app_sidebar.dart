import 'package:flutter/material.dart';

import '../theme/command_design_tokens.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';
import 'chrome/architectural_grid.dart';
import 'chrome/command_chrome.dart';
import 'chrome/theme_switcher.dart';

/// A single navigation destination in the sidebar.
@immutable
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.tooltip,
  });

  /// Accessible label (also the visible text).
  final String label;

  /// Leading icon for the destination.
  final IconData icon;

  /// Optional alternate icon shown while selected.
  final IconData? selectedIcon;

  /// Optional hover/focus hint.
  final String? tooltip;
}

/// Persistent navigation rail, driven by the same component on every screen.
///
/// The command-center chrome: a technical brand identity, an indexed
/// navigation list with a glowing active rail, a theme switcher and the
/// caller's footer slot. Navigation items keep full keyboard focus,
/// hover/press overlays and a selected state, so behavior is unchanged — only
/// the material language is richer.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    this.items = const [],
    this.selectedIndex,
    this.onSelect,
    this.brandTitle,
    this.brandIcon = Icons.checklist,
    this.footer,
    this.header,
  });

  /// Ordered destinations rendered below the brand.
  final List<AppNavItem> items;

  /// Index of the active destination (highlighted), or `null` for none.
  final int? selectedIndex;

  /// Invoked with the tapped [AppNavItem].
  final ValueChanged<AppNavItem>? onSelect;

  /// Product name shown next to the brand mark.
  final String? brandTitle;

  /// Brand mark glyph. Defaults to the task-checklist glyph.
  final IconData brandIcon;

  /// Optional widget rendered above the navigation list.
  final Widget? header;

  /// Optional widget pinned at the bottom (user slot, actions, version).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return SizedBox(
      width: AppSizes.sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.surfaceElevated, tokens.background],
          ),
          border: Border(right: BorderSide(color: tokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommandIdentity(
                    title: brandTitle,
                    subtitle: brandTitle == null ? null : 'Command center',
                    icon: brandIcon,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CommandRule(height: AppSpacing.md),
                ],
              ),
            ),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: header!,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.md,
                      bottom: AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: TechLabel('Navigation', icon: Icons.blur_on_rounded),
                  ),
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _SidebarItem(
                        index: i,
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(items[i]),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.page,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CommandRule(height: AppSpacing.lg),
                  const SizedBox(height: AppSpacing.md),
                  const ThemeSwitcher(expanded: true),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded navigation row with focus, hover, press and selected states,
/// refinished with an indexed readout and a glowing active rail.
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.index,
    required this.item,
    required this.selected,
    this.onTap,
  });

  final int index;
  final AppNavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final command = context.commandTokens;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;
    final selected = widget.selected;
    final hovered = _hovered;

    final background = selected
        ? tokens.selectedSurface
        : hovered
        ? tokens.hoverSurface
        : Colors.transparent;
    final fg = selected
        ? tokens.textPrimary
        : hovered
        ? tokens.textPrimary
        : tokens.textSecondary;
    final labelStyle = textTheme.labelMedium?.copyWith(color: fg);
    final icon = (selected && item.selectedIcon != null)
        ? item.selectedIcon!
        : item.icon;
    final code = (widget.index + 1).toString().padLeft(2, '0');

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.mediumAll,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return tokens.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return tokens.primary.withValues(alpha: 0.05);
            }
            return null;
          }),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.enter,
            height: AppSizes.navItemHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadius.mediumAll,
              border: Border.all(
                color: selected
                    ? command.frame
                    : hovered
                    ? tokens.border
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: command.glow,
                        blurRadius: 16,
                        spreadRadius: -6,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // A quiet glowing rail marks the active destination.
                AnimatedContainer(
                  duration: AppDurations.fast,
                  curve: AppCurves.enter,
                  width: 3,
                  height: selected ? 22 : 0,
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    borderRadius: AppRadius.pillAll,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: command.glowStrong,
                              blurRadius: 10,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 3),
                AnimatedSlide(
                  offset: hovered && !selected
                      ? const Offset(0.18, 0)
                      : Offset.zero,
                  duration: AppDurations.fast,
                  curve: AppCurves.standard,
                  child: Icon(icon, size: 20, color: fg),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: AppDurations.fast,
                    curve: AppCurves.standard,
                    style: labelStyle!,
                    child: Text(item.label, maxLines: 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  code,
                  style: CommandText.label(
                    context,
                    color: selected ? tokens.textSecondary : tokens.textMuted,
                  ).copyWith(letterSpacing: 0.5, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
