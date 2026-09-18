import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/theme/command_design_tokens.dart';
import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_inline_alert.dart';
import '../../../shared/widgets/chrome/architectural_grid.dart';
import '../../../shared/widgets/chrome/command_chrome.dart';
import '../../../shared/widgets/motion/fade_entrance.dart';

/// Shared layout for the public auth screens (sign in, create account).
///
/// On desktop widths (≥ [AppBreakpoints.desktop]) the screen becomes a
/// split-panel command center: a cinematic brand console on the left and the
/// form pane on the right. Below that the familiar centered card layout is
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

  /// Desktop: brand console + centered form pane side by side.
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TechLabel(
                      'Secure access',
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodyLarge?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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

/// The cinematic, technical brand console shown on the left of the split
/// layout — an architectural grid with glow and an editorial product pitch.
class _BrandPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final command = context.commandTokens;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.surface, tokens.background],
        ),
        border: Border(
          right: BorderSide(color: tokens.border),
          bottom: BorderSide(color: tokens.border),
        ),
      ),
      child: ClipRect(
        child: ArchitecturalGrid(
          gridOpacity: 0.7,
          child: Stack(
            children: [
              Positioned(
                right: -120,
                top: -140,
                child: IgnorePointer(child: GlowOrb(size: 460)),
              ),
              Positioned(
                left: -100,
                bottom: -120,
                child: IgnorePointer(child: GlowOrb(size: 400)),
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
                            color: tokens.primary,
                            borderRadius: AppRadius.mdAll,
                            boxShadow: [
                              BoxShadow(
                                color: command.glowStrong,
                                blurRadius: 20,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.checklist_rounded,
                            size: 24,
                            color: tokens.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          AppConstants.appName,
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const TechLabel(
                      'Command center',
                      icon: Icons.bolt_rounded,
                      color: Color(0xFF6FA8FF),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Plan.\nExecute.\nShip.',
                      style: textTheme.displayLarge?.copyWith(
                        height: 1.04,
                        fontSize: 48,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConstants.tagline,
                      style: textTheme.bodyLarge?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const Spacer(),
                    TechReadout(
                      '${DateTime.now().year}',
                      icon: Icons.military_tech_rounded,
                      color: tokens.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final command = context.commandTokens;
    return Center(
      child: Container(
        width: AppSizes.brandMark + 20,
        height: AppSizes.brandMark + 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: AppRadius.lgAll,
          boxShadow: [
            BoxShadow(
              color: command.glowStrong,
              blurRadius: 24,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Icon(Icons.check_rounded, size: 26, color: tokens.onPrimary),
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
