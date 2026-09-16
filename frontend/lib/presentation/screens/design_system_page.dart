import 'package:flutter/material.dart';

import '../../shared/theme/design_tokens.dart';
import '../../shared/theme/theme_extensions.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_confirmation_dialog.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_divider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/app_text_field.dart';

/// Interactive inventory of the design system — every token and reusable
/// component rendered in one place for validation and reference.
///
/// Purely presentational: no authentication, no data, no API calls. It is the
/// canonical gallery that designers and new contributors can inspect.
class DesignSystemPage extends StatelessWidget {
  const DesignSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Design system',
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.giant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _Section(
              'Typography',
              description:
                  'All text roles come from the shared TextTheme. Screens pick a '
                  'role instead of inventing sizes.',
              child: _TypographyGallery(),
            ),
            _Section(
              'Color',
              description:
                  'Surfaces, primary/secondary action colors, text roles, borders '
                  'and feedback semantics.',
              child: _ColorGallery(),
            ),
            _Section(
              'Spacing & radius',
              description:
                  'Every gap and corner derives from the token scale — never '
                  'arbitrary numbers.',
              child: _GeometryGallery(),
            ),
            _Section(
              'Buttons',
              description:
                  'Primary, secondary, outlined, destructive and text. '
                  'States: idle, disabled and loading.',
              child: _ButtonGallery(),
            ),
            _Section(
              'Inputs',
              description:
                  'Filled, rounded fields with focus and error styling from the '
                  'theme.',
              child: _InputGallery(),
            ),
            _Section(
              'Cards',
              description:
                  'Standard and elevated surfaces; interactive cards expose '
                  'hover, focus and ripple.',
              child: _CardGallery(),
            ),
            _Section(
              'Badges & dividers',
              description: 'Status pills and the labeled divider.',
              child: _BadgeGallery(),
            ),
            _Section(
              'Feedback',
              description:
                  'Snackbars, dialogs and confirmations — the only sanctioned '
                  'paths for transient messages.',
              child: _FeedbackGallery(),
            ),
            _Section(
              'States',
              description: 'Loading, empty and error placeholders.',
              child: _StateGallery(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.description, required this.child});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: textTheme.bodyMedium?.copyWith(
                color: textTheme.bodySmall?.color,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _TypographyGallery extends StatelessWidget {
  const _TypographyGallery();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roles = <(String, TextStyle?)>[
      ('displayLarge', textTheme.displayLarge),
      ('headlineLarge', textTheme.headlineLarge),
      ('headlineMedium', textTheme.headlineMedium),
      ('headlineSmall', textTheme.headlineSmall),
      ('titleLarge', textTheme.titleLarge),
      ('titleMedium', textTheme.titleMedium),
      ('titleSmall', textTheme.titleSmall),
      ('bodyLarge', textTheme.bodyLarge),
      ('bodyMedium', textTheme.bodyMedium),
      ('bodySmall', textTheme.bodySmall),
      ('labelLarge', textTheme.labelLarge),
      ('labelMedium', textTheme.labelMedium),
      ('labelSmall', textTheme.labelSmall),
    ];

    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in roles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      name,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Almost before we knew it', style: style),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteEntry {
  const _PaletteEntry(this.name, this.color, this.onColor);

  final String name;
  final Color color;
  final Color onColor;
}

class _ColorGallery extends StatelessWidget {
  const _ColorGallery();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final entries = <_PaletteEntry>[
      _PaletteEntry('background', c.background, c.textPrimary),
      _PaletteEntry('surface', c.surface, c.textPrimary),
      _PaletteEntry('surfaceElevated', c.surfaceElevated, c.textPrimary),
      _PaletteEntry('surfaceAlt', c.surfaceAlt, c.textPrimary),
      _PaletteEntry('primary', c.primary, c.onPrimary),
      _PaletteEntry('primaryContainer', c.primaryContainer, c.textPrimary),
      _PaletteEntry('secondary', c.secondary, c.onPrimary),
      _PaletteEntry(
        'secondaryContainer',
        c.secondaryContainer,
        c.onSecondaryContainer,
      ),
      _PaletteEntry('textPrimary', c.textPrimary, c.onPrimary),
      _PaletteEntry('textSecondary', c.textSecondary, c.onPrimary),
      _PaletteEntry('textMuted', c.textMuted, c.onPrimary),
      _PaletteEntry('border', c.border, c.textPrimary),
      _PaletteEntry('success', c.success, c.onPrimary),
      _PaletteEntry('warning', c.warning, c.onPrimary),
      _PaletteEntry('danger', c.danger, c.onPrimary),
      _PaletteEntry('info', c.info, c.onPrimary),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in entries)
          Container(
            width: 140,
            decoration: BoxDecoration(
              color: entry.color,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entry.color.toARGB32().toRadixString(16).padLeft(8, '0'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GeometryGallery extends StatelessWidget {
  const _GeometryGallery();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scales = <(String, double)>[
      ('4  · xs', AppSpacing.xs),
      ('8  · sm', AppSpacing.sm),
      ('12 · tight', AppSpacing.tight),
      ('16 · md', AppSpacing.md),
      ('20 · roomy', AppSpacing.roomy),
      ('24 · lg', AppSpacing.lg),
      ('32 · xl', AppSpacing.xl),
      ('40 · huge', AppSpacing.huge),
      ('48 · xxl', AppSpacing.xxl),
      ('64 · giant', AppSpacing.giant),
    ];
    final radiusScale = <(String, double)>[
      ('small · 8', AppRadius.small),
      ('medium · 14', AppRadius.medium),
      ('large · 16', AppRadius.large),
      ('extraLarge · 20', AppRadius.extraLarge),
      ('pill · 999', AppRadius.pill),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spacing scale', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final (name, value) in scales)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(name, style: textTheme.bodySmall),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 18,
                      width: value == 0 ? 1 : value,
                      decoration: BoxDecoration(
                        color: context.appColors.primary,
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('Radius scale', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (name, value) in radiusScale)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(value),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Text(name, style: textTheme.bodySmall),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Elevation levels', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final (name, shadow) in const <(String, List<BoxShadow>)>[
              ('none', AppShadows.none),
              ('subtle', AppShadows.subtle),
              ('raised', AppShadows.raised),
              ('floating', AppShadows.floating),
            ])
              Container(
                width: 160,
                height: 88,
                padding: const EdgeInsets.all(AppSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: AppRadius.mdAll,
                  boxShadow: shadow,
                ),
                child: Text(name, style: textTheme.bodySmall),
              ),
          ],
        ),
      ],
    );
  }
}

class _ButtonGallery extends StatelessWidget {
  const _ButtonGallery();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final variant in AppButtonVariant.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  variant.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AppButton(label: 'Action', variant: variant, onPressed: () {}),
                AppButton(
                  label: 'Icon',
                  variant: variant,
                  icon: Icons.add,
                  onPressed: () {},
                ),
                AppButton(label: 'Disabled', variant: variant),
                AppButton(
                  label: 'Loading',
                  variant: variant,
                  loading: true,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Wide',
                  variant: variant,
                  expanded: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InputGallery extends StatelessWidget {
  const _InputGallery();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        children: [
          const AppTextField(
            label: 'With label',
            hintText: 'Type something...',
            prefixIcon: Icons.search,
            suffixIcon: Icons.arrow_forward,
          ),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(
            label: 'With error',
            errorText: 'Something needs attention',
            helperText: 'Helper explains the error',
          ),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(
            label: 'Disabled',
            enabled: false,
            hintText: 'Not editable',
          ),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(
            label: 'Multiline',
            maxLines: 3,
            hintText: 'Multiline content',
          ),
        ],
      ),
    );
  }
}

