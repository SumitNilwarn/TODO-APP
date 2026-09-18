import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'features/auth/presentation/app_scope.dart';
import 'features/auth/presentation/auth_state.dart';
import 'presentation/router/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_preferences.dart';
import 'shared/theme/theme_scope.dart';

/// Root widget of the Todo App.
///
/// Owns the single [AuthState] (and with it the authenticated HTTP transport)
/// and exposes it to every routed screen through [AppScope]. The session is
/// resolved on first frame so route guards know immediately whether the user
/// is signed in. The WHITE / GRAPHITE theme preference is owned here as well,
/// restored from `localStorage` on the web and shared through [ThemeScope].
class TodoApp extends StatefulWidget {
  const TodoApp({
    super.key,
    this.initialRoute = AppRouter.home,
    this.authState,
    this.graphite = true,
    this.dark,
  });

  /// Starting route; defaults to the home page. Overridable for tests.
  final String initialRoute;

  /// Optional pre-built session controller (tests, embedding). When `null` the
  /// app creates and owns its own [AuthState].
  final AuthState? authState;

  /// Starting theme preference; defaults to GRAPHITE (the cinematic look).
  /// Overridable for tests.
  final bool graphite;

  /// Legacy alias for [graphite] (previous `dark` semantics). When provided it
  /// wins over [graphite].
  final bool? dark;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late final AuthState _auth;
  late final bool _ownsAuth;
  late bool _graphite;

  @override
  void initState() {
    super.initState();
    _ownsAuth = widget.authState == null;
    _auth = widget.authState ?? AuthState();
    _graphite = _resolveInitialTheme();
    _auth.initialise();
  }

  bool _resolveInitialTheme() {
    final explicit = widget.dark ?? widget.graphite;
    switch (ThemePreferences.storedMode) {
      case ThemePreferences.white:
        return false;
      case ThemePreferences.graphite:
        return true;
    }
    return explicit;
  }

  void _switchTheme(bool graphite) {
    setState(() => _graphite = graphite);
    ThemePreferences.persist(graphite ? 'graphite' : 'white');
  }

  @override
  void dispose() {
    if (_ownsAuth) {
      _auth.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: _auth,
      child: ThemeScope(
        graphite: _graphite,
        onChange: _switchTheme,
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.white(),
          darkTheme: AppTheme.graphite(),
          themeMode: _graphite ? ThemeMode.dark : ThemeMode.light,
          initialRoute: widget.initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) {
            // Keep the page background uniform while async pages load.
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.6,
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
