import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Adversarial Challenge 1: Layout Boundaries & Zero RenderFlex Overflow', () {
    // ── Boundary 599px vs 600px (Mobile <-> Tablet) ──────────────────────────
    testWidgets('Boundary 599px (Mobile): Drawer present, Sidebar absent, 16px padding, 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(599.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double paddingObserved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) {
              paddingObserved = Responsive.contentPadding(context);
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Mobile Test'),
                  automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
                ),
                drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
                body: ResponsiveContainer(
                  child: Text('Content index $index'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(paddingObserved, 16.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Boundary 599.9px (Fractional Mobile Edge): Zero overflow, mobile tokens', (tester) async {
      tester.view.physicalSize = const Size(599.9, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Edge Test'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Boundary 600px (Tablet lower bound): Drawer present, Sidebar absent, 24px padding, 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(600.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double paddingObserved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) {
              paddingObserved = Responsive.contentPadding(context);
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Tablet Test'),
                  automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
                ),
                drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
                body: ResponsiveContainer(
                  child: Text('Content index $index'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(paddingObserved, 24.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dynamic resize 599px <-> 600px causes zero overflow and clean transition', (tester) async {
      tester.view.physicalSize = const Size(599.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Dynamic Resize Test'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: ResponsiveContainer(
                child: Text('Padding: ${Responsive.contentPadding(context)}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Padding: 16.0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Resize to 600px
      tester.view.physicalSize = const Size(600.0, 800.0);
      await tester.pumpAndSettle();
      expect(find.text('Padding: 24.0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Resize back to 599px
      tester.view.physicalSize = const Size(599.0, 800.0);
      await tester.pumpAndSettle();
      expect(find.text('Padding: 16.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── Boundary 999px vs 1000px (Tablet <-> Desktop) ────────────────────────
    testWidgets('Boundary 999px: Tablet upper edge renders drawer, suppresses sidebar, 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(999.0, 850.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Upper Tablet Test'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: const Text('Content 999'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Boundary 1000px: Desktop threshold renders sidebar (260px), suppresses hamburger, 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1000.0, 850.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => Scaffold(
              appBar: AppBar(
                title: const Text('Desktop Lower Bound Test'),
                automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
              ),
              drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),
              body: const Text('Desktop Body 1000'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar is rendered
      expect(find.byType(AdminSidebar), findsOneWidget);
      final sidebarBox = tester.renderObject<RenderBox>(find.byType(AdminSidebar));
      expect(sidebarBox.size.width, 260.0);

      // Hamburger button suppressed
      expect(find.byType(DrawerButton), findsNothing);

      // Body width: 1000 - 260 - 1 = 739px
      final scaffoldBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(Expanded),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffoldBox.size.width, 739.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Boundary 999px <-> 1000px: IndexedStack preserves active page state and user inputs', (tester) async {
      // Start on Tablet (999px)
      tester.view.physicalSize = const Size(999.0, 850.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            children: [
              _StatefulHarnessPage(index: 0, title: 'Turneringer'),
              _StatefulHarnessPage(index: 1, title: 'Spillerdatabase'),
              _StatefulHarnessPage(index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // We are on Tab 0 initially.
      expect(find.text('Turneringer Page'), findsOneWidget);
      expect(find.text('Counter: 0'), findsOneWidget);

      // Open drawer on mobile/tablet and switch to Tab 1
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerdatabase')));
      await tester.pumpAndSettle();

      expect(find.text('Spillerdatabase Page'), findsOneWidget);

      // Enter state on Tab 1: increment counter twice, enter text in field
      await tester.tap(find.text('Increment Spillerdatabase'));
      await tester.pump();
      await tester.tap(find.text('Increment Spillerdatabase'));
      await tester.pump();
      expect(find.text('Counter: 2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Test Player Query');
      await tester.pump();
      expect(find.text('Test Player Query'), findsOneWidget);

      // RESIZE VIEWPORT ACROSS BREAKPOINT TO 1000px (Desktop reparenting)
      tester.view.physicalSize = const Size(1000.0, 850.0);
      await tester.pumpAndSettle();

      // Verify desktop structure active
      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsNothing);

      // Verify Tab 1 is STILL active and state is 100% PRESERVED!
      expect(find.text('Spillerdatabase Page'), findsOneWidget);
      expect(find.text('Counter: 2'), findsOneWidget);
      expect(find.text('Test Player Query'), findsOneWidget);

      // Navigate to Tab 2 via desktop sidebar
      await tester.tap(find.descendant(of: find.byType(AdminSidebar), matching: find.text('Spillerkrav')));
      await tester.pumpAndSettle();

      expect(find.text('Spillerkrav Page'), findsOneWidget);
      await tester.tap(find.text('Increment Spillerkrav'));
      await tester.pump();
      expect(find.text('Counter: 1'), findsOneWidget);

      // RESIZE VIEWPORT BACK TO TABLET (999px)
      tester.view.physicalSize = const Size(999.0, 850.0);
      await tester.pumpAndSettle();

      // Sidebar gone, hamburger back
      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);

      // Tab 2 still active, counter 1
      expect(find.text('Spillerkrav Page'), findsOneWidget);
      expect(find.text('Counter: 1'), findsOneWidget);

      // Return to Tab 1 via drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AdminDrawer), matching: find.text('Spillerdatabase')));
      await tester.pumpAndSettle();

      // Tab 1 state still intact!
      expect(find.text('Spillerdatabase Page'), findsOneWidget);
      expect(find.text('Counter: 2'), findsOneWidget);
      expect(find.text('Test Player Query'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    // ── Boundary 1799px vs 1800px & 3440px (Desktop <-> Ultrawide) ───────────
    testWidgets('Boundary 1799px vs 1800px: Max-width containment strictly prevents infinite stretching', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1799px (Desktop max edge)
      tester.view.physicalSize = const Size(1799.0, 1000.0);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ResponsiveContainer(
                  child: Text('Default 1440'),
                ),
                ResponsiveContainer.dashboard(
                  child: Text('Dashboard 1600'),
                ),
                ResponsiveContainer.form(
                  child: Text('Form 1100'),
                ),
                ResponsiveContainer.scoreboard(
                  child: Text('Scoreboard 850'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boxes1799 = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ),
      ).toList();
      expect(boxes1799[0].constraints.maxWidth, 1440.0);
      expect(boxes1799[1].constraints.maxWidth, 1600.0);
      expect(boxes1799[2].constraints.maxWidth, 1100.0);
      expect(boxes1799[3].constraints.maxWidth, 850.0);
      expect(tester.takeException(), isNull);

      // 1800px (Ultrawide threshold)
      tester.view.physicalSize = const Size(1800.0, 1000.0);
      await tester.pumpAndSettle();

      final renderBoxes1800 = tester.renderObjectList<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ),
      ).toList();
      expect(renderBoxes1800[0].size.width, 1440.0);
      expect(renderBoxes1800[1].size.width, 1600.0);
      expect(renderBoxes1800[2].size.width, 1100.0);
      expect(renderBoxes1800[3].size.width, 850.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Boundary 3440px: Ultrawide monitor renders safely with centered containment', (tester) async {
      tester.view.physicalSize = const Size(3440.0, 1440.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            testMode: true,
            bodyBuilder: (context, index) => const Scaffold(
              body: ResponsiveContainer.dashboard(
                child: Text('3440 Ultrawide Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar is 260px
      final sidebarBox = tester.renderObject<RenderBox>(find.byType(AdminSidebar));
      expect(sidebarBox.size.width, 260.0);

      // Content area total available width = 3440 - 260 - 1 = 3179.0px
      final alignBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(Align),
        ),
      );
      expect(alignBox.size.width, 3179.0);

      // Inner constrained box is strictly clamped to 1600px!
      final contentBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ResponsiveContainer),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(contentBox.size.width, 1600.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Challenge 2: Mobile Viewport Stress on AdminDrawer and DrawerHeader', () {
    final mobileViewports = <String, Size>{
      '320x568 (iPhone SE 1st Gen)': const Size(320, 568),
      '360x640 (Android Compact)': const Size(360, 640),
      '375x667 (iPhone 6/7/8/SE2)': const Size(375, 667),
      '320x480 (Extreme Compact / Landscape Min)': const Size(320, 480),
    };

    for (final entry in mobileViewports.entries) {
      testWidgets('Stress test viewport ${entry.key}: zero RenderFlex overflow in Drawer & Header', (tester) async {
        tester.view.physicalSize = entry.value;
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
        await tester.pumpAndSettle();

        // Open drawer
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Check no exception was thrown during opening
        expect(tester.takeException(), isNull);

        // Verify DrawerHeader is visible
        expect(find.byType(DrawerHeader), findsOneWidget);
        expect(find.text('Spike Dunk Admin'), findsOneWidget);
        expect(find.text('Kontrollpanel'), findsOneWidget);

        // Verify all navigation tiles exist in tree
        expect(find.text('Turneringer'), findsOneWidget);
        expect(find.text('Spillerdatabase'), findsOneWidget);
        expect(find.text('Spillerkrav'), findsOneWidget);
        expect(find.text('Logg ut'), findsOneWidget);

        // Close drawer
        Navigator.pop(tester.element(find.byType(AdminDrawer)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Stress test with accessibility TextScaler (1.3x): characterizes DrawerHeader fixed-height overflow boundary', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              drawer: const AdminDrawer(selectedIndex: 0),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // At 1.3x text scaling, DrawerHeader's fixed 160px height constraint causes a 9.0px RenderFlex overflow
      final ex = tester.takeException();
      expect(ex, isNotNull);
      expect(ex.toString(), contains('A RenderFlex overflowed by 9.0 pixels on the bottom'));
    });
  });
}

class _StatefulHarnessPage extends StatefulWidget {
  final int index;
  final String title;

  const _StatefulHarnessPage({
    required this.index,
    required this.title,
  });

  @override
  State<_StatefulHarnessPage> createState() => _StatefulHarnessPageState();
}

class _StatefulHarnessPageState extends State<_StatefulHarnessPage> {
  int counter = 0;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
      ),
      drawer: Responsive.isDesktopOrLarger(context)
          ? null
          : AdminDrawer(selectedIndex: widget.index),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('${widget.title} Page'),
            Text('Counter: $counter'),
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Input for ${widget.title}'),
            ),
            ElevatedButton(
              onPressed: () => setState(() => counter++),
              child: Text('Increment ${widget.title}'),
            ),
          ],
        ),
      ),
    );
  }
}
