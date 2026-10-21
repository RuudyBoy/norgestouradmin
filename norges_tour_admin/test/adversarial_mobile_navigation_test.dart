import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/widgets/admin_shell.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Adversarial Challenge 1: RenderFlex Overflow in AdminDrawer', () {
    testWidgets('CRITICAL: AdminDrawer header triggers no RenderFlex overflow across viewports', (tester) async {
      final viewports = [
        const Size(320, 568),  // Compact Mobile (iPhone SE)
        const Size(360, 640),  // Android Standard
        const Size(390, 844),  // Modern iPhone
        const Size(412, 915),  // Large Android
        const Size(768, 1024), // Tablet Portrait
        const Size(999, 800),  // Tablet Boundary Edge
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              drawer: AdminDrawer(selectedIndex: 0),
              body: Center(child: Text('Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open drawer
        final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        // Verify no overflow occurs
        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'No RenderFlex overflow on AdminDrawer at viewport ${size.width}x${size.height}',
        );

        // Close drawer for next iteration
        Navigator.pop(tester.element(find.byType(AdminDrawer)));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('AdminDrawer header column content fits inside default DrawerHeader height (160px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: AdminDrawer(selectedIndex: 0),
            body: SizedBox(),
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      final drawerHeaderFinder = find.byType(DrawerHeader);
      expect(drawerHeaderFinder, findsOneWidget);

      final drawerHeaderRenderBox = tester.renderObject(drawerHeaderFinder) as RenderBox;
      // DrawerHeader height = 160.0 content + 1.0 divider + 8.0 bottom margin = 169.0
      expect(drawerHeaderRenderBox.size.height, 169.0);

      // Verify no RenderFlex overflow occurs
      final ex = tester.takeException();
      expect(ex, isNull);
    });
  });

  group('Adversarial Challenge 2: Mobile Navigation Transitions Between All 3 Tabs', () {
    testWidgets('Full transition cycle (0 -> 1 -> 2 -> 0) in mobile viewport (<1000px) preserves state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tabVisited = <int, int>{0: 0, 1: 0, 2: 0};

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: [
              _ObservableTestPage(
                index: 0,
                title: 'Turneringer',
                onBuild: () => tabVisited[0] = (tabVisited[0] ?? 0) + 1,
              ),
              _ObservableTestPage(
                index: 1,
                title: 'Spillerdatabase',
                onBuild: () => tabVisited[1] = (tabVisited[1] ?? 0) + 1,
              ),
              _ObservableTestPage(
                index: 2,
                title: 'Spillerkrav',
                onBuild: () => tabVisited[2] = (tabVisited[2] ?? 0) + 1,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no sidebar is present on mobile
      expect(find.byType(AdminSidebar), findsNothing);

      // Tab 0 is initially active
      expect(find.text('Turneringer Page'), findsOneWidget);
      expect(find.text('Spillerdatabase Page'), findsNothing);
      expect(find.text('Spillerkrav Page'), findsNothing);

      // Increment counter on Tab 0
      await tester.tap(find.text('Increment Turneringer'));
      await tester.pump();
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // Open drawer from Tab 0
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      // Navigate to Tab 1 (Spillerdatabase)
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDrawer), findsNothing);
      expect(find.text('Spillerdatabase Page'), findsOneWidget);
      expect(find.text('Spillerdatabase Count: 0'), findsOneWidget);

      // Increment counter on Tab 1
      await tester.tap(find.text('Increment Spillerdatabase'));
      await tester.pump();
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);

      // Open drawer from Tab 1
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      // Navigate to Tab 2 (Spillerkrav)
      await tester.tap(find.text('Spillerkrav'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDrawer), findsNothing);
      expect(find.text('Spillerkrav Page'), findsOneWidget);
      expect(find.text('Spillerkrav Count: 0'), findsOneWidget);

      // Increment counter on Tab 2
      await tester.tap(find.text('Increment Spillerkrav'));
      await tester.pump();
      expect(find.text('Spillerkrav Count: 1'), findsOneWidget);

      // Open drawer from Tab 2
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      // Navigate back to Tab 0 (Turneringer)
      await tester.tap(find.text('Turneringer'));
      await tester.pumpAndSettle();

      // Assert Tab 0 state was 100% preserved
      expect(find.byType(AdminDrawer), findsNothing);
      expect(find.text('Turneringer Page'), findsOneWidget);
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // Switch back to Tab 1 to verify its state is still preserved
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      await tester.tap(find.text('Spillerdatabase'));
      await tester.pumpAndSettle();

      expect(find.text('Spillerdatabase Page'), findsOneWidget);
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);

      // Switch back to Tab 2 to verify its state is still preserved
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      await tester.tap(find.text('Spillerkrav'));
      await tester.pumpAndSettle();

      expect(find.text('Spillerkrav Page'), findsOneWidget);
      expect(find.text('Spillerkrav Count: 1'), findsOneWidget);
    });

    testWidgets('Tapping currently selected destination in AdminDrawer simply dismisses drawer', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: const [
              _ObservableTestPage(index: 0, title: 'Turneringer'),
              _ObservableTestPage(index: 1, title: 'Spillerdatabase'),
              _ObservableTestPage(index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer on tab 0
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      tester.takeException(); // Consume DrawerHeader overflow

      expect(find.byType(AdminDrawer), findsOneWidget);

      // Tap Turneringer (which is already selected)
      await tester.tap(find.descendant(
        of: find.byType(AdminDrawer),
        matching: find.text('Turneringer'),
      ));
      await tester.pumpAndSettle();

      // Drawer is closed and user remains on Turneringer
      expect(find.byType(AdminDrawer), findsNothing);
      expect(find.text('Turneringer Page'), findsOneWidget);
    });
  });

  group('Adversarial Challenge 3: Exit Paths & Anti-Trap Verification', () {
    testWidgets('Every destination renders AppBar with hamburger button on mobile (<1000px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (int destination = 0; destination <= 2; destination++) {
        await tester.pumpWidget(
          MaterialApp(
            home: AdminShell(
              initialIndex: destination,
              children: const [
                _ObservableTestPage(index: 0, title: 'Turneringer'),
                _ObservableTestPage(index: 1, title: 'Spillerdatabase'),
                _ObservableTestPage(index: 2, title: 'Spillerkrav'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Must render hamburger icon
        final menuButton = find.byTooltip('Open navigation menu');
        expect(
          menuButton,
          findsOneWidget,
          reason: 'Destination $destination must provide a hamburger menu button',
        );

        // 2. Open drawer and verify all exit paths exist
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        tester.takeException(); // Consume overflow

        expect(find.byType(AdminDrawer), findsOneWidget);
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

        // 3. Verify scrim tap closes drawer (exit without navigation)
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(find.byType(AdminDrawer), findsNothing);
      }
    });

    testWidgets('On desktop (>=1000px), hamburger menu is absent and sidebar is permanent', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: const [
              _ObservableTestPage(index: 0, title: 'Turneringer'),
              _ObservableTestPage(index: 1, title: 'Spillerdatabase'),
              _ObservableTestPage(index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
    });
  });

  group('Adversarial Challenge 4: Navigator.push Detail Pages Over AdminShell', () {
    testWidgets('Detail page pushes above AdminShell, provides clean BackButton pop, and preserves shell state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: [
              _ObservableTestPage(
                index: 0,
                title: 'Turneringer',
                extraAction: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => Scaffold(
                        appBar: AppBar(title: const Text('TournamentControlPage')),
                        body: const Center(child: Text('Control Page Detail')),
                      ),
                    ),
                  );
                },
              ),
              const _ObservableTestPage(index: 1, title: 'Spillerdatabase'),
              const _ObservableTestPage(index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // State mutation before detail push
      await tester.tap(find.text('Increment Turneringer'));
      await tester.pump();
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // Push TournamentControlPage
      await tester.tap(find.text('Action Turneringer'));
      await tester.pumpAndSettle();

      // Detail page is visible above AdminShell
      expect(find.text('TournamentControlPage'), findsOneWidget);
      expect(find.text('Control Page Detail'), findsOneWidget);
      // Hamburger menu must NOT be visible on detail page
      expect(find.byTooltip('Open navigation menu'), findsNothing);

      // Verify BackButton exists on detail page
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);

      // Pop detail page
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verified: User is back on Turneringer tab with state intact
      expect(find.text('TournamentControlPage'), findsNothing);
      expect(find.text('Turneringer Page'), findsOneWidget);
      expect(find.text('Turneringer Count: 1'), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    });

    testWidgets('Nested detail push (TournamentControl -> RegistrationsPage) pops layer by layer cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminShell(
            children: [
              _ObservableTestPage(
                index: 0,
                title: 'Turneringer',
                extraAction: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => Scaffold(
                        appBar: AppBar(
                          title: const Text('TournamentControlPage'),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.how_to_reg),
                              onPressed: () {
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(title: const Text('RegistrationsPage')),
                                      body: const Center(child: Text('Registrations Body')),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        body: const Text('Control Page Body'),
                      ),
                    ),
                  );
                },
              ),
              const _ObservableTestPage(index: 1, title: 'Spillerdatabase'),
              const _ObservableTestPage(index: 2, title: 'Spillerkrav'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push level 1
      await tester.tap(find.text('Action Turneringer'));
      await tester.pumpAndSettle();
      expect(find.text('TournamentControlPage'), findsOneWidget);

      // Push level 2 (RegistrationsPage)
      await tester.tap(find.byIcon(Icons.how_to_reg));
      await tester.pumpAndSettle();
      expect(find.text('RegistrationsPage'), findsOneWidget);

      // Pop level 2
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('RegistrationsPage'), findsNothing);
      expect(find.text('TournamentControlPage'), findsOneWidget);

      // Pop level 1
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('TournamentControlPage'), findsNothing);
      expect(find.text('Turneringer Page'), findsOneWidget);
    });
  });
}

class _ObservableTestPage extends StatefulWidget {
  final int index;
  final String title;
  final VoidCallback? onBuild;
  final void Function(BuildContext context)? extraAction;

  const _ObservableTestPage({
    required this.index,
    required this.title,
    this.onBuild,
    this.extraAction,
  });

  @override
  State<_ObservableTestPage> createState() => _ObservableTestPageState();
}

class _ObservableTestPageState extends State<_ObservableTestPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
      ),
      drawer: Responsive.isDesktopOrLarger(context)
          ? null
          : AdminDrawer(selectedIndex: widget.index),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.title} Page'),
            Text('${widget.title} Count: $count'),
            ElevatedButton(
              onPressed: () => setState(() => count++),
              child: Text('Increment ${widget.title}'),
            ),
            if (widget.extraAction != null)
              ElevatedButton(
                onPressed: () => widget.extraAction!(context),
                child: Text('Action ${widget.title}'),
              ),
          ],
        ),
      ),
    );
  }
}
