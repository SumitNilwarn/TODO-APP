import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/presentation/app_scope.dart';
import '../../auth/domain/auth_models.dart';

/// Landing screen.
///
/// Always reachable. It adapts to the session: signed-in visitors get a link
/// straight into their workspace (dashboard), everyone else sees the sign-in
/// call to action.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;
    final auth = AppScope.authOf(context);
    final signedIn = auth.isAuthenticated;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AppMark(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome to ${AppConstants.appName}',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppConstants.tagline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signedIn
                              ? 'Your workspace'
                              : 'A calm place to plan your day',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          signedIn
                              ? 'You are signed in as '
                                    '${auth.username ?? "a member"}. Head to the '
                                    'dashboard to get started, or visit your '
                                    'profile to personalise your account.'
                              : 'Sign in to manage your tasks and personalise '
                                    'your account. Everything is stored securely '
                                    'behind your profile.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'API: ${AppConfig.apiBaseUrl}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (signedIn)
                          AppButton(
                            label: 'Open dashboard',
                            icon: Icons.dashboard_outlined,
                            expanded: true,
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushReplacementNamed(AppRouter.dashboard),
                          )
                        else
                          AppButton(
                            label: 'Get started',
                            icon: Icons.arrow_forward_rounded,
                            expanded: true,
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushReplacementNamed(AppRouter.login),
                          ),
                        if (auth.status == AuthStatus.refreshing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Restoring your session…',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '· Workspace · Tasks · Profile ·',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Center(
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          color: tokens.onPrimary,
          size: 36,
          semanticLabel: AppConstants.appName,
        ),
      ),
    );
  }
}
