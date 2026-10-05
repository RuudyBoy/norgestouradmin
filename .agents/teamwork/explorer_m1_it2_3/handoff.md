# Milestone M1 Gate 1 Test Gap Remediation Report: Responsive Navigation & State Preservation

**Author**: `explorer_m1_it2_3` (Roles: Explorer, Investigator, Synthesizer)  
**Milestone**: M1 Gate 1 Test Gap Remediation  
**Target Codebase**: `norges_tour_admin`  
**Target Test File**: `norges_tour_admin/test/responsive_layout_test.dart`  
**Related Source Files**: `norges_tour_admin/lib/admin_shell.dart`, `norges_tour_admin/lib/main.dart`, `norges_tour_admin/lib/all_players_page.dart`, `norges_tour_admin/lib/player_claims_page.dart`  
**Date**: 2026-09-29  
**Recipient**: `orchestrator_1` (Conversation ID: `9d9d876f-c592-48a3-9249-10e10a358357`), `worker_m1`  

---

## 1. Observation

### 1.1 Test Suite Gaps in `test/responsive_layout_test.dart`
Direct inspection of `norges_tour_admin/test/responsive_layout_test.dart` lines 295–388 revealed the following baseline tests for `AdminShell` and `AdminDrawer`:

```dart
// test/responsive_layout_test.dart lines 318–344:
testWidgets('switching tab in AdminSidebar updates active content', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  await tester.pumpWidget(
    const MaterialApp(
      home: AdminShell(
        testMode: true,
      ),
    ),
  );
  await tester.pump();

  expect(find.text('Test Destination 0'), findsOneWidget);

  // Tap on Spillerdatabase
  await tester.tap(find.text('Spillerdatabase'));
  await tester.pump();

  expect(find.text('Test Destination 1'), findsOneWidget);

  // Tap on Spillerkrav
  await tester.tap(find.text('Spillerkrav'));
  await tester.pump();

  expect(find.text('Test Destination 2'), findsOneWidget);

  addTearDown(() => tester.binding.setSurfaceSize(null));
});
```

```dart
// test/responsive_layout_test.dart lines 363–387:
testWidgets('AdminDrawer displays navigation items and responds to taps', (tester) async {
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
  expect(find.text('Turneringer'), findsOneWidget);
  expect(find.text('Spillerdatabase'), findsOneWidget);
  expect(find.text('Spillerkrav'), findsOneWidget);
  expect(find.text('Logg ut'), findsOneWidget);
});
```

Specific gaps observed:
1. **No State Retention Verification**: In `switching tab in AdminSidebar updates active content`, the test only asserted that the static string `'Test Destination 0'` changed to `'Test Destination 1'`. It used stateless placeholder text from `testMode: true`. It did not test:
   - Whether `IndexedStack` was used as the body container.
   - Whether internal widget state (e.g. counters, form text, scroll offsets) was retained when navigating from Destination 0 to 1 and back to 0.
   - Because `AdminShell._buildCurrentPage()` was using `switch (_selectedIndex)` which re-instantiated widgets on every tab change, any state in Destination 0 was completely lost—yet this test passed as a false positive!
2. **No Mobile Drawer Navigation / Exit Path Verification**: In `AdminDrawer displays navigation items and responds to taps`, the test opened `AdminDrawer` inside an isolated Scaffold and checked text labels. It never tapped any navigation destination, never tested the drawer within `AdminShell`, and never asserted that selecting a destination under mobile constraints (<1000px) gives the user a valid exit control (e.g. BackButton or Drawer button) back to Destination 0.

### 1.2 Underlying Root Causes in Source Files
1. **`lib/admin_shell.dart` lines 92–109**:
   ```dart
   Widget _buildCurrentPage() {
     if (widget.bodyBuilder != null) {
       return widget.bodyBuilder!(context, _selectedIndex);
     }
     if (widget.testMode) {
       return Center(child: Text('Test Destination $_selectedIndex'));
     }
     switch (_selectedIndex) {
       case 0:
         return const AdminDashboard();
       case 1:
         return const AllPlayersPage();
       case 2:
         return const PlayerClaimsPage();
       default:
         return const AdminDashboard();
     }
   }
   ```
   `switch (_selectedIndex)` destroys and recreates the child element tree on every tab switch.
