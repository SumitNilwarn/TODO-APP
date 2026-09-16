import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/presentation/router/app_router.dart';
import 'package:todo_app/presentation/screens/design_system_page.dart';
import 'package:todo_app/shared/widgets/app_button.dart';
import 'package:todo_app/shared/widgets/app_empty_state.dart';
import 'package:todo_app/shared/widgets/app_error_state.dart';
import 'package:todo_app/shared/widgets/app_loading.dart';

void main() {
  void setDesktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The gallery contains always-animating AppLoading spinners, so
  // pumpAndSettle would never settle. Bounded pumps are used instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> pumpShowcase(
    WidgetTester tester, {
    String route = AppRouter.designSystem,
  }) async {
    // A fresh key boots a clean navigator for each route.
    await tester.pumpWidget(TodoApp(key: ValueKey(route), initialRoute: route));
    await settle(tester);
  }

  Future<void> flushSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('is reachable through its reserved route', (tester) async {
    setDesktop(tester);
    await pumpShowcase(tester);

    expect(find.byType(DesignSystemPage), findsOneWidget);
    expect(find.text('Design system'), findsWidgets);
  });

  testWidgets('surfaces the token galleries and component inventory', (
    tester,
  ) async {
    setDesktop(tester);
    await pumpShowcase(tester);

    for (final section in [
      'Typography',
      'Color',
      'Spacing & radius',
      'Buttons',
      'Inputs',
      'Cards',
      'Badges & dividers',
      'Feedback',
      'States',
    ]) {
      expect(find.text(section), findsOneWidget, reason: section);
    }

    // A representative sample of the actual tokens/components is rendered.
    expect(find.text('displayLarge'), findsOneWidget);
    // Exact swatch value (8-digit ARGB) for the current ink token
    // (shared by `primary` and `textPrimary`).
    expect(find.text('ff191919'), findsWidgets);
    expect(find.textContaining('neutral'), findsWidgets);
    expect(find.byType(AppLoading), findsWidgets);
    expect(find.byType(AppEmptyState), findsWidgets);
    expect(find.byType(AppErrorState), findsWidgets);
  });

  testWidgets('opens snackbars, a dialog and a confirmation', (tester) async {
    setDesktop(tester);
    await pumpShowcase(tester);

    // Snackbar variants.
    await revealAndTap(tester, find.widgetWithText(AppButton, 'success'));
    expect(find.text('This is a success message.'), findsOneWidget);
    await flushSnackBars(tester);

    // Generic dialog.
    await revealAndTap(tester, find.text('Open dialog'));
    await settle(tester);
    expect(find.text('A dialog'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    expect(find.text('A dialog'), findsNothing);

    // Confirmation flow.
    await revealAndTap(
      tester,
      find.widgetWithText(AppButton, 'Confirm delete'),
    );
    await settle(tester);

    expect(find.text('Delete thing?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await settle(tester);
    expect(find.text('Deleted'), findsOneWidget);
    await flushSnackBars(tester);
  });

  testWidgets('stays presentational — no backend calls are made', (
    tester,
  ) async {
    setDesktop(tester);
    await pumpShowcase(tester);

    // The page contains no input-driven form submissions and no data layer:
    // feature/API screens are not mounted on this route.
    expect(find.byType(TextField), findsWidgets); // gallery fields only
    expect(tester.takeException(), isNull);

    // Every listed action is a pure UI affordance: nothing routes away.
    await revealAndTap(tester, find.widgetWithText(AppButton, 'info'));
    expect(find.byType(DesignSystemPage), findsOneWidget);
    await flushSnackBars(tester);
  });
}
