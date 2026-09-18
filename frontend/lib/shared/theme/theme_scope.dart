import 'package:flutter/widgets.dart';

/// App-scoped theme preference so any screen — e.g. the sidebar theme
/// switcher — can read the current mode and switch it.
///
/// The root [TodoApp] owns the boolean and rebuilds `MaterialApp`'s
/// `themeMode` with the WHITE / GRAPHITE pair, which animates the palette
/// change through the built-in theme transition.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.graphite,
    required this.onChange,
    required super.child,
  });

  /// Whether the app currently renders the GRAPHITE theme (the cinematic
  /// default). `false` renders WHITE.
  final bool graphite;

  /// Flipped the active theme; receives the new `graphite` value.
  final ValueChanged<bool> onChange;

  /// Backwards-compatible alias — graphite is the app's "dark" mode.
  bool get dark => graphite;

  /// Backwards-compatible toggle for callers that only flip the mode.
  VoidCallback get onToggle =>
      () => onChange(!graphite);

  static ThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope found above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) {
    return oldWidget.graphite != graphite || oldWidget.onChange != onChange;
  }
}