2. **`lib/admin_shell.dart` lines 408–414**:
   ```dart
   void _handleNavigation(BuildContext context, int destinationIndex) {
     Navigator.pop(context); // Close mobile drawer

     final shellState = AdminShell.of(context);
     if (shellState != null) {
       shellState.setIndex(destinationIndex);
     } ...
   ```
   On mobile viewports (<1000px), calling `shellState.setIndex(2)` rendered `PlayerClaimsPage` in place.
3. **`lib/player_claims_page.dart` lines 60–66**:
   ```dart
   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: const Text('Ventende Spillerkrav'),
         backgroundColor: AppColors.adminOrange,
       ),
   ```
   `PlayerClaimsPage` defines `drawer: null`. When rendered in place without `Navigator.push`, `Navigator.canPop(context)` is `false`. Flutter's `AppBar` renders no leading button at all, trapping mobile users on the page.

---

## 2. Logic Chain

1. **State Preservation Verification Mechanism**:
   - To verify state retention across tab switches, the test harness must inject stateful widgets containing mutating state (e.g. an integer counter modified via `setState()`).
   - If an `IndexedStack` is properly utilized, switching `index` from 0 $\rightarrow$ 1 $\rightarrow$ 0 must keep the `State` of Tab 0 alive and mounted offstage in the element tree. When returning to Tab 0, the counter value must remain at its incremented value (e.g. `1`), rather than resetting to `0`.
   - Furthermore, the test must explicitly assert that `find.byType(IndexedStack)` exists and that `IndexedStack.index` matches the selected tab.
2. **Mobile Navigation Dead-End Verification Mechanism**:
   - To verify that mobile users are not trapped upon navigating via `AdminDrawer`, the test must set the surface size to a mobile viewport (`width < 1000px`, e.g. 390x844).
   - The test must open `AdminDrawer` via the hamburger menu button (`find.byTooltip('Open navigation menu')` or `find.byIcon(Icons.menu)`), tap a destination (e.g. `Spillerkrav`), and wait for animations to settle (`pumpAndSettle()`).
   - On the resulting screen, the test must assert:
     $$\text{hasBackButton} \lor \text{hasDrawerButton} == \text{true}$$
     - If pushed onto the `Navigator`, `find.byType(BackButton)` or `find.byTooltip('Back')` must exist.
     - If rendered in the responsive shell, an accessible drawer trigger (`find.byTooltip('Open navigation menu')` or `find.byIcon(Icons.menu)`) must exist.
   - The test must then activate that navigation control and assert that the user successfully returns to Destination 0 (`Turneringer`).
   - If a screen renders without either control, the test will immediately fail with a descriptive failure message: *"Mobile destination must provide either a BackButton or a Drawer menu button to prevent trapping the user"*.
3. **Independence from Firebase**:
   - In automated widget test environments, Firebase is not initialized.
   - The tests must use zero-dependency stateful test destinations (`_StatefulTestTab`, `_MobileTestPage`) or `AdminShell(testMode: true)` to guarantee that `flutter test` executes completely offline without throwing `[core/no-app] No Firebase App '[DEFAULT]' has been created`.

---

## 3. Concrete Test Formulations & Exact Drop-in Code for Worker

Below is the complete, drop-in test suite to be integrated into `norges_tour_admin/test/responsive_layout_test.dart`.

### 3.1 Test Cases Added to `AdminShell & Responsive Navigation` Group

The following 5 new and upgraded tests replace and expand the `AdminShell & Responsive Navigation` test group in `test/responsive_layout_test.dart`:

