import 'package:flutter/material.dart';

import '../../../presentation/router/app_router.dart';
import '../../../shared/widgets/app_loading.dart';
import '../domain/auth_models.dart';
import 'app_scope.dart';

/// Access policy of a routed screen, driving [AuthGuard] behavior.
enum AuthPolicy {
  /// The screen must not be shown to signed-in users; authenticated callers
  /// are redirected to the app (login/register/landing).
  publicOnly,

  /// The screen requires a valid session; unauthenticated callers are
  /// redirected to the login screen (profile/dashboard/tasks).
  protected,
}

/// Route-level gate between the [AppRouter] and a feature screen.
///
/// - While the session is still being resolved ([AuthStatus.unknown] on a
///   protected route) the guard renders a quiet loading view instead of
///   flashing the page.
/// - [AuthPolicy.protected] redirects unauthenticated callers to
///   `AppRouter.login`, preserving the attempted route as the `from` argument
///   so a successful sign-in returns the user exactly where they started.
/// - [AuthPolicy.publicOnly] redirects authenticated callers to the `from`
///   target (when one was supplied) or the home landing otherwise.
///
/// The guard only redirects while its own route is current, and only once per
/// state, so navigation never races or loops.
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key, required this.policy, required this.child});

  final AuthPolicy policy;
  final Widget child;

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _scheduled = false;

  @override
  void didUpdateWidget(covariant AuthGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      _scheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.authOf(context);
    final status = auth.status;

    if (widget.policy == AuthPolicy.protected && status == AuthStatus.unknown) {
      return const Scaffold(
        body: SafeArea(child: AppLoading(label: 'Checking your session…')),
      );
    }

    final target = _redirectTarget(context, status);
    if (target != null && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirect(context, target);
      });
    }

    return widget.child;
  }

  /// Returns the route to redirect to, or `null` when the current state is
  /// fine.
  ///
  /// A redirect is pointless (and would loop forever) when the target is the
  /// route this guard is already on — e.g. the landing page is public *and*
  /// the default destination for signed-in visitors, so it must never replace
  /// itself.
  String? _redirectTarget(BuildContext context, AuthStatus status) {
    final target = switch (widget.policy) {
      AuthPolicy.publicOnly when status == AuthStatus.authenticated =>
        _publicTarget(context),
      AuthPolicy.protected when status == AuthStatus.unauthenticated =>
        AppRouter.login,
      _ => null,
    };
    if (target == null) return null;
    if (target == ModalRoute.of(context)?.settings.name) return null;
    return target;
  }

  String _publicTarget(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map && arguments['from'] is String) {
      final from = arguments['from'] as String;
      if (const {
        AppRouter.profile,
        AppRouter.dashboard,
        AppRouter.tasks,
      }.contains(from)) {
        return from;
      }
    }
    return AppRouter.home;
  }

  void _redirect(BuildContext context, String target) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    final navigator = Navigator.of(context);
    if (target == AppRouter.login) {
      navigator.pushNamedAndRemoveUntil(
        target,
        (r) => false,
        arguments: {'from': route.settings.name},
      );
    } else {
      navigator.pushReplacementNamed(target);
    }
  }
}
