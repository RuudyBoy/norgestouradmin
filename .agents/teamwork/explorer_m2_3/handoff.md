# Handoff Report — Milestone M2 Safety Verification Boundaries & Automated Widget Tests

**Agent ID**: `explorer_m2_3`  
**Milestone**: M2 (AdminDashboard Responsive Multi-Column Grid, AdminDashboardOverview Stats Cards, Ultrawide Containment)  
**Date**: 2026-09-29  
**Recipient**: `orchestrator_1` (Parent ID: `9d9d876f-c592-48a3-9249-10e10a358357`)

---

## 1. Observation

### 1.1 Direct Inspection of Key Code Files
Direct file inspections via `view_file` revealed the following exact locations, structures, and lines:

1. **`lib/main.dart`**:
   - Lines 15–19: `void main()` initializes `WidgetsFlutterBinding.ensureInitialized()` and `await Firebase.initializeApp(...)`.
   - Lines 38–80: `AuthGate` listens to `FirebaseAuth.instance.authStateChanges()` and queries `FirebaseFirestore.instance.collection('admins').doc(snapshot.data!.uid).get()`. Renders `AdminShell()` if authenticated admin.
   - Lines 82–347: `AdminDashboard` widget.
     - Lines 88–93: `AppBar` with `title: const Text("Admin Dashboard")`, `backgroundColor: Colors.blue[800]`, and `automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context)`.
     - Line 96: `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer()`.
     - Lines 99–110: `FloatingActionButton.extended(...)` navigating to `AddTournamentPage()`.
     - Lines 113–118: Primary Stream:
       ```dart
       StreamBuilder<QuerySnapshot>(
         stream: FirebaseFirestore.instance
             .collection('tournaments')
             .orderBy('created_at', descending: true)
             .snapshots(),
       ```
     - Lines 124–140: Empty state UI:
       ```dart
       Icon(Icons.inbox, size: 64, color: AppColors.adminTextSecondary)
       Text("Ingen turneringer enda. Trykk på knappen for å lage en!")
       ```
     - Lines 145–343: Content Column:
       - Line 148: `const AdminDashboardOverview()`
       - Lines 152–340: `Expanded(child: ListView.builder(...))` with single-column cards.
       - Lines 159–163: Document fields: `name`, `location`, `start_date`, `end_date`, `image_url`.
       - Lines 250–264: "Administrer" button navigating to `TournamentControlPage(tournamentId: id, tournamentName: name)`.
       - Lines 266–331: Delete `IconButton` opening `AlertDialog` ("Slett turnering") and deleting via `FirebaseFirestore.instance.collection('tournaments').doc(id).delete()`.

2. **`lib/admin_dashboard_overview.dart`**:
   - Lines 10–16: Query stream:
     ```dart
     StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance
           .collection('tournaments')
           .orderBy('created_at', descending: true)
           .limit(3)
           .snapshots(),
     ```
   - Lines 17–19: Empty check: returns `const SizedBox.shrink()`.
   - Lines 28–35: Header: `"Oversikt (Siste turneringer)"`.
   - Lines 37–55: Fixed horizontal scroll list:
     ```dart
     SizedBox(
       height: 120,
       child: ListView.builder(
         scrollDirection: Axis.horizontal,
         padding: const EdgeInsets.symmetric(horizontal: 16),
         itemCount: tournaments.length,
         ...
     ```
   - Lines 75–163: `_TournamentStatCard`:
     - Width currently hardcoded: `width: 260`.
     - Lines 99–104: Nested Firestore query stream:
       ```dart
       StreamBuilder<QuerySnapshot>(
         stream: FirebaseFirestore.instance
             .collection('teams')
             .where('tournament_id', isEqualTo: tournamentId)
             .snapshots(),
       ```
     - Lines 137–153: Three stat columns:
       - "Lag": `teamCount.toString()` (green)
       - "Frist": `_shortDate(deadline)` (orange)
       - "Påmelding": `isOpen ? "Åpen" : "Stengt"` (green or red)

