import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/theme/app_colors.dart';
import 'package:todo_app/shared/widgets/app_badge.dart';
import 'package:todo_app/shared/widgets/app_button.dart';
import 'package:todo_app/shared/widgets/app_card.dart';
import 'package:todo_app/shared/widgets/app_chip.dart';
import 'package:todo_app/shared/widgets/app_confirmation_dialog.dart';
import 'package:todo_app/shared/widgets/app_dialog.dart';
import 'package:todo_app/shared/widgets/app_divider.dart';
import 'package:todo_app/shared/widgets/app_empty_state.dart';
import 'package:todo_app/shared/widgets/app_error_state.dart';
import 'package:todo_app/shared/widgets/app_inline_alert.dart';
import 'package:todo_app/shared/widgets/app_loading.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/app_text_field.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppButton', () {
    testWidgets('renders the label and fires onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Go', onPressed: () => pressed++)),
      );

      expect(find.text('Go'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(pressed, 1);
    });

    testWidgets('is disabled while loading and shows a spinner', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(
          AppButton(label: 'Saving', loading: true, onPressed: () => pressed++),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(pressed, 0);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(host(const AppButton(label: 'Disabled')));

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('supports outlined and text variants', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: const [
              AppButton(
                label: 'Secondary',
                variant: AppButtonVariant.outlined,
                onPressed: _noop,
              ),
              AppButton(
                label: 'Quiet',
                variant: AppButtonVariant.text,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Quiet'), findsOneWidget);
    });

    testWidgets('adds secondary and destructive variants', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: const [
              AppButton(
                label: 'Soft',
                variant: AppButtonVariant.secondary,
                onPressed: _noop,
              ),
              AppButton(
                label: 'Delete',
                variant: AppButtonVariant.destructive,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Soft'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('expanded buttons stretch across the full width', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Wide', expanded: true, onPressed: _noop)),
      );

      final fullWidth = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == double.infinity,
      );
      expect(fullWidth, findsOneWidget);
    });

    testWidgets('exposes a tooltip hint', (tester) async {
      await tester.pumpWidget(
        host(
          const AppButton(
            label: 'Save',
            tooltip: 'Save your work',
            onPressed: _noop,
          ),
        ),
      );

      expect(find.byTooltip('Save your work'), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('renders label, hint and error text', (tester) async {
      await tester.pumpWidget(
        host(
          const AppTextField(
            label: 'Email',
            hintText: 'you@example.com',
            errorText: 'Required',
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('surfaces typed input through onChanged', (tester) async {
      String? value;
      await tester.pumpWidget(
        host(AppTextField(label: 'Name', onChanged: (v) => value = v)),
      );

      await tester.enterText(find.byType(TextField), 'Sumit');
      expect(value, 'Sumit');
    });

    testWidgets('renders an arbitrary suffix widget and hides the counter', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'Search',
            maxLength: 5,
            suffix: IconButton(
              key: const Key('custom-suffix'),
              tooltip: 'Clear',
              onPressed: () {},
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom-suffix')), findsOneWidget);
      expect(find.byTooltip('Clear'), findsOneWidget);
      // Search/forms hide the character counter app-wide (Phase 16).
      expect(find.text('0/5'), findsNothing);
    });

    testWidgets('prefers suffix over a static suffix icon', (tester) async {
      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'Field',
            suffixIcon: Icons.arrow_forward,
            suffix: const Icon(Icons.check_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });

  group('AppChoiceChip', () {
    testWidgets('renders a selectable status chip and fires onSelected', (
      tester,
    ) async {
      var selected = false;
      await tester.pumpWidget(
        host(
          AppChoiceChip(
            label: 'Completed',
            selected: selected,
            onSelected: () => selected = true,
          ),
        ),
      );

      expect(find.byType(ChoiceChip), findsOneWidget);
      var chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isFalse);

      await tester.tap(find.text('Completed'));
      expect(selected, isTrue);
    });
  });

  group('AppFilterChip', () {
    testWidgets('renders a toggle filter chip', (tester) async {
      await tester.pumpWidget(
        host(
          AppFilterChip(
            label: 'Overdue only',
            selected: true,
            onSelected: (_) {},
            activeColor: AppColors.danger,
          ),
        ),
      );

      expect(find.byType(FilterChip), findsOneWidget);
      final chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chip.selected, isTrue);
    });
  });

  group('AppInlineAlert', () {
    testWidgets('renders a danger message with a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AppInlineAlert(message: 'Title must not be blank.')),
      );

      expect(find.text('Title must not be blank.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Title must not be blank.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('supports the info variant', (tester) async {
      await tester.pumpWidget(
        host(
          const AppInlineAlert(
            message: 'Heads up',
            variant: AppInlineAlertVariant.info,
          ),
        ),
      );

      expect(find.text('Heads up'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('renders its child inside a padded surface', (tester) async {
      await tester.pumpWidget(host(const AppCard(child: Text('Inside'))));

      expect(find.text('Inside'), findsOneWidget);
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.padding, isNot(EdgeInsets.zero));
    });
  });

  group('AppLoading', () {
    testWidgets('shows a spinner and an optional label', (tester) async {
      await tester.pumpWidget(host(const AppLoading(label: 'Synchronizing')));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Synchronizing'), findsOneWidget);
    });
  });

  group('AppErrorState', () {
    testWidgets('shows title/message and triggers retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        host(
          AppErrorState(
            title: 'Oops',
            message: 'Could not load tasks.',
            onRetry: () => retried++,
          ),
        ),
      );

      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Could not load tasks.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders title, message and an optional action', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppEmptyState(
            title: 'No tasks',
            message: 'Create one to get started.',
            action: AppButton(
              label: 'Add task',
              variant: AppButtonVariant.outlined,
              onPressed: _noop,
            ),
          ),
        ),
      );

      expect(find.text('No tasks'), findsOneWidget);
      expect(find.text('Create one to get started.'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('supports standard and elevated variants and defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            children: const [
              AppCard(child: Text('Flat')),
              AppCard(variant: AppCardVariant.elevated, child: Text('Raised')),
            ],
          ),
        ),
      );

      final cards = tester.widgetList<AppCard>(find.byType(AppCard)).toList();
      expect(cards.first.variant, AppCardVariant.standard);
      expect(cards.last.variant, AppCardVariant.elevated);
    });

    testWidgets('interactive cards fire onTap and expose button semantics', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        host(
          AppCard(
            interactive: true,
            onTap: () => tapped++,
            child: const Text('Open'),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(AppCard));
      expect(tapped, 1);
    });
  });

  group('AppLoading', () {
    testWidgets('honors a custom color and size', (tester) async {
      await tester.pumpWidget(
        host(
          const AppLoading(label: 'Working', color: AppColors.danger, size: 24),
        ),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, AppColors.danger);
      expect(spinner.strokeWidth, closeTo(2.6, 0.01));
    });
  });

  group('AppTextField', () {
    testWidgets('supports an overridden screen-reader label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        host(
          const AppTextField(label: 'Email', semanticsLabel: 'E-mail address'),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('E-mail address')), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppBadge', () {
    testWidgets('renders every semantic variant', (tester) async {
      await tester.pumpWidget(
        host(
          Wrap(
            children: [
              for (final variant in AppBadgeVariant.values)
                AppBadge(variant.name, variant: variant),
              const AppBadge(
                'Active',
                variant: AppBadgeVariant.success,
                showDot: true,
              ),
              const AppBadge(
                'Info',
                variant: AppBadgeVariant.info,
                icon: Icons.info_outline,
              ),
            ],
          ),
        ),
      );

      expect(find.text('neutral'), findsOneWidget);
      expect(find.text('success'), findsOneWidget);
      expect(find.text('warning'), findsOneWidget);
      expect(find.text('danger'), findsOneWidget);
      expect(find.text('info'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
    });
  });

  group('AppDivider', () {
    testWidgets('renders a plain rule by default', (tester) async {
      await tester.pumpWidget(host(const AppDivider()));

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders a labeled rule', (tester) async {
      await tester.pumpWidget(host(const AppDivider(label: 'or')));

      expect(find.text('or'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('AppSnackbar', () {
    testWidgets('shows a floating message with the requested variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSnackbar.show(
                  context,
                  'Saved',
                  variant: AppFeedbackVariant.success,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
    });
  });

  group('AppDialog', () {
    testWidgets('opens a dialog with title, content and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppDialog.show(
                  context,
                  title: 'Are you sure?',
                  content: const Text('This changes the setting.'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('This changes the setting.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('showAppConfirmationDialog', () {
    testWidgets('confirms and cancels', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAppConfirmationDialog(
                    context,
                    title: 'Delete thing?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete thing?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

void _noop() {}