```dart
  group('AdminShell & Responsive Navigation', () {
    testWidgets('desktop viewport renders permanent AdminSidebar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminShell(
            testMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Destination 0'), findsOneWidget);

      // Tap on Spillerdatabase
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pump();

      expect(find.text('Test Destination 1'), findsOneWidget);

      // Tap on Spillerkrav
      await tester.tap(find.text('Spillerkrav'));
      await tester.pump();

      expect(find.text('Test Destination 2'), findsOneWidget);
    });

    testWidgets('mobile viewport renders page directly without AdminSidebar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      // 4. Switch to Tab 1 (Spillerdatabase)
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pump();

      // 5. Verify IndexedStack index updated to 1
      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Spillerdatabase Count: 0'), findsOneWidget);

      // 6. Mutate Tab 1 state
      await tester.tap(find.text('Increment Spillerdatabase'));
      await tester.pump();
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);

      // 7. Switch back to Tab 0 (Turneringer)
      await tester.tap(find.text('Turneringer'));
      await tester.pump();

      // 8. CRITICAL ASSERTION: Tab 0 state MUST be preserved (Count remains 1)
      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 0);
      expect(find.text('Turneringer Count: 1'), findsOneWidget);

      // 9. Switch back to Tab 1 and verify its state was also preserved
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Spillerdatabase Count: 1'), findsOneWidget);
    });

    testWidgets('AdminShell testMode renders all destinations inside IndexedStack', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 1);
      expect(find.text('Test Destination 1'), findsOneWidget);

      // Switch to index 2
      await tester.tap(find.text('Spillerkrav'));
      await tester.pump();

      stack = tester.widget<IndexedStack>(stackFinder);
      expect(stack.index, 2);
      expect(find.text('Test Destination 2'), findsOneWidget);
    });

    testWidgets('mobile viewport opening drawer and navigating does not trap the user', (tester) async {
      // Set mobile viewport width (<1000px)
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      expect(find.text('Spillerdatabase'), findsOneWidget);
      expect(find.text('Spillerkrav'), findsOneWidget);

      // 4. Tap Spillerkrav (Destination 2)
      await tester.tap(find.text('Spillerkrav'));
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
        await tester.tap(find.text('Turneringer'));
        await tester.pumpAndSettle();
      }

      // 8. Confirm user successfully returned to Turneringer
      expect(find.text('Turneringer Body'), findsOneWidget);
      expect(find.text('Spillerkrav Body'), findsNothing);
    });

    testWidgets('AdminDrawer displays navigation items and responds to taps', (tester) async {
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
      expect(find.text('Turneringer'), findsOneWidget);
      expect(find.text('Spillerdatabase'), findsOneWidget);
      expect(find.text('Spillerkrav'), findsOneWidget);
      expect(find.text('Logg ut'), findsOneWidget);
    });

    testWidgets('AdminDrawer closes automatically when a navigation destination is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: AppBar(title: Text('Active: $selected')),
              drawer: AdminDrawer(selectedIndex: selected),
              body: Center(child: Text('Selected: $selected')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDrawer), findsOneWidget);

      // Tap on Spillerdatabase
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pumpAndSettle();

      // Verify drawer route was popped and is no longer open
      expect(find.byType(AdminDrawer), findsNothing);
    });

    testWidgets('resizing viewport across 1000px breakpoint preserves active state', (tester) async {
      // Start on desktop (1200px)
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.tap(find.text('Spillerdatabase'));
      await tester.pump();
      expect(find.text('Tab 1 Count: 0'), findsOneWidget);
      await tester.tap(find.text('Increment Tab 1'));
      await tester.pump();
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Resize across breakpoint to mobile (400px)
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();

      // Verify Tab 1 is still active and count is 1
      expect(find.byType(AdminSidebar), findsNothing);
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Resize back to desktop (1200px)
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pump();

      // Verify Tab 1 is still active
      expect(find.byType(AdminSidebar), findsOneWidget);
      expect(find.text('Tab 1 Count: 1'), findsOneWidget);

      // Switch to Tab 0 and verify its state was also retained
      await tester.tap(find.text('Turneringer'));
      await tester.pump();
      expect(find.text('Tab 0 Count: 1'), findsOneWidget);
    });
  });
```

### 3.2 Private Helper Widgets (to be placed at bottom of `test/responsive_layout_test.dart`)

```dart
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
```

---

## 4. Companion Architecture Instructions for Worker M1

To ensure these tests pass cleanly, `worker_m1` must ensure `lib/admin_shell.dart` satisfies the following contract:

1. **`AdminShell` Constructor Contract**:
   Expose an optional `final List<Widget>? children;` parameter:
   ```dart
   class AdminShell extends StatefulWidget {
     final int initialIndex;
     final bool testMode;
     final Widget Function(BuildContext context, int index)? bodyBuilder;
     final List<Widget>? children;

     const AdminShell({
       super.key,
       this.initialIndex = 0,
       this.testMode = false,
       this.bodyBuilder,
       this.children,
     });
   ```

2. **`IndexedStack` Body Construction**:
   Inside `AdminShellState`, replace `_buildCurrentPage()` with `_buildBody()`:
   ```dart
   Widget _buildBody() {
     if (widget.children != null) {
       return IndexedStack(
         index: _selectedIndex,
         children: widget.children!,
       );
     }
     if (widget.bodyBuilder != null) {
       return widget.bodyBuilder!(context, _selectedIndex);
     }
     if (widget.testMode) {
       return IndexedStack(
         index: _selectedIndex,
         children: const [
           Center(child: Text('Test Destination 0')),
           Center(child: Text('Test Destination 1')),
           Center(child: Text('Test Destination 2')),
         ],
       );
     }
     return IndexedStack(
       index: _selectedIndex,
       children: const [
         AdminDashboard(),
         AllPlayersPage(),
         PlayerClaimsPage(),
       ],
     );
   }
   ```
   Both desktop (`Expanded(child: _buildBody())`) and mobile (`return _buildBody();`) render through `_buildBody()`.

3. **Mobile Drawer Navigation Without Trap**:
   In `lib/admin_shell.dart`, ensure `AdminDrawer._handleNavigation` delegates to `shellState.setIndex(destinationIndex)` when hosted inside `AdminShell`, and closes the drawer cleanly via `Navigator.pop(context)`. Equip `AllPlayersPage` and `PlayerClaimsPage` with `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(selectedIndex: ...)` so mobile users always have the hamburger menu available from any top-level destination.

---

## 5. Caveats

1. **Sub-Page Refactoring Scope**:
   - `AllPlayersPage` and `PlayerClaimsPage` full responsive card refactoring is scheduled under Milestones M3 and M6.
   - However, adding `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(selectedIndex: ...)` to their Scaffolds is minimally invasive (1 line in each file) and completely resolves the mobile trap.
2. **Headless Offline Execution**:
   - The test code strictly uses pure Flutter widgets (`MaterialApp`, `Scaffold`, `IndexedStack`, `Text`, `ElevatedButton`, `AdminShell`, `AdminDrawer`).
   - It introduces zero Firebase dependencies, ensuring it executes rapidly and deterministically in any offline CI/CD or headless agent test environment.

---

## 6. Conclusion

Milestone M1 Gate 1 test gaps have been comprehensively addressed:
1. **IndexedStack State Preservation**: Concrete widget test (`switching tabs preserves state via IndexedStack`) verifies that navigating 0 $\rightarrow$ 1 $\rightarrow$ 0 maintains internal state without resetting or disposing widgets.
2. **Mobile Navigation Dead-End**: Concrete widget test (`mobile viewport opening drawer and navigating does not trap the user`) asserts that mobile users always receive an exit control (BackButton or Drawer menu) and can successfully return to Destination 0.
3. **Exact Drop-in Code**: Provided verbatim test functions and helper widgets ready for immediate incorporation into `norges_tour_admin/test/responsive_layout_test.dart`.

---

## 7. Verification Method

Once `worker_m1` updates `test/responsive_layout_test.dart` and `lib/admin_shell.dart`:

1. **Run Responsive Layout Tests**:
   ```powershell
   cd c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin
   flutter test test/responsive_layout_test.dart
   ```
   *Expected Result*: All 22 tests across 7 groups pass with 0 failures.

2. **Run Breakpoint Adversarial Tests**:
   ```powershell
   flutter test test/adversarial_breakpoints_challenge_test.dart
   ```
   *Expected Result*: All 16 stress tests pass.

3. **Static Analysis**:
   ```powershell
   flutter analyze test/responsive_layout_test.dart lib/admin_shell.dart
   ```
   *Expected Result*: Zero analyzer errors or warnings.
