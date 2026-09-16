import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';
import 'app_page_header.dart';
import 'app_sidebar.dart';

/// Application shell: renders the brand + navigation sidebar and the routed
/// page content with an optional page header.
///
/// Responsive behavior:
/// - **Compact (< 600):** navigation collapses behind a `Drawer`; content and
///   the page header flow vertically with a top app bar.
/// - **Tablet/Desktop (≥ 600):** the [AppSidebar] stays pinned on the left and
///   content flows beside it, centered through [ResponsiveContainer] via the
///   caller (or the optional [ResponsiveContainer]-based [body]).
///
/// No navigation logic lives here — [navItems] + [selectedIndex] + [onSelect]
/// are passed in so every feature keeps owning its routing.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.navItems = const [],
    this.selectedIndex,
    this.onSelect,
    this.footer,
    this.brandTitle,
  });

  /// Rendered page body (already constrained/scrolled by the caller).
  final Widget body;

  /// Page title shown in the header (and compact app bar).
  final String? title;

  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;

  /// Destinations for the sidebar / drawer.
  final List<AppNavItem> navItems;

  /// Index of the active destination.
  final int? selectedIndex;

  /// Invoked with the tapped destination.
  final ValueChanged<AppNavItem>? onSelect;

  /// Footer slot for the sidebar (user/actions).
  final Widget? footer;

  final String? brandTitle;

  @override
  Widget build(BuildContext context) {
    final layout = AppScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    final compact = layout == AppScreenSize.compact;

    if (compact) {
      return _compact(context);
    }
    return _wide(context, layout);
  }

  /// Compact shell: drawer navigation + header + content.
  Widget _compact(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(brandTitle ?? title ?? ''),
      ),
      drawer: Drawer(
        backgroundColor: context.appColors.surface,
        child: SafeArea(
          child: AppSidebar(
            items: navItems,
            selectedIndex: selectedIndex,
            onSelect: (item) {
              Navigator.of(context).pop();
              onSelect?.call(item);
            },
            brandTitle: brandTitle,
            footer: footer,
          ),
        ),
      ),
      body: SafeArea(
        child: _Content(
          title: title,
          subtitle: subtitle,
          leading: leading,
          actions: actions,
          body: body,
          compact: true,
        ),
      ),
    );
  }

  /// Tablet/desktop shell: pinned sidebar beside the page content.
  Widget _wide(BuildContext context, AppScreenSize layout) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              border: Border(
                right: BorderSide(color: context.appColors.border),
              ),
            ),
            child: SafeArea(
              child: AppSidebar(
                items: navItems,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                brandTitle: brandTitle,
                footer: footer,
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: _Content(
                title: title,
                subtitle: subtitle,
                leading: leading,
                actions: actions,
                body: body,
                compact: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
    required this.compact,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? AppSpacing.page : AppSpacing.xl,
            compact ? AppSpacing.lg : AppSpacing.xl,
            compact ? AppSpacing.page : AppSpacing.xl,
            0,
          ),
          child: AppPageHeader(
            title: title,
            subtitle: subtitle,
            leading: leading,
            actions: actions,
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
