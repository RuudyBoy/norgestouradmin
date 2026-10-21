import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';

void main() {
  group('ResponsiveLayout Breakpoints & Width Queries', () {
    test('classifies widths into correct breakpoints', () {
      expect(ResponsiveLayout.getBreakpointFromWidth(390), ResponsiveBreakpoint.mobile);
      expect(ResponsiveLayout.getBreakpointFromWidth(599.9), ResponsiveBreakpoint.mobile);
      expect(ResponsiveLayout.getBreakpointFromWidth(600), ResponsiveBreakpoint.tablet);
      expect(ResponsiveLayout.getBreakpointFromWidth(999.9), ResponsiveBreakpoint.tablet);
      expect(ResponsiveLayout.getBreakpointFromWidth(1000), ResponsiveBreakpoint.desktop);
      expect(ResponsiveLayout.getBreakpointFromWidth(1799.9), ResponsiveBreakpoint.desktop);
      expect(ResponsiveLayout.getBreakpointFromWidth(1800), ResponsiveBreakpoint.ultrawide);
      expect(ResponsiveLayout.getBreakpointFromWidth(2560), ResponsiveBreakpoint.ultrawide);
    });

    test('width boolean queries match breakpoint intervals', () {
      // Mobile (<600)
      expect(Responsive.isMobileWidth(400), isTrue);
      expect(Responsive.isTabletWidth(400), isFalse);
      expect(Responsive.isDesktopWidth(400), isFalse);
      expect(Responsive.isUltrawideWidth(400), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(400), isFalse);

      // Tablet (600 - 1000)
      expect(Responsive.isMobileWidth(800), isFalse);
      expect(Responsive.isTabletWidth(800), isTrue);
      expect(Responsive.isDesktopWidth(800), isFalse);
      expect(Responsive.isUltrawideWidth(800), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(800), isFalse);

      // Desktop (1000 - 1800)
      expect(Responsive.isMobileWidth(1400), isFalse);
      expect(Responsive.isTabletWidth(1400), isFalse);
      expect(Responsive.isDesktopWidth(1400), isTrue);
      expect(Responsive.isUltrawideWidth(1400), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(1400), isTrue);

      // Ultrawide (>=1800)
      expect(Responsive.isMobileWidth(2560), isFalse);
      expect(Responsive.isTabletWidth(2560), isFalse);
      expect(Responsive.isDesktopWidth(2560), isFalse);
      expect(Responsive.isUltrawideWidth(2560), isTrue);
      expect(Responsive.isDesktopOrLargerWidth(2560), isTrue);
    });
  });

  group('Responsive.value cascading fallbacks', () {
    test('cascades down when only mobile is specified', () {
      expect(Responsive.valueFromWidth(400, mobile: 'M'), 'M');
      expect(Responsive.valueFromWidth(800, mobile: 'M'), 'M');
      expect(Responsive.valueFromWidth(1200, mobile: 'M'), 'M');
      expect(Responsive.valueFromWidth(2560, mobile: 'M'), 'M');
    });

    test('cascades from desktop to ultrawide, and mobile to tablet', () {
      expect(Responsive.valueFromWidth(400, mobile: 1, desktop: 3), 1);
      expect(Responsive.valueFromWidth(800, mobile: 1, desktop: 3), 1);
      expect(Responsive.valueFromWidth(1200, mobile: 1, desktop: 3), 3);
      expect(Responsive.valueFromWidth(2560, mobile: 1, desktop: 3), 3);
    });

    test('resolves specific values when all are provided', () {
      expect(
        Responsive.valueFromWidth(400, mobile: 1, tablet: 2, desktop: 3, ultrawide: 4),
        1,
      );
      expect(
        Responsive.valueFromWidth(800, mobile: 1, tablet: 2, desktop: 3, ultrawide: 4),
        2,
      );
      expect(
        Responsive.valueFromWidth(1200, mobile: 1, tablet: 2, desktop: 3, ultrawide: 4),
        3,
      );
      expect(
        Responsive.valueFromWidth(2560, mobile: 1, tablet: 2, desktop: 3, ultrawide: 4),
        4,
      );
    });
  });

  group('ResponsiveContainer Presets', () {
    testWidgets('default container sets maxWidth to 1440', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );

      expect(constrainedBox.constraints.maxWidth, ResponsiveLayout.defaultMaxContentWidth);
      expect(constrainedBox.constraints.maxWidth, 1440.0);
    });

    testWidgets('form preset sets maxWidth to 1100', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer.form(
              child: Text('Form Content'),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );

      expect(constrainedBox.constraints.maxWidth, ResponsiveLayout.formMaxContentWidth);
      expect(constrainedBox.constraints.maxWidth, 1100.0);
    });

    testWidgets('scoreboard preset sets maxWidth to 850', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer.scoreboard(
              child: Text('Scoreboard Content'),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );

      expect(constrainedBox.constraints.maxWidth, ResponsiveLayout.scoreboardMaxContentWidth);
      expect(constrainedBox.constraints.maxWidth, 850.0);
    });

    testWidgets('dashboard preset sets maxWidth to 1600', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer.dashboard(
              child: Text('Dashboard Content'),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ).first,
      );

      expect(constrainedBox.constraints.maxWidth, ResponsiveLayout.dashboardMaxContentWidth);
      expect(constrainedBox.constraints.maxWidth, 1600.0);
    });
  });

  group('ResponsiveTwoColumn', () {
    testWidgets('renders Row on desktop and Column on mobile', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Test Desktop
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveTwoColumn(
              left: Text('Left'),
              right: Text('Right'),
            ),
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsNothing);

      // Test Mobile
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveTwoColumn(
              left: Text('Left'),
              right: Text('Right'),
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Row), findsNothing);
    });
  });

  group('ResponsiveBuilder & ResponsiveConstraintsBuilder', () {
    testWidgets('ResponsiveBuilder provides active breakpoint', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              builder: (context, breakpoint) => Text(breakpoint.name),
            ),
          ),
        ),
      );

      expect(find.text('mobile'), findsOneWidget);
    });

    testWidgets('ResponsiveConstraintsBuilder evaluates local width', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: ResponsiveConstraintsBuilder(
                builder: (context, constraints, breakpoint) => Text(breakpoint.name),
              ),
            ),
          ),
        ),
      );

      expect(find.text('desktop'), findsOneWidget);
    });
  });

  group('ResponsiveWidget', () {
    testWidgets('renders correct slot based on breakpoint', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveWidget(
              mobile: Text('Mobile View'),
              desktop: Text('Desktop View'),
            ),
          ),
        ),
      );

      expect(find.text('Desktop View'), findsOneWidget);
      expect(find.text('Mobile View'), findsNothing);

      tester.view.physicalSize = const Size(500, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveWidget(
              mobile: Text('Mobile View'),
              desktop: Text('Desktop View'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile View'), findsOneWidget);
      expect(find.text('Desktop View'), findsNothing);
    });
  });

  group('AdminShell & Responsive Navigation', () {
    testWidgets('desktop viewport renders permanent AdminSidebar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.text('Spike Dunk'), findsOneWidget);
      expect(find.text('Turneringer'), findsOneWidget);
      expect(find.text('Spillerdatabase'), findsOneWidget);
      expect(find.text('Spillerkrav'), findsOneWidget);
      expect(find.text('Logg ut'), findsOneWidget);
      expect(find.text('Test Destination 0'), findsOneWidget);
    });

    testWidgets('switching tab in AdminSidebar updates active content', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Destination 0'), findsOneWidget);

      // Tap on Spillerdatabase in AdminSidebar
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerdatabase'),
      ));
      await tester.pump();

      expect(find.text('Test Destination 1'), findsOneWidget);

      // Tap on Spillerkrav in AdminSidebar
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerkrav'),
      ));
      await tester.pump();

      expect(find.text('Test Destination 2'), findsOneWidget);
    });

    testWidgets('mobile viewport renders page directly without AdminSidebar', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.text('Test Destination 0'), findsOneWidget);
    });

    testWidgets('switching tabs preserves state via IndexedStack', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump AdminShell with stateful destination widgets
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: const [
              _StatefulTestTab(key: ValueKey('tab_0'), label: 'Turneringer'),
              _StatefulTestTab(key: ValueKey('tab_1'), label: 'Spillerdatabase'),
              _StatefulTestTab(key: ValueKey('tab_2'), label: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pump();

      // 1. Verify IndexedStack is present and index is initially 0
      final stackFinder = find.byType(IndexedStack);
      expect(stackFinder, findsOneWidget);
      IndexedStack stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 0);

      // 2. Initial state on Tab 0
      expect(find.text('Turneringer Count: 0'), findsOneWidget);

      // 3. Mutate Tab 0 state
      await tester.tap(find.text('Increment Turneringer'));
      await tester.pump();
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // 4. Switch to Tab 1 (Spillerdatabase) via AdminSidebar
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerdatabase'),
      ));
      await tester.pump();

      // 5. Verify IndexedStack index updated to 1
      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Spillerdatabase Count: 0'), findsOneWidget);

      // 6. Mutate Tab 1 state
      await tester.tap(find.text('Increment Spillerdatabase'));
      await tester.pump();
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);

      // 7. Switch back to Tab 0 (Turneringer) via AdminSidebar
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Turneringer'),
      ));
      await tester.pump();

      // 8. CRITICAL ASSERTION: Tab 0 state MUST be preserved (Count remains 1)
      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 0);
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // 9. Switch back to Tab 1 and verify its state was also retained
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerdatabase'),
      ));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);
    });

    testWidgets('AdminShell testMode renders all destinations inside IndexedStack', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      final stackFinder = find.byType(IndexedStack);
      expect(stackFinder, findsOneWidget);
      IndexedStack stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 0);
      expect(stack.children.length, 3);
      expect(find.text('Test Destination 0'), findsOneWidget);

      // Switch to index 1
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerdatabase'),
      ));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Test Destination 1'), findsOneWidget);

      // Switch to index 2
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerkrav'),
      ));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 2);
      expect(find.text('Test Destination 2'), findsOneWidget);
    });

    testWidgets('mobile viewport opening drawer and navigating does not trap the user', (tester) async {
      // Set mobile viewport width (<1000px)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: const [
              _MobileTestPage(key: ValueKey('page_0'), index: 0, title: 'Turneringer'),
              _MobileTestPage(key: ValueKey('page_1'), index: 1, title: 'Spillerdatabase'),
              _MobileTestPage(key: ValueKey('page_2'), index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial screen displays Turneringer and no desktop sidebar
      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.text('Turneringer Body'), findsOneWidget);

      // 2. Open drawer via hamburger menu button in AppBar
      final openDrawerButton = find.byTooltip('Open navigation menu');
      expect(openDrawerButton, findsOneWidget);
      await tester.tap(openDrawerButton);
      await tester.pumpAndSettle();

      // 3. Verify AdminDrawer is visible with all navigation destinations
      expect(find.byType(AdminDrawer), findsOneWidget);
      expect(find.text('Spike Dunk Admin'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerdatabase')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerkrav')),
        findsOneWidget,
      );

      // 4. Tap Spillerkrav (Destination 2) inside AdminDrawer
      await tester.tap(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerkrav')),
      );
      await tester.pumpAndSettle();

      // 5. Verify drawer has closed
      expect(find.byType(AdminDrawer), findsNothing);
      expect(find.text('Spillerkrav Body'), findsOneWidget);

      // 6. Assert user is NOT trapped: Destination must provide an exit path
      // Either a leading BackButton (if pushed onto Navigator)
      // OR a hamburger menu drawer button (if hosted in responsive shell)
      final backButton = find.byType(BackButton);
      final menuButton = find.byTooltip('Open navigation menu');
      final hasExitRoute = backButton.evaluate().isNotEmpty || menuButton.evaluate().isNotEmpty;
      expect(
        hasExitRoute,
        isTrue,
        reason: 'Mobile destination must provide either a BackButton or a Drawer menu button to prevent trapping the user',
      );

      // 7. Execute navigation exit to return to Turneringer (Destination 0)
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: find.byType(AdminDrawer), matching: find.text('Turneringer')),
        );
        await tester.pumpAndSettle();
      }

      // 8. Confirm user successfully returned to Turneringer
      expect(find.text('Turneringer Body'), findsOneWidget);
      expect(find.text('Spillerkrav Body'), findsNothing);
    });

    testWidgets('mobile viewport provides AdminDrawer on all destinations and allows switching without trap', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            bodyBuilder: (context, index) {
              selected = index;
              return Scaffold(
                appBar: AppBar(
                  title: Text('Destination $index'),
                  automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
                ),
                drawer: Responsive.isDesktopOrLarger(context)
                    ? null
                    : AdminDrawer(selectedIndex: index),
                body: Center(child: Text('Content $index')),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Destination 0 has drawer leading icon
      expect(find.text('Destination 0'), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);

      // Open drawer on mobile
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      // Tap Spillerkrav (index 2) inside AdminDrawer
      await tester.tap(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerkrav')),
      );
      await tester.pumpAndSettle();

      // Destination 2 is active, drawer is present, user is not trapped!
      expect(selected, 2);
      expect(find.text('Destination 2'), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    });

    testWidgets('AdminDrawer displays navigation items and responds to taps', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: const AdminDrawer(selectedIndex: 0),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Spike Dunk Admin'), findsOneWidget);
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
    });

    testWidgets('AdminDrawer closes automatically when a navigation destination is tapped', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            bodyBuilder: (context, index) {
              selected = index;
              return Scaffold(
                appBar: AppBar(title: Text('Active: $index')),
                drawer: AdminDrawer(selectedIndex: index),
                body: Center(child: Text('Selected: $index')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDrawer), findsOneWidget);

      // Tap on Spillerdatabase in AdminDrawer
      await tester.tap(
        find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerdatabase')),
      );
      await tester.pumpAndSettle();

      // Verify drawer route was popped and is no longer open
      expect(find.byType(AdminDrawer), findsNothing);
      expect(selected, 1);
    });

    testWidgets('resizing viewport across 1000px breakpoint preserves active state', (tester) async {
      // Start on desktop (1200px)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: const [
              _StatefulTestTab(key: ValueKey('tab_0'), label: 'Tab 0'),
              _StatefulTestTab(key: ValueKey('tab_1'), label: 'Tab 1'),
              _StatefulTestTab(key: ValueKey('tab_2'), label: 'Tab 2'),
            ],
          ),
        ),
      );
      await tester.pump();

      // Increment count on Tab 0
      await tester.tap(find.text('Increment Tab 0'));
      await tester.pump();
      expect(find.text('Tab 0 Count: 1'), findsOneWidget);

      // Switch to Tab 1
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Spillerdatabase'),
      ));
      await tester.pump();
      expect(find.text('Tab 1 Count: 0'), findsOneWidget);
      await tester.tap(find.text('Increment Tab 1'));
      await tester.pump();
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Resize across breakpoint to mobile (400px)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();

      // Verify Tab 1 is still active and count is 1
      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Resize back to desktop (1200px)
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pump();

      // Verify Tab 1 is still active
      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Switch to Tab 0 and verify its state was also retained
      await tester.tap(find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.text('Turneringer'),
      ));
      await tester.pump();
      expect(find.text('Tab 0 Count: 1'), findsOneWidget);
    });
  });
}

/// A stateful test destination widget verifying that State instances survive tab switching.
class _StatefulTestTab extends StatefulWidget {
  final String label;
  const _StatefulTestTab({super.key, required this.label});

  @override
  State<_StatefulTestTab> createState() => _StatefulTestTabState();
}

class _StatefulTestTabState extends State<_StatefulTestTab> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.label} Count: $count'),
          ElevatedButton(
            onPressed: () => setState(() => count++),
            child: Text('Increment ${widget.label}'),
          ),
        ],
      ),
    );
  }
}

/// A mobile test destination page providing an AppBar with AdminDrawer.
class _MobileTestPage extends StatelessWidget {
  final int index;
  final String title;

  const _MobileTestPage({
    super.key,
    required this.index,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      drawer: AdminDrawer(selectedIndex: index),
      body: Center(
        child: Text('$title Body'),
      ),
    );
  }
}
