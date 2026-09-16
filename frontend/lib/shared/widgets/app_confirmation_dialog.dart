import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Destructive-action confirmation dialog.
///
/// Returns `true` when the user confirms, `false` when they dismiss. Uses
/// [AppButtonVariant.destructive] for the confirming action and the shared
/// [AppDialog] surface.
Future<bool> showAppConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      icon: icon,
      content: Text(
        message,
        style: Theme.of(dialogContext).textTheme.bodyMedium,
      ),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppButton(
          label: confirmLabel,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
