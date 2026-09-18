import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_inline_alert.dart';
import '../../../shared/widgets/app_kicker.dart';
import '../../../shared/widgets/motion/fade_entrance.dart';

/// Shared layout for the public auth screens (sign in, create account).
///
/// On desktop widths (≥ [AppBreakpoints.desktop]) the screen becomes a
/// split-panel "command center": a dark editorial brand pane on the left and
/// the form pane on the right. Below that the familiar centered card layout is
/// used so both routes stay consistent everywhere. Branding, width constraints
/// and the page background stay shared across both routes.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = screenSizeOf(context) == AppScreenSize.desktop;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: wide ? _buildSplit(context) : _buildStacked(context),
      ),
    );
  }

  /// Desktop: brand pane + centered form pane side by side.
  Widget _buildSplit(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: _BrandPane()),
        Expanded(
          flex: 7,
          child: _FormPane(
            title: title,
            subtitle: subtitle,
            showBrandMark: false,
            children: children,
          ),
        ),
      ],
    );
  }

  /// Compact/tablet: the centered stacked layout with the brand mark on top.
  Widget _buildStacked(BuildContext context) {
    return Center(
      child: _FormPane(
        title: title,
        subtitle: subtitle,
        showBrandMark: true,
        children: children,
      ),
    );
  }
}

/// The centered scrolling column that carries title, subtitle and the form.
class _FormPane extends StatelessWidget {
  const _FormPane({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.showBrandMark,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBrandMark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrandMark) ...[
                const FadeEntrance(
                  offset: Offset(0, 8),
                  duration: Duration(milliseconds: 380),
                  child: _BrandMark(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              FadeEntrance(
                delay: const Duration(milliseconds: 80),
                offset: const Offset(0, 8),
                child: Text(
                  title,
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FadeEntrance(
                delay: const Duration(milliseconds: 140),
                offset: const Offset(0, 8),
                child: Text(
                  subtitle,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final child in children)
                FadeEntrance(
                  delay: const Duration(milliseconds: 220),
                  duration: const Duration(milliseconds: 400),
                  offset: const Offset(0, 12),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dark, technical editorial pane shown on the left of the split layout.
class _BrandPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    const low = 0.72;
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.primary),
      child: ClipRect(
        child: Stack(
          children: [
            // A quiet 3×3 grid of checks gives the ink panel a command-center
            // texture without stealing attention.
            Positioned(
              right: -16,
              top: -16,
              child: SizedBox(
                width: 220,
                height: 220,
                child: Wrap(
                  spacing: 28,
                  runSpacing: 28,
                  children: List.generate(9, (_) {
                    return Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: tokens.onPrimary.withValues(alpha: 0.06),
                    );
                  }),
                ),
              ),
            ),
            Positioned(
              right: 36,
              bottom: 36,
              child: Icon(
                Icons.check_rounded,
                size: 180,
                color: tokens.onPrimary.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppSizes.brandMark + 10,
                        height: AppSizes.brandMark + 10,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.onPrimary,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Icon(
                          Icons.checklist_rounded,
                          size: 24,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        AppConstants.appName,
                        style: textTheme.titleMedium?.copyWith(
                          color: tokens.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AppKicker(
                    label: 'Command center',
                    color: tokens.onPrimary.withValues(alpha: low),
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Plan.\nExecute.\nShip.',
                    style: textTheme.displayLarge?.copyWith(
                      color: tokens.onPrimary,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppConstants.tagline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tokens.onPrimary.withValues(alpha: low),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'MONOCHROME OS · ${DateTime.now().year}',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.onPrimary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Center(
      child: Container(
        width: AppSizes.brandMark + 20,
        height: AppSizes.brandMark + 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: AppRadius.lgAll,
        ),
        child: const Icon(Icons.check_rounded, size: 26),
      ),
    );
  }
}

/// Inline error banner for auth failures (renders `AuthState.lastError`).
///
/// Never renders server/token internals — only the friendly, translated
/// message produced by [AuthState]. Delegates to the shared [AppInlineAlert]
/// so every inline banner in the app stays visually identical.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppInlineAlert(message: message);
  }
}

/// Themed form field used on the auth screens; reads the same
/// `InputDecorationTheme` as the rest of the design system.
class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool obscureText;
  final IconData? prefixIcon;

  /// Trailing widget (e.g. the visibility toggle).
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}
