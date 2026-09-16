import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/features/auth/presentation/auth_state.dart';

/// Pumps the real [TodoApp] (AppScope + router + guards) with a caller-owned
/// [AuthState] and lets the first frame settle.
Future<void> pumpApp(
  WidgetTester tester, {
  required AuthState auth,
  String initialRoute = '/',
}) async {
  await tester.pumpWidget(TodoApp(initialRoute: initialRoute, authState: auth));
  await tester.pumpAndSettle();
}
