import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/core/config/app_config.dart';
import 'package:todo_app/shared/widgets/app_button.dart';
import 'package:todo_app/shared/widgets/app_card.dart';

void main() {
  testWidgets('app renders the home landing page', (tester) async {
    await tester.pumpWidget(const TodoApp());

    expect(find.text('Welcome to Todo App'), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('home page surfaces the configured API base URL', (tester) async {
    await tester.pumpWidget(const TodoApp());

    expect(find.textContaining(AppConfig.apiBaseUrl), findsOneWidget);
  });

  testWidgets('lays out correctly across all supported widths', (tester) async {
    for (final width in const [390, 600, 768, 1024, 1280, 1440]) {
      tester.view.physicalSize = Size(width.toDouble(), 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TodoApp());

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to Todo App'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    }
  });
}
