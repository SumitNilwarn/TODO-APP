import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/app_page_header.dart';
import 'package:todo_app/shared/widgets/app_sidebar.dart';
import 'package:todo_app/shared/widgets/app_shell.dart';

const _navItems = <AppNavItem>[
  AppNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
  AppNavItem(label: 'Tasks', icon: Icons.checklist),
  AppNavItem(label: 'Settings', icon: Icons.settings_outlined),
];

Widget _shell({
  ValueChanged<AppNavItem>? onSelect,
  int? selectedIndex,
  String? title = 'Page title',
}) {
  return MaterialApp(
    home: AppShell(
      title: title,
      subtitle: 'A supporting description.',
      actions: const [Icon(Icons.add)],
      navItems: _navItems,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
      footer: const Text('user slot'),
      body: const SizedBox(height: 600),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('desktop shell', () {
    testWidgets('pins the sidebar and renders content + header', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_shell(selectedIndex: 1));

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('user slot'), findsOneWidget);
      expect(find.text('Page title'), findsOneWidget);
      expect(find.text('A supporting description.'), findsOneWidget);

      // No material drawer on wide layouts.
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('forwards navigation to the caller and highlights selection', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 800));
      AppNavItem? selected;
      await tester.pumpWidget(
        _shell(selectedIndex: 0, onSelect: (i) => selected = i),
      );

      await tester.tap(find.text('Tasks'));
      expect(selected?.label, 'Tasks');
    });
  });

  group('compact shell', () {
    testWidgets('collapses navigation into a drawer via the menu button', (
      tester,
    ) async {
      _setSize(tester, const Size(375, 700));
      await tester.pumpWidget(_shell());

      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('selecting a drawer item fires the callback and closes it', (
      tester,
    ) async {
      _setSize(tester, const Size(375, 700));
      AppNavItem? selected;
      await tester.pumpWidget(_shell(onSelect: (i) => selected = i));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(selected?.label, 'Settings');
      expect(find.byType(AppSidebar), findsNothing);
    });
  });

  group('AppPageHeader', () {
    testWidgets('renders title, subtitle and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPageHeader(
              title: 'Inbox',
              subtitle: 'Three items need attention.',
              actions: const [Icon(Icons.more_horiz)],
            ),
          ),
        ),
      );

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Three items need attention.'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });
  });
}
