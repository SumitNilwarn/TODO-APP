import 'package:flutter/material.dart';

import '../../../shared/theme/design_tokens.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/app_inline_alert.dart';

/// Shared centered-card layout for the public auth screens (sign in, create
/// account). Keeps branding, width constraints and the page background
/// consistent across both routes.
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
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
    return Center(
      child: Container(
        width: AppSizes.brandMark + 20,
        height: AppSizes.brandMark + 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: AppRadius.lgAll,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
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
