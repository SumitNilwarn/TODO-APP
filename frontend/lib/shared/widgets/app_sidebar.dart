import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

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
/// Renders a brand row, the navigation list and a footer slot (user/actions).
/// Navigation items expose full keyboard focus, hover/press overlays and a
/// selected state; the container itself stays quiet so it works inside a
/// desktop `Row`, a `Drawer` or a narrow rail.
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
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    final brand = Row(
      children: [
        Container(
          width: AppSizes.brandMark,
          height: AppSizes.brandMark,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.primary,
            borderRadius: AppRadius.mediumAll,
          ),
          child: Icon(
            brandIcon,
            size: 18,
            color: tokens.onPrimary,
            semanticLabel: brandTitle,
          ),
        ),
        if (brandTitle != null) ...[
          const SizedBox(width: AppSpacing.tight),
          Flexible(
            child: Text(
              brandTitle!,
              style: textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      width: AppSizes.sidebarWidth,
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
            child: brand,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SidebarItem(
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
          if (footer != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

/// Rounded navigation row with focus, hover, press and selected states.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected, this.onTap});

  final AppNavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    final background = selected ? tokens.surfaceAlt : Colors.transparent;
    final fg = selected ? tokens.textPrimary : tokens.textSecondary;
    final labelStyle = textTheme.labelMedium?.copyWith(color: fg);
    final icon = (selected && item.selectedIcon != null)
        ? item.selectedIcon!
        : item.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: AppRadius.mediumAll,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return tokens.primary.withValues(alpha: 0.04);
          }
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
          ),
          child: Row(
            children: [
              // A quiet three-point accent bar marks the active destination.
              if (selected) ...[
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 3),
              ],
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Text(item.label, style: labelStyle, maxLines: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
