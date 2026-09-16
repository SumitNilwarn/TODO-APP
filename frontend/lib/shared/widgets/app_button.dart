import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_extensions.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant {
  /// The dark, filled primary CTA.
  primary,

  /// A soft secondary fill — the calm alternative to the primary CTA.
  secondary,

  /// A bordered, soft surface button for secondary actions.
  outlined,

  /// A bordered danger button for destructive confirmations.
  destructive,

  /// A quiet, borderless text button.
  text,
}

/// Application's action button.
///
/// Rendered through the theme's `FilledButton`/`OutlinedButton`/`TextButton`
/// styles so sizing, shapes and disabled/focus states stay centralized. Shows
/// a loading spinner when [loading] and disables itself accordingly.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.tooltip,
  });

  /// Accessible label (and visible text) of the button.
  final String label;

  /// Invoked when the button is activated. `null` disables it.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  /// When `true`, replaces content with a spinner and disables the button.
  final bool loading;

  /// When `true`, stretches the button across the available width.
  final bool expanded;

  /// Optional `Tooltip`/`Semantics` hint shown on hover and focus.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    final baseButton = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isDisabled ? null : onPressed,
        child: _buildContent(context),
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: isDisabled ? null : onPressed,
        style: _secondaryStyle(context),
        child: _buildContent(context),
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        child: _buildContent(context),
      ),
      AppButtonVariant.destructive => OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: _destructiveStyle(context),
        child: _buildContent(context),
      ),
      AppButtonVariant.text => TextButton(
        onPressed: isDisabled ? null : onPressed,
        child: _buildContent(context),
      ),
    };
    final button = tooltip == null
        ? baseButton
        : Tooltip(message: tooltip!, child: baseButton);

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: loading ? '$label, ${AppConstants.appName} — loading' : label,
      child: expanded
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }

  ButtonStyle _secondaryStyle(BuildContext context) {
    final tokens = context.appColors;
    return FilledButton.styleFrom(
      backgroundColor: tokens.secondaryContainer,
      foregroundColor: tokens.onSecondaryContainer,
      disabledBackgroundColor: tokens.secondaryContainer.withValues(alpha: 0.5),
      disabledForegroundColor: tokens.onSecondaryContainer.withValues(
        alpha: 0.45,
      ),
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: tokens.onSecondaryContainer),
    );
  }

  ButtonStyle _destructiveStyle(BuildContext context) {
    final tokens = context.appColors;
    return OutlinedButton.styleFrom(
      foregroundColor: tokens.danger,
      disabledForegroundColor: tokens.danger.withValues(alpha: 0.38),
      backgroundColor: tokens.surface,
      minimumSize: const Size(AppSizes.buttonMinWidth, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      side: BorderSide(color: tokens.danger.withValues(alpha: 0.55)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: tokens.danger),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return tokens.danger.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return tokens.danger.withValues(alpha: 0.06);
        }
        return null;
      }),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading) {
      final color = switch (variant) {
        AppButtonVariant.primary => AppColors.onInk,
        AppButtonVariant.secondary => context.appColors.onSecondaryContainer,
        AppButtonVariant.destructive => context.appColors.danger,
        _ => AppColors.ink,
      };
      return SizedBox(
        width: AppSizes.buttonSpinner,
        height: AppSizes.buttonSpinner,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: color,
          // Keep the announced label stable while loading.
          semanticsLabel: label,
        ),
      );
    }

    if (icon == null) {
      return Text(label);
    }
    // Scale the icon + label down rather than overflow when the button is
    // squeezed into a narrow slot (e.g. the sidebar identity footer).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
