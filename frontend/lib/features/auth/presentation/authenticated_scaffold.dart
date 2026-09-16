import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_sidebar.dart';
import 'app_scope.dart';

/// Shell for every signed-in screen: brand sidebar (Dashboard/Tasks/Profile),
/// optional page header, and the identity footer with profile + sign-out.
class AuthenticatedScaffold extends StatelessWidget {
  const AuthenticatedScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.actions,
    this.selectedIndex,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  /// Index of the active sidebar destination (0 = Dashboard, 1 = Tasks,
  /// 2 = Profile), or `null` for none.
  final int? selectedIndex;

  static const List<AppNavItem> _navItems = [
    AppNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
    AppNavItem(label: 'Tasks', icon: Icons.checklist_rounded),
    AppNavItem(label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  static const List<String> _navRoutes = [
    AppRouter.dashboard,
    AppRouter.tasks,
    AppRouter.profile,
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      brandTitle: AppConstants.appName,
      navItems: _navItems,
      selectedIndex: selectedIndex,
      onSelect: (item) {
        final index = _navItems.indexOf(item);
        if (index < 0) return;
        final target = _navRoutes[index];
        final current = ModalRoute.of(context)?.settings.name;
        if (target == current) return;
        Navigator.of(context).pushReplacementNamed(target);
      },
      footer: const _IdentityFooter(),
      title: title,
      subtitle: subtitle,
      actions: actions,
      body: body,
    );
  }
}

/// The sidebar footer: avatar + name for the signed-in user, and the
/// profile / sign-out actions.
class _IdentityFooter extends StatefulWidget {
  const _IdentityFooter();

  @override
  State<_IdentityFooter> createState() => _IdentityFooterState();
}

class _IdentityFooterState extends State<_IdentityFooter> {
  bool _signingOut = false;

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'Sign out',
      message: 'You will need to sign in again to use your workspace.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    await AppScope.authOf(context).logout();
    // The protected-route guard redirects to the login screen once the
    // session clears; no manual navigation needed here.
    if (mounted) {
      setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.authOf(context);
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    final initial = user == null ? '?' : _initialFor(user.username);
    final name = user?.username ?? 'Account';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatar / 2,
                backgroundColor: tokens.secondaryContainer,
                foregroundColor: tokens.onSecondaryContainer,
                child: Text(initial, style: textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Profile',
                  variant: AppButtonVariant.text,
                  icon: Icons.person_outline_rounded,
                  onPressed: () {
                    Navigator.of(context)
                        .pushReplacementNamed(AppRouter.profile);
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.text,
                  icon: Icons.logout_rounded,
                  loading: _signingOut,
                  onPressed: _signingOut ? null : _confirmSignOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
