import 'package:flutter/widgets.dart';

/// App-scoped theme preference (light/dark) so any screen — e.g. the sidebar
/// footer — can read the current mode and switch it.
///
/// The root [TodoApp] owns the boolean state and rebuilds `MaterialApp`'s
/// `themeMode`, which animates the palette change through the built-in theme
/// transition.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.dark,
    required this.onToggle,
    required super.child,
  });

  /// Whether the app currently renders the dark theme.
  final bool dark;

  /// Flips the theme preference.
  final VoidCallback onToggle;

  static ThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope found above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) {
    return oldWidget.dark != dark || oldWidget.onToggle != onToggle;
  }
}
