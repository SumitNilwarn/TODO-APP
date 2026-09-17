import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_guard.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/tasks/presentation/task_detail_page.dart';
import '../../features/tasks/presentation/tasks_page.dart';
import '../screens/design_system_page.dart';
import 'app_page_route.dart';

/// Central route table for the app.
///
/// Route *names* live here (and nowhere else). Every feature screen is wrapped
/// in an [AuthGuard] that resolves the appropriate access policy:
///
/// - public-only: [home] (landing), [login], [register], [designSystem]
/// - protected: [profile], [dashboard], [tasks], any task detail (`/tasks/{id}`)
///
/// The public auth screens keep their own session-aware behavior; the
/// design-system inventory stays public as a development reference. Unknown
/// routes fall back to [home] instead of crashing.
abstract final class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String dashboard = '/dashboard';
  static const String tasks = '/tasks';

  /// Prefix for task detail routes: `/tasks/<taskId>`. The id is a backend
  /// UUID, so this must come before the fallback in [onGenerateRoute].
  static const String taskDetailPrefix = '/tasks/';

  /// Interactive inventory of the design system (development reference).
  static const String designSystem = '/design-system';

  /// Route names that require an authenticated session.
  static const Set<String> protectedRoutes = {profile, dashboard, tasks};

  /// Builds the full route name for a task detail screen.
  static String taskDetailFor(String taskId) => '$taskDetailPrefix$taskId';

  static String taskIdFromRoute(String name) =>
      name.substring(taskDetailPrefix.length);

  static bool isTaskDetailRoute(String name) =>
      name.startsWith(taskDetailPrefix);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name != null && isTaskDetailRoute(name)) {
      return _page<bool>(
        AuthGuard(
          policy: AuthPolicy.protected,
          child: TaskDetailPage(taskId: taskIdFromRoute(name)),
        ),
        settings,
      );
    }
    return switch (name) {
      home => _page(
        const AuthGuard(policy: AuthPolicy.publicOnly, child: HomePage()),
        settings,
      ),
      login => _page(
        const AuthGuard(policy: AuthPolicy.publicOnly, child: LoginPage()),
        settings,
      ),
      register => _page(
        const AuthGuard(policy: AuthPolicy.publicOnly, child: RegisterPage()),
        settings,
      ),
      profile => _page(
        const AuthGuard(policy: AuthPolicy.protected, child: ProfilePage()),
        settings,
      ),
      dashboard => _page(
        const AuthGuard(policy: AuthPolicy.protected, child: DashboardPage()),
        settings,
      ),
      tasks => _page(
        const AuthGuard(policy: AuthPolicy.protected, child: TasksPage()),
        settings,
      ),
      designSystem => _page(const DesignSystemPage(), settings),
      _ => _page(
        const AuthGuard(policy: AuthPolicy.publicOnly, child: HomePage()),
        settings,
      ),
    };
  }

  static AppPageRoute<T> _page<T>(Widget child, RouteSettings settings) {
    return AppPageRoute<T>(builder: (_) => child, settings: settings);
  }
}
