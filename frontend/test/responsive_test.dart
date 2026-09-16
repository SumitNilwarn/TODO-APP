import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/utils/responsive.dart';
import 'package:todo_app/presentation/screens/design_system_page.dart';
import 'package:todo_app/shared/widgets/app_shell.dart';
import 'package:todo_app/shared/widgets/responsive_container.dart';

void main() {
  group('AppScreenSize classification', () {
    test('classifies widths against the bot breakpoint', () {
      expect(AppScreenSize.fromWidth(480), AppScreenSize.compact);
      expect(AppScreenSize.fromWidth(599), AppScreenSize.compact);
      expect(AppScreenSize.fromWidth(600), AppScreenSize.tablet);
      expect(AppScreenSize.fromWidth(1023), AppScreenSize.tablet);
      expect(AppScreenSize.fromWidth(1024), AppScreenSize.desktop);
      expect(AppScreenSize.fromWidth(1920), AppScreenSize.desktop);
    });
  });

  group('ResponseLayout', () {
    test('caps content width on desktop and passes tablet widths through', () {
      expect(ResponseLayout.fromWidth(1920).maxWidth, 1200);
      expect(ResponseLayout.fromWidth(1024).maxWidth, 1200);
      expect(ResponseLayout.fromWidth(800).maxWidth, 800);
      expect(ResponseLayout.fromWidth(375).maxWidth, 375);
    });

    test('exposes size-class helpers', () {
      expect(ResponseLayout.fromWidth(1400).isDesktop, isTrue);
      expect(ResponseLayout.fromWidth(800).isTablet, isTrue);
      expect(ResponseLayout.fromWidth(800).isCompact, isFalse);
      expect(ResponseLayout.fromWidth(375).isCompact, isTrue);
    });
  });

  testWidgets('desktop caps the content width at the leading breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const ResponsiveContainer(
          child: SizedBox(key: probeKey, width: double.infinity, height: 80),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(probeKey));
    expect(size.width, AppBreakpoints.maxContentWidth);
  });

  testWidgets('tablet widths are padded but not capped', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const ResponsiveContainer(
          child: SizedBox(key: probeKey, width: double.infinity, height: 80),
        ),
      ),
    );

    // 800 - 24 (page gutter) - 24 (page gutter) = 752 available.
    final size = tester.getSize(find.byKey(probeKey));
    expect(size.width, 752);
  });

  testWidgets('custom horizontal padding is honored', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const ResponsiveContainer(
          horizontalPadding: 60,
          child: SizedBox(key: probeKey, width: double.infinity, height: 80),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(probeKey));
    expect(size.width, 800 - 120);
  });

  testWidgets('design system and shell never overflow across breakpoints', (
    tester,
  ) async {
    const widths = [600, 768, 1024, 1280, 1440];

    for (final width in widths) {
      tester.view.physicalSize = Size(width.toDouble(), 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(MaterialApp(home: const DesignSystemPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.takeException(),
        isNull,
        reason: 'DesignSystemPage at ${width}px',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: const AppShell(title: 'Tasks', body: SizedBox(height: 600)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'AppShell at ${width}px');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const probeKey = Key('responsive-probe');

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
