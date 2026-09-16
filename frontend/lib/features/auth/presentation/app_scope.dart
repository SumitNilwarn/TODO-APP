import 'package:flutter/widgets.dart';

import '../../../data/api/api_client.dart';
import 'auth_state.dart';

/// App-scoped dependencies exposed to every routed screen.
///
/// Backed by an [InheritedNotifier] of [AuthState], so descendants rebuild
/// whenever the session status (and every piece of the auth lifecycle) changes
/// without any extra state-management dependency.
///
/// Widget tree shape:
///
/// ```
/// AppScope(auth: _auth)
/// └─ MaterialApp(root …)
///    ├─ AuthGuard(publicOnly) → Login/Register/Home
///    └─ AuthGuard(protected)  → Profile/Dashboard/Tasks
/// ```
class AppScope extends InheritedNotifier<AuthState> {
  const AppScope({super.key, required AuthState auth, required super.child})
    : super(notifier: auth);

  /// Reads the surrounding [AppScope] (and subscribes to its notifier).
  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget');
    return scope!;
  }

  /// The session controller. Rebuilds the calling widget on auth changes.
  static AuthState authOf(BuildContext context) => of(context).notifier!;

  /// The authenticated [ApiClient] shared by all feature repositories.
  static ApiClient apiOf(BuildContext context) =>
      of(context).notifier!.apiClient;
}