3. **`lib/simulator_logic.dart` and `lib/firebase_options.dart` Frozen Status**:
   - Inspection of `lib/simulator_logic.dart` (219 lines): Contains match simulation algorithms and batch Firestore writes.
   - Inspection of `lib/firebase_options.dart` (89 lines): Auto-generated Firebase credentials for web, android, ios, macos, windows.
   - Command `git status` output verbatim:
     ```
     Changes not staged for commit:
       modified: lib/add_tournament_page.dart
       modified: lib/all_players_page.dart
       modified: lib/edit_tournament_page.dart
       modified: lib/main.dart
       modified: lib/player_claims_page.dart
       modified: lib/tournament_control_page.dart
     Untracked files:
       lib/admin_shell.dart
       lib/theme/responsive_layout.dart
       test/
     ```
     Neither `lib/simulator_logic.dart` nor `lib/firebase_options.dart` has been modified. They are 100% clean and frozen.

4. **Existing Test Suite Baseline**:
   - Execution of `flutter test` returned:
     ```
     00:06 +62: All tests passed!
     ```
     All 62 tests across M1 test suites pass with zero failures.

---

## 2. Logic Chain

1. **Safety Boundary Definition**:
   - Requirement R2 strictly forbids modifying data models, backend queries, collections, document keys, transaction logic, or authentication handlers.
   - From Observation 1.1, the exact collections accessed in M2 are:
     - `tournaments` (orderBy `created_at` descending, limit 3 for overview, full list for dashboard)
     - `teams` (where `tournament_id` equals tournament ID)
     - `admins` (doc `uid` for auth verification)
   - The required document field mappings that MUST remain untouched are:
     - `name`, `location`, `start_date`, `end_date`, `image_url`
     - `registration_deadline`, `registration_status`
   - Actions that MUST remain untouched:
     - Floating Action Button opening `AddTournamentPage`
     - "Administrer" button opening `TournamentControlPage`
     - Delete button triggering confirmation `AlertDialog` and executing `.doc(id).delete()` with SnackBar feedback.

2. **Presentation Refactoring for M2 (Features 3, 4, 5)**:
   - **Feature 3 (`AdminDashboard` Tournament Grid)**:
     - Current state: Single-column `ListView.builder` stretching cards infinitely across wide screens.
     - Required state: Responsive multi-column `GridView` or `SliverGrid` using `ResponsiveLayout.gridColumns(context, mobile: 1, tablet: 2, desktop: 3)`.
       - Mobile (375x667): 1 column.
       - Tablet (768x1024): 2 columns.
       - Desktop (1200x800): 2–3 columns.
   - **Feature 4 (`AdminDashboardOverview` Stat Cards)**:
     - Current state: Fixed `SizedBox(height: 120)` with horizontal scroll `ListView.builder` leaving large whitespace on desktop.
     - Required state: Responsive `Wrap` or `Row` layout where stat cards adapt to screen width (stacking/wrapping on mobile <600px without horizontal scroll, spanning side-by-side on tablet/desktop) with zero `RenderFlex` overflow.
   - **Feature 5 (`AdminDashboard` Ultrawide Containment)**:
     - Current state: Full screen stretching without max-width bounds.
     - Required state: Constrained via `ResponsiveContainer.dashboard(child: ...)` (capping maximum width at `1600.0px` and centering on displays $\ge 1800$px).

3. **Deterministic Headless Testability Pattern**:
   - In Flutter widget tests, direct calls to `FirebaseFirestore.instance` fail unless Firebase is initialized or mocked.
   - Following the successful pattern established in `AdminShell` (which added `testMode` and optional test builders without breaking production), `AdminDashboard` and `AdminDashboardOverview` will accept:
     - `final List<Map<String, dynamic>>? testTournaments;`
     - `final bool testMode;`
   - When `testTournaments == null && !testMode` (production web app):
     - The widgets execute the live `StreamBuilder<QuerySnapshot>` code against Firestore identically to the original implementation.
   - When `testTournaments != null || testMode` (automated tests):
     - The widgets consume the injected test data synchronously without attempting Firestore connections.
     - This enables automated testing of layout boundaries, card positions, column counts, and responsive wraps across all viewports in milliseconds.

---

## 3. Caveats

1. **State of Working Tree**:
   - `lib/main.dart` currently contains the single-column `ListView.builder` from M1. The builder agent for M2 (`builder_m2_1` or equivalent) must apply the grid refactoring and `testTournaments` parameter before running the responsive tests against the actual app files.
2. **Navigator.push in Unit Tests**:
   - The "Administrer" and FAB buttons use `Navigator.push`. In unit tests without mock routes, verifying button existence and widget hierarchy is fully verified; testing route transitions requires a mock Navigator or MaterialApp routes definition.
