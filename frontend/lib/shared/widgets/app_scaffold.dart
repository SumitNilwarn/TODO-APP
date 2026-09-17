import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import 'responsive_container.dart';

/// Standard page shell: consistent app bar, background and body layout.
///
/// When [constrainBody] is `true` (default), the body flows through
/// [ResponsiveContainer] so page contents align with the responsive strategy.
/// Colors, elevation and title styling come from the central `appBarTheme`
/// (see `app_theme.dart`).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.body,
    this.leading,
    this.actions,
    this.constrainBody = true,
    this.floatingActionButton,
  });

  /// Page title shown in the app bar.
  final String? title;
  final Widget? body;
  final Widget? leading;
  final List<Widget>? actions;
  final bool constrainBody;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null || leading != null || actions != null;

    return Scaffold(
      appBar: hasAppBar
          ? AppBar(
              backgroundColor: context.appColors.background,
              leading: leading,
              title: title == null ? null : Text(title!),
              actions: actions,
            )
          : null,
      body: SafeArea(
        child: constrainBody
            ? ResponsiveContainer(child: body ?? const SizedBox.shrink())
            : (body ?? const SizedBox.shrink()),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
