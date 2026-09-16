import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'features/auth/presentation/app_scope.dart';
import 'features/auth/presentation/auth_state.dart';
import 'presentation/router/app_router.dart';
import 'shared/theme/app_theme.dart';

/// Root widget of the Todo App.
///
/// Owns the single [AuthState] (and with it the authenticated HTTP transport)
/// and exposes it to every routed screen through [AppScope]. The session is
/// resolved on first frame so route guards know immediately whether the user
/// is signed in.
class TodoApp extends StatefulWidget {
  const TodoApp({
    super.key,
    this.initialRoute = AppRouter.home,
    this.authState,
  });

  /// Starting route; defaults to the home page. Overridable for tests.
  final String initialRoute;

  /// Optional pre-built session controller (tests, embedding). When `null` the
  /// app creates and owns its own [AuthState].
  final AuthState? authState;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late final AuthState _auth;
  late final bool _ownsAuth;

  @override
  void initState() {
    super.initState();
    _ownsAuth = widget.authState == null;
    _auth = widget.authState ?? AuthState();
    _auth.initialise();
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
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
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
    );
  }
}
