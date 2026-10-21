import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';

void main() {
  group('Adversarial Resolution Boundary Checks', () {
    test('Boundary 1: 599px vs 600px (Mobile <-> Tablet)', () {
      // 599.0px (Mobile)
      expect(Responsive.isMobileWidth(599.0), isTrue);
      expect(Responsive.isTabletWidth(599.0), isFalse);
      expect(Responsive.isDesktopWidth(599.0), isFalse);
      expect(Responsive.isUltrawideWidth(599.0), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(599.0), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(599.0), ResponsiveBreakpoint.mobile);
      expect(Responsive.valueFromWidth(599.0, mobile: 16.0, tablet: 24.0, desktop: 32.0), 16.0);

      // 599.9px (Fractional Mobile Edge)
      expect(Responsive.isMobileWidth(599.9), isTrue);
      expect(Responsive.isTabletWidth(599.9), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(599.9), ResponsiveBreakpoint.mobile);

      // 600.0px (Tablet Exact)
      expect(Responsive.isMobileWidth(600.0), isFalse);
      expect(Responsive.isTabletWidth(600.0), isTrue);
      expect(Responsive.isDesktopWidth(600.0), isFalse);
      expect(Responsive.isUltrawideWidth(600.0), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(600.0), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(600.0), ResponsiveBreakpoint.tablet);
      expect(Responsive.valueFromWidth(600.0, mobile: 16.0, tablet: 24.0, desktop: 32.0), 24.0);

      // 600.1px (Tablet Lower Interior)
      expect(Responsive.isMobileWidth(600.1), isFalse);
      expect(Responsive.isTabletWidth(600.1), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(600.1), ResponsiveBreakpoint.tablet);
    });

    test('Boundary 2: 999px vs 1000px (Tablet <-> Desktop)', () {
      // 999.0px (Tablet Upper Bound)
      expect(Responsive.isMobileWidth(999.0), isFalse);
      expect(Responsive.isTabletWidth(999.0), isTrue);
      expect(Responsive.isDesktopWidth(999.0), isFalse);
      expect(Responsive.isUltrawideWidth(999.0), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(999.0), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(999.0), ResponsiveBreakpoint.tablet);
      expect(Responsive.valueFromWidth(999.0, mobile: 16.0, tablet: 24.0, desktop: 32.0), 24.0);

      // 999.9px (Fractional Tablet Edge)
      expect(Responsive.isTabletWidth(999.9), isTrue);
      expect(Responsive.isDesktopWidth(999.9), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(999.9), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(999.9), ResponsiveBreakpoint.tablet);

      // 1000.0px (Desktop Lower Bound)
      expect(Responsive.isMobileWidth(1000.0), isFalse);
      expect(Responsive.isTabletWidth(1000.0), isFalse);
      expect(Responsive.isDesktopWidth(1000.0), isTrue);
      expect(Responsive.isUltrawideWidth(1000.0), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(1000.0), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(1000.0), ResponsiveBreakpoint.desktop);
      expect(Responsive.valueFromWidth(1000.0, mobile: 16.0, tablet: 24.0, desktop: 32.0), 32.0);

      // 1000.1px (Desktop Lower Interior)
      expect(Responsive.isTabletWidth(1000.1), isFalse);
      expect(Responsive.isDesktopWidth(1000.1), isTrue);
      expect(Responsive.isDesktopOrLargerWidth(1000.1), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(1000.1), ResponsiveBreakpoint.desktop);
    });

    test('Boundary 3: 1799px vs 1800px (Desktop <-> Ultrawide)', () {
      // 1799.0px (Desktop Upper Bound)
      expect(Responsive.isMobileWidth(1799.0), isFalse);
      expect(Responsive.isTabletWidth(1799.0), isFalse);
      expect(Responsive.isDesktopWidth(1799.0), isTrue);
      expect(Responsive.isUltrawideWidth(1799.0), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(1799.0), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(1799.0), ResponsiveBreakpoint.desktop);

      // 1799.9px (Fractional Desktop Edge)
      expect(Responsive.isDesktopWidth(1799.9), isTrue);
      expect(Responsive.isUltrawideWidth(1799.9), isFalse);
      expect(ResponsiveLayout.getBreakpointFromWidth(1799.9), ResponsiveBreakpoint.desktop);

      // 1800.0px (Ultrawide Lower Bound)
      expect(Responsive.isMobileWidth(1800.0), isFalse);
      expect(Responsive.isTabletWidth(1800.0), isFalse);
      expect(Responsive.isDesktopWidth(1800.0), isFalse);
      expect(Responsive.isUltrawideWidth(1800.0), isTrue);
      expect(Responsive.isDesktopOrLargerWidth(1800.0), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(1800.0), ResponsiveBreakpoint.ultrawide);
    });

    test('Boundary 4: 3440px (Ultrawide Desktop 21:9 / 32:9)', () {
      expect(Responsive.isMobileWidth(3440.0), isFalse);
      expect(Responsive.isTabletWidth(3440.0), isFalse);
      expect(Responsive.isDesktopWidth(3440.0), isFalse);
      expect(Responsive.isUltrawideWidth(3440.0), isTrue);
      expect(Responsive.isDesktopOrLargerWidth(3440.0), isTrue);
      expect(ResponsiveLayout.getBreakpointFromWidth(3440.0), ResponsiveBreakpoint.ultrawide);
    });
  });

  group('Adversarial Layout Behavior: 599px vs 600px (Mobile vs Tablet)', () {
    testWidgets('599px: Renders mobile view, hides sidebar, content padding is 16px', (tester) async {
      tester.view.physicalSize = const Size(599, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double observedPadding = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) {
              observedPadding = Responsive.contentPadding(context);
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Mobile Dashboard'),
                  automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
                ),
                drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
                body: Text('Active Index: $index'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Sidebar must NOT be present
      expect(find.byType(AdminSidebar), findsNothing);
      // Hamburger drawer button MUST be present in AppBar
      expect(find.byType(DrawerButton), findsOneWidget);
      // Content padding must be 16.0
      expect(observedPadding, 16.0);
    });

    testWidgets('600px: Renders tablet view, hides sidebar, content padding transitions to 24px', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double observedPadding = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) {
              observedPadding = Responsive.contentPadding(context);
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Tablet Dashboard'),
                  automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
                ),
                drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
                body: Text('Active Index: $index'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Sidebar must NOT be present on tablet < 1000px
      expect(find.byType(AdminSidebar), findsNothing);
      // Hamburger drawer button MUST be present
      expect(find.byType(DrawerButton), findsOneWidget);
      // Content padding must be 24.0 (tablet padding)
      expect(observedPadding, 24.0);
    });
  });

  group('Adversarial Layout Behavior: 999px vs 1000px (Tablet vs Desktop)', () {
    testWidgets('999px: Tablet upper edge renders drawer, suppresses sidebar', (tester) async {
      tester.view.physicalSize = const Size(999, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Upper Tablet Dashboard'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
    });

    testWidgets('1000px: Desktop threshold renders AdminSidebar and suppresses hamburger menu', (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Desktop Dashboard'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sidebar MUST be rendered
      expect(find.byType(AdminSidebar), findsOneWidget);
      // Sidebar width must be exactly 260px
      final sidebarRenderBox = tester.renderObject<RenderBox>(find.byType(AdminSidebar));
      expect(sidebarRenderBox.size.width, 260.0);

      // Hamburger button MUST be suppressed
      expect(find.byType(DrawerButton), findsNothing);

      // Remaining body width must be 1000 - 260 - 1 = 739px
      final scaffoldFinder = find.descendant(
        of: find.byType(Expanded),
        matching: find.byType(Scaffold),
      );
      expect(scaffoldFinder, findsOneWidget);
      final bodyRenderBox = tester.renderObject<RenderBox>(scaffoldFinder);
      expect(bodyRenderBox.size.width, 739.0);
    });
  });

  group('Adversarial Layout Behavior: 1799px vs 1800px & 3440px (Desktop vs Ultrawide)', () {
    testWidgets('1799px: Desktop max width containment', (tester) async {
      tester.view.physicalSize = const Size(1799, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer.dashboard(
              child: SizedBox(height: 100, child: Text('Dashboard Box')),
            ),
          ),
        ),
      );
      await tester.pump();

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(constrainedBox.constraints.maxWidth, 1600.0);

      // The inner box width should not exceed 1600.0
      final alignRenderBox = tester.renderObject<RenderBox>(find.byType(Align));
      expect(alignRenderBox.size.width, 1799.0);

      final boxRenderBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(boxRenderBox.size.width, 1600.0);
    });

    testWidgets('1800px: Ultrawide threshold strictly prevents infinite stretching', (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              child: SizedBox(height: 100, child: Text('Default Box')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Viewport is 1800px, but default container maxWidth is 1440px
      final boxRenderBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(boxRenderBox.size.width, 1440.0);
      expect(boxRenderBox.size.width < 1800.0, isTrue);
    });

    testWidgets('3440px: Ultrawide monitor (21:9 / 32:9) caps content safely', (tester) async {
      tester.view.physicalSize = const Size(3440, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => const ResponsiveContainer.dashboard(
              child: Text('Ultrawide Dashboard Content'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sidebar is 260px
      final sidebarRenderBox = tester.renderObject<RenderBox>(find.byType(AdminSidebar));
      expect(sidebarRenderBox.size.width, 260.0);

      // Dashboard content box is constrained to 1600px despite 3440px total width
      final boxRenderBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(boxRenderBox.size.width, 1600.0);
    });
  });

  group('Adversarial Stress Testing: Overflow & Edge Cases', () {
    testWidgets('Resizing across 999px -> 1000px -> 999px preserves tab selection and causes no crash', (tester) async {
      // Start at tablet (999px)
      tester.view.physicalSize = const Size(999, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            initialIndex: 1, // Spillerdatabase
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Destination 1'), findsOneWidget);
      expect(find.byType(AdminSidebar), findsNothing);

      // Resize to Desktop (1000px)
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pump();

      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.text('Test Destination 1'), findsOneWidget);

      // Resize to Ultrawide (2560px)
      tester.view.physicalSize = const Size(2560, 1440);
      await tester.pump();

      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.text('Test Destination 1'), findsOneWidget);

      // Resize back to Mobile (390px)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.text('Test Destination 1'), findsOneWidget);
    });

    testWidgets('Narrow mobile viewport (320px) does not cause horizontal RenderFlex overflow in ResponsiveContainer', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              child: Text('Narrow Screen Test'),
            ),
          ),
        ),
      );
      await tester.pump();

      final boxRenderBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      // At 320px screen with 16px edge padding, available width is 320px
      expect(boxRenderBox.size.width, 320.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminDrawer opens and closes without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: const AdminDrawer(selectedIndex: 0),
            body: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Spike Dunk Admin'), findsOneWidget);
      expect(find.text('Kontrollpanel'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Turneringer')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerdatabase')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerkrav')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Logg ut')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ResponsiveTwoColumn transitions between Column at 999px and Row at 1000px', (tester) async {
      // 999px (Tablet upper bound): Stacks as Column
      tester.view.physicalSize = const Size(999, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveTwoColumn(
              left: Text('Left Column'),
              right: Text('Right Column'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Row), findsNothing);

      // 1000px (Desktop lower bound): Lays out side-by-side as Row
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pump();

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('AdminSidebar renders stably on typical desktop screens (1024x768, 1920x1080)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in [const Size(1024, 768), const Size(1920, 1080), const Size(2560, 1440)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: AdminShell(
              testMode: true,
              bodyBuilder: (context, index) => const Text('Desktop Content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AdminSidebar), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
