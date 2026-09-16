import 'package:flutter/material.dart';

import '../../shared/theme/design_tokens.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';

/// Minimal screen placeholder used by the Phase 9 routing foundation.
///
/// Each reserved route renders one of these until its feature phase lands.
/// Contains no feature logic — it only proves routing, theming and the base
/// layout work end to end.
class RoutePlaceholderScreen extends StatelessWidget {
  const RoutePlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.message,
  });

  final String title;
  final IconData icon;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppEmptyState(
              icon: icon,
              title: '$title is coming',
              message:
                  message ??
                  'This screen is reserved by the routing foundation and will '
                      'be implemented in its own phase.',
              action: AppButton(
                label: 'Back home',
                variant: AppButtonVariant.outlined,
                expanded: true,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