class _CardGallery extends StatelessWidget {
  const _CardGallery();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        SizedBox(
          width: 260,
          child: AppCard(
            variant: AppCardVariant.standard,
            child: Text(
              'Standard — flat, hairline border. Ideal for grouped intro information.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppCard(
            variant: AppCardVariant.elevated,
            child: Text(
              'Elevated — soft shadow. Ideal for primary content panels.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppCard(
            variant: AppCardVariant.standard,
            interactive: true,
            onTap: () {},
            child: Row(
              children: [
                const Icon(Icons.arrow_forward),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Interactive — hover, focus, ripple and a pointer cursor.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeGallery extends StatelessWidget {
  const _BadgeGallery();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final variant in AppBadgeVariant.values)
              AppBadge(variant.name, variant: variant),
            AppBadge(
              'With dot',
              variant: AppBadgeVariant.success,
              showDot: true,
            ),
            AppBadge(
              'With icon',
              variant: AppBadgeVariant.info,
              icon: Icons.info_outline,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppDivider(label: 'or keep scrolling'),
      ],
    );
  }
}

class _FeedbackGallery extends StatelessWidget {
  const _FeedbackGallery();

  @override
  Widget build(BuildContext context) {
    void toast(AppFeedbackVariant variant) {
      AppSnackbar.show(
        context,
        'This is a ${variant.name} message.',
        variant: variant,
        actionLabel: 'Undo',
      );
    }

    return AppCard(
      variant: AppCardVariant.elevated,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final variant in AppFeedbackVariant.values)
            AppButton(
              label: variant.name,
              variant: AppButtonVariant.outlined,
              onPressed: () => toast(variant),
            ),
          AppButton(
            label: 'Open dialog',
            variant: AppButtonVariant.outlined,
            onPressed: () => AppDialog.show(
              context,
              title: 'A dialog',
              content: const Text(
                'Dialogs carry short confirmations and inline actions.',
              ),
              icon: Icons.tune,
              actions: [
                const AppButton(label: 'Close', variant: AppButtonVariant.text),
              ],
            ),
          ),
          AppButton(
            label: 'Confirm delete',
            variant: AppButtonVariant.destructive,
            onPressed: () async {
              final ok = await showAppConfirmationDialog(
                context,
                title: 'Delete thing?',
                message: 'This cannot be undone. Are you sure?',
                confirmLabel: 'Delete',
              );
              if (ok && context.mounted) {
                AppSnackbar.show(
                  context,
                  'Deleted',
                  variant: AppFeedbackVariant.danger,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StateGallery extends StatelessWidget {
  const _StateGallery();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        const SizedBox(width: 300, child: AppLoading(label: 'Loading...')),
        SizedBox(
          width: 300,
          child: AppEmptyState(
            title: 'Nothing yet',
            message: 'There is no content to show right now.',
          ),
        ),
        SizedBox(
          width: 300,
          child: AppErrorState(
            title: 'Something went wrong',
            message: 'A friendly, actionable explanation.',
            onRetry: () {},
          ),
        ),
      ],
    );
  }
}