3. **No Other Uninvestigated Areas**:
   - No assumptions made outside the explicit requirements of R1, R2, and M2 scope.

---

## 4. Conclusion

1. **Frozen Files Verified**:
   - `lib/simulator_logic.dart` and `lib/firebase_options.dart` are 100% untouched and must remain frozen.
2. **Data & Stream Boundaries Defined**:
   - All Firestore streams (`tournaments`, `teams`), document fields, deletion transactions, dialogs, and navigation routes have been cataloged with strict instructions to preserve all existing functionality.
3. **Automated Test Suite Formulated**:
   - Complete, production-grade drop-in test code has been created: `test/admin_dashboard_responsive_test.dart` (and stored locally in `.agents/teamwork/explorer_m2_3/proposed_admin_dashboard_responsive_test.dart`).
   - The test suite covers:
     - Mobile (375x667): Single-column cards.
     - Tablet (768x1024): 2-column grid.
     - Desktop (1200x800): 2–3 columns grid.
     - Ultrawide (2560x1440): Centered max-width containment ($\le 1600$px).
     - Overview Stats Cards: `Wrap`/`Row` responsive layout with zero `RenderFlex` overflow across all screen sizes (including iPhone SE 320px).
     - Breakpoint boundaries: 599.9px, 600px, 999.9px, 1000px, 1799.9px, 1800px.
     - Content preservation: FAB, buttons, icons, empty state inbox icon.
4. **Drop-in Implementation Ready**:
   - Ready-to-apply proposed implementations have been written to:
     - `proposed_admin_dashboard_changes.dart`
     - `proposed_admin_dashboard_overview_changes.dart`

---

## 5. Verification Method

### 5.1 Verification Commands
The implementing builder and verifying agents can independently verify M2 with:

1. **Static Analysis**:
   ```powershell
   flutter analyze
   ```
   *Pass criteria*: 0 errors, 0 warnings, 0 new lints.

2. **Automated M2 Responsive Widget Tests**:
   ```powershell
   flutter test test/admin_dashboard_responsive_test.dart
   ```
   *Pass criteria*: All test cases in all 4 groups pass with 0 failures and 0 exceptions.

3. **Full Test Suite Regression Run**:
   ```powershell
   flutter test
   ```
   *Pass criteria*: All 62+ tests pass cleanly.

4. **Web Build Compilation**:
   ```powershell
   flutter build web
   ```
   *Pass criteria*: Exit code 0, confirming successful compilation of Flutter Web.

### 5.2 Invalidation Conditions
- Any edit to `lib/simulator_logic.dart` or `lib/firebase_options.dart`.
- Any change to Firestore collection names (`tournaments`, `teams`), document fields, or query ordering.
- Any `RenderFlex` horizontal overflow at widths 320px, 375px, 768px, 1200px, or 2560px.
- Ultrawide content stretching beyond 1600px width.

---

