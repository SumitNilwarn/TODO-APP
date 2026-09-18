import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../presentation/router/app_router.dart';
import '../../../shared/theme/command_design_tokens.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/chrome/architectural_grid.dart';
import '../../../shared/widgets/chrome/command_chrome.dart';
import '../../../shared/widgets/chrome/metric_ring.dart';
import '../../../shared/widgets/motion/fade_entrance.dart';
import '../../../shared/widgets/motion/perspective_tilt.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/app_scope.dart';

/// Landing screen.
///
/// Always reachable. It adapts to the session: signed-in visitors get a link
/// straight into their workspace (dashboard), everyone else sees the sign-in
/// call to action. Presented as a cinematic command-center hero over the
/// architectural grid, with a live system console on wide viewports.
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
        child: ArchitecturalGrid(
          glowAlignment: Alignment.topCenter,
          child: Stack(
            children: [
              const Positioned(
                top: -140,
                right: -100,
                child: IgnorePointer(child: GlowOrb(size: 420)),
              ),
              const Positioned(
                bottom: -160,
                left: -120,
                child: IgnorePointer(child: GlowOrb(size: 380)),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: ResponsiveContainer(
                  maxWidth: 960,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeEntrance(
                        offset: Offset(0, 10),
                        duration: Duration(milliseconds: 420),
                        child: _BrandCore(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide =
                              constraints.maxWidth >= AppBreakpoints.desktop;
                          if (wide) {
                            return _HeroRow(
                              signedIn: signedIn,
                              username: auth.username,
                              refreshing: auth.status == AuthStatus.refreshing,
                              textTheme: textTheme,
                              tokens: tokens,
                            );
                          }
                          return _HeroStacked(
                            signedIn: signedIn,
                            username: auth.username,
                            refreshing: auth.status == AuthStatus.refreshing,
                            textTheme: textTheme,
                            tokens: tokens,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FadeEntrance(
                        delay: const Duration(milliseconds: 320),
                        duration: const Duration(milliseconds: 380),
                        child: Text(
                          '· Workspace · Tasks · Profile ·',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide hero: editorial copy beside the live console.
class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.signedIn,
    required this.username,
    required this.refreshing,
    required this.textTheme,
    required this.tokens,
  });

  final bool signedIn;
  final String? username;
  final bool refreshing;
  final TextTheme textTheme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: _HeroCopy(
            signedIn: signedIn,
            username: username,
            refreshing: refreshing,
            headingStyle: textTheme.displayLarge?.copyWith(fontSize: 52),
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        const Expanded(flex: 5, child: _SystemConsole()),
      ],
    );
  }
}

/// Stacked hero for compact/tablet viewports.
class _HeroStacked extends StatelessWidget {
  const _HeroStacked({
    required this.signedIn,
    required this.username,
    required this.refreshing,
    required this.textTheme,
    required this.tokens,
  });

  final bool signedIn;
  final String? username;
  final bool refreshing;
  final TextTheme textTheme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCopy(
          signedIn: signedIn,
          username: username,
          refreshing: refreshing,
          headingStyle: textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SystemConsole(),
      ],
    );
  }
}

/// The editorial half of the hero: overline, headline, tagline and the one
/// [AppCard] that carries the workspace CTA and the configured API URL.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.signedIn,
    required this.username,
    required this.refreshing,
    required this.headingStyle,
  });

  final bool signedIn;
  final String? username;
  final bool refreshing;
  final TextStyle? headingStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeEntrance(
          delay: const Duration(milliseconds: 60),
          child: const TechLabel('Command center', icon: Icons.blur_on_rounded),
        ),
        const SizedBox(height: AppSpacing.sm),
        FadeEntrance(
          delay: const Duration(milliseconds: 90),
          child: Text(
            'Welcome to ${AppConstants.appName}',
            style: headingStyle,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FadeEntrance(
          delay: const Duration(milliseconds: 150),
          child: Text(
            AppConstants.tagline,
            style: textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FadeEntrance(
          delay: const Duration(milliseconds: 220),
          duration: const Duration(milliseconds: 440),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TechLabel(
                  signedIn ? 'Workspace online' : 'Awaiting credentials',
                  color: signedIn ? tokens.success : tokens.textMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signedIn ? 'Your workspace' : 'A calm place to plan your day',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signedIn
                      ? 'You are signed in as '
                            '${username ?? "a member"}. Head to the '
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
                if (refreshing) ...[
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
        ),
      ],
    );
  }
}

/// Decorative "system console" — a floating readout panel with a completion
/// gauge, used to convey the product's command-center character. Contains no
/// [AppCard]/[AppButton] so the landing page keeps its pinned widget count.
class _SystemConsole extends StatelessWidget {
  const _SystemConsole();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.appColors;

    return FadeEntrance(
      delay: const Duration(milliseconds: 260),
      duration: const Duration(milliseconds: 460),
      child: FloatingPanel(
        showGlow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const TechLabel('System status', icon: Icons.sensors_rounded),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tokens.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.success.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const MetricRing(
                  value: 0.68,
                  label: 'Ready',
                  size: 108,
                  strokeWidth: 8,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Readout(
                        icon: Icons.checklist_rounded,
                        label: 'Tasks',
                        value: 'PLAN',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Readout(
                        icon: Icons.insights_rounded,
                        label: 'Dashboard',
                        value: 'LIVE',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Readout(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        value: 'SYNC',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            CommandRule(height: AppSpacing.md),
            const SizedBox(height: AppSpacing.md),
            Text(
              'A single workspace for tasks, progress and identity — engineered '
              'to stay calm under load.',
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Row(
      children: [
        Icon(icon, size: 16, color: tokens.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TechReadout(value, color: tokens.textSecondary),
      ],
    );
  }
}

/// The brand core: a machined mark with a cool halo, gently tilted on hover.
class _BrandCore extends StatelessWidget {
  const _BrandCore();

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final command = context.commandTokens;
    return Center(
      child: PerspectiveTilt(
        angle: 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    command.glowStrong,
                    command.glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: command.glowStrong,
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                  const BoxShadow(
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
          ],
        ),
      ),
    );
  }
}