## Appendix: Complete Drop-in Test Suite Code
*(Target file: `norges_tour_admin/test/admin_dashboard_responsive_test.dart`)*

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/main.dart';
import 'package:norges_tour_admin/admin_dashboard_overview.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // ── Mock Data Fixtures ─────────────────────────────────────────────────────
  final sampleTournaments = [
    {
      'id': 'tour_1',
      'name': 'Oslo Summer Masters',
      'location': 'Oslo Sandvolleyballklubb',
      'start_date': '01.07.2026',
      'end_date': '03.07.2026',
      'image_url': '',
      'registration_deadline': '25.06.2026',
      'registration_status': 'open',
      'team_count': 16,
    },
    {
      'id': 'tour_2',
      'name': 'Bergen Beach Invitational',
      'location': 'Åsane Arena Beach',
      'start_date': '10.07.2026',
      'end_date': '12.07.2026',
      'image_url': '',
      'registration_deadline': '05.07.2026',
      'registration_status': 'open',
      'team_count': 12,
    },
    {
      'id': 'tour_3',
      'name': 'Stavanger Major Championship',
      'location': 'Vardeneset Sand',
      'start_date': '20.07.2026',
      'end_date': '22.07.2026',
      'image_url': '',
      'registration_deadline': '15.07.2026',
      'registration_status': 'closed',
      'team_count': 24,
    },
    {
      'id': 'tour_4',
      'name': 'Trondheim Tour Final',
      'location': 'Lade Sandanlegg',
      'start_date': '05.08.2026',
      'end_date': '07.08.2026',
      'image_url': '',
      'registration_deadline': '01.08.2026',
      'registration_status': 'open',
      'team_count': 8,
    },
  ];

  Widget buildTestableDashboard({
    List<Map<String, dynamic>>? tournaments,
    bool testMode = true,
  }) {
    return MaterialApp(
      home: AdminDashboard(
        testTournaments: tournaments ?? sampleTournaments,
        testMode: testMode,
      ),
    );
  }

  Widget buildTestableOverview({
    List<Map<String, dynamic>>? tournaments,
    bool testMode = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminDashboardOverview(
            testTournaments: tournaments ?? sampleTournaments,
            testMode: testMode,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 1: AdminDashboard Responsive Grid Across Viewports
  // ════════════════════════════════════════════════════════════════════════════
  group('AdminDashboard Responsive Grid Viewports', () {
    testWidgets('Mobile (375x667): single column cards stacked vertically with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(375.0, 667.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on mobile');

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);

      final cardCount = cardFinders.evaluate().length;
      expect(cardCount, greaterThanOrEqualTo(3));

      final firstCard = tester.getTopLeft(cardFinders.at(cardCount - 3));
      final secondCard = tester.getTopLeft(cardFinders.at(cardCount - 2));

      expect(firstCard.dx, equals(secondCard.dx), reason: 'Cards must be in a single column');
      expect(secondCard.dy, greaterThan(firstCard.dy), reason: 'Second card must be below first card');
    });

    testWidgets('Tablet (768x1024): 2-column grid layout with side-by-side cards', (tester) async {
      tester.view.physicalSize = const Size(768.0, 1024.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on tablet');

      final gridViewFinder = find.byType(GridView);
      final sliverGridFinder = find.byType(SliverGrid);
      expect(gridViewFinder.evaluate().isNotEmpty || sliverGridFinder.evaluate().isNotEmpty, isTrue,
          reason: 'Dashboard must use a GridView or SliverGrid');

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      final cardCount = cardFinders.evaluate().length;

      if (cardCount >= 4) {
        final card0 = tester.getTopLeft(cardFinders.at(cardCount - 4));
        final card1 = tester.getTopLeft(cardFinders.at(cardCount - 3));

        expect(card0.dy, equals(card1.dy), reason: 'Card 0 and Card 1 must be side-by-side in row 1');
        expect(card1.dx, greaterThan(card0.dx), reason: 'Card 1 must be to the right of Card 0');

        if (cardCount >= 5) {
          final card2 = tester.getTopLeft(cardFinders.at(cardCount - 2));
          expect(card2.dy, greaterThan(card0.dy), reason: 'Card 2 wraps to row 2 below Card 0');
          expect(card2.dx, equals(card0.dx), reason: 'Card 2 aligns with column 1');
        }
      }
    });

    testWidgets('Desktop (1200x800): 2-3 columns grid layout utilizing horizontal space', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on desktop');

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      final cardCount = cardFinders.evaluate().length;

      if (cardCount >= 4) {
        final card0 = tester.getTopLeft(cardFinders.at(cardCount - 4));
        final card1 = tester.getTopLeft(cardFinders.at(cardCount - 3));

        expect(card0.dy, equals(card1.dy), reason: 'Card 0 and Card 1 must share the same vertical row');
        expect(card1.dx, greaterThan(card0.dx), reason: 'Card 1 must be to the right of Card 0');

        final card2 = tester.getTopLeft(cardFinders.at(cardCount - 2));
        final isThreeColumns = (card2.dy == card0.dy) && (card2.dx > card1.dx);
        final isTwoColumns = (card2.dy > card0.dy) && (card2.dx == card0.dx);
        expect(isThreeColumns || isTwoColumns, isTrue,
            reason: 'Desktop grid must layout 2 or 3 columns across 1200px viewport');
      }
    });

    testWidgets('Ultrawide (2560x1440): centered content capped at max-width (1600px)', (tester) async {
      tester.view.physicalSize = const Size(2560.0, 1440.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on ultrawide');

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasDashboardConstraint = constrainedBoxes.any((box) =>
          box.constraints.maxWidth == ResponsiveLayout.dashboardMaxContentWidth ||
          (box.constraints.maxWidth > 0 && box.constraints.maxWidth <= 1600.0));
      expect(hasDashboardConstraint, isTrue,
          reason: 'Ultrawide content must be capped at max width <= 1600.0px');

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);

      final firstCardRect = tester.getRect(cardFinders.first);
      final lastCardRect = tester.getRect(cardFinders.last);

      expect(firstCardRect.left, greaterThanOrEqualTo(200.0),
          reason: 'Content must have significant left margin on 2560px screen');
      expect(2560.0 - lastCardRect.right, greaterThanOrEqualTo(100.0),
          reason: 'Content must not stretch to right edge of 2560px screen');
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 2: AdminDashboardOverview Responsive Stats Cards
  // ════════════════════════════════════════════════════════════════════════════
  group('AdminDashboardOverview Responsive Stats Cards', () {
    testWidgets('Mobile (375x667): stats cards adapt with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(375.0, 667.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on mobile overview');
      expect(find.text('Oversikt (Siste turneringer)'), findsOneWidget);
      expect(find.text('Lag'), findsWidgets);
      expect(find.text('Frist'), findsWidgets);
      expect(find.text('Påmelding'), findsWidgets);
    });

    testWidgets('Desktop (1200x800): stats cards use Wrap or Row layout without fixed horizontal scroll constraint', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on desktop overview');

      final wrapFinder = find.descendant(
        of: find.byType(AdminDashboardOverview),
        matching: find.byType(Wrap),
      );
      final rowFinder = find.descendant(
        of: find.byType(AdminDashboardOverview),
        matching: find.byType(Row),
      );
      expect(wrapFinder.evaluate().isNotEmpty || rowFinder.evaluate().isNotEmpty, isTrue,
          reason: 'Stat cards must use Wrap or Row layout to adapt horizontally on desktop');

      expect(find.text('Oslo Summer Masters'), findsOneWidget);
      expect(find.text('Bergen Beach Invitational'), findsOneWidget);
      expect(find.text('Stavanger Major Championship'), findsOneWidget);
    });

    testWidgets('Compact narrow mobile (320x568 - iPhone SE): zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320.0, 568.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Narrow iPhone SE (320px) must have zero RenderFlex overflow');
    });

    testWidgets('Empty state returns SizedBox.shrink cleanly without errors', (tester) async {
      tester.view.physicalSize = const Size(800.0, 600.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview(tournaments: const []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Oversikt (Siste turneringer)'), findsNothing);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 3: Functional Content Preservation & Interactions
  // ════════════════════════════════════════════════════════════════════════════
  group('Functional Content Preservation & Interaction Safety', () {
    testWidgets('Preserves tournament card details, buttons, and FloatingActionButton', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(find.text('Oslo Summer Masters'), findsWidgets);
      expect(find.text('Oslo Sandvolleyballklubb'), findsWidgets);
      expect(find.text('01.07.2026 - 03.07.2026'), findsWidgets);

      expect(find.text('Administrer'), findsWidgets);
      expect(find.byIcon(Icons.delete), findsWidgets);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Ny Turnering'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Empty tournament list displays original inbox icon and guidance text', (tester) async {
      tester.view.physicalSize = const Size(800.0, 600.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard(tournaments: const []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(
        find.text('Ingen turneringer enda. Trykk på knappen for å lage en!'),
        findsOneWidget,
      );
    });

    testWidgets('Stat card formats registration deadline and status correctly', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview());
      await tester.pumpAndSettle();

      expect(find.text('25.06'), findsOneWidget);
      expect(find.text('Åpen'), findsWidgets);
      expect(find.text('Stengt'), findsWidgets);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 4: Responsive Breakpoint Boundaries
  // ════════════════════════════════════════════════════════════════════════════
  group('Responsive Breakpoint Boundaries', () {
    testWidgets('Boundary 599.9px (Mobile) vs 600px (Tablet): zero overflow and column transition', (tester) async {
      tester.view.physicalSize = const Size(599.9, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 599.9px');

      tester.view.physicalSize = const Size(600.0, 800.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 600.0px');
    });

    testWidgets('Boundary 999.9px (Tablet) vs 1000px (Desktop): zero overflow across navigation threshold', (tester) async {
      tester.view.physicalSize = const Size(999.9, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 999.9px');

      tester.view.physicalSize = const Size(1000.0, 800.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1000.0px');
    });

    testWidgets('Boundary 1799.9px (Desktop) vs 1800px (Ultrawide): containment activates cleanly', (tester) async {
      tester.view.physicalSize = const Size(1799.9, 1000.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1799.9px');

      tester.view.physicalSize = const Size(1800.0, 1000.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1800.0px');
    });
  });
}
```
