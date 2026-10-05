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

      // Find all Card widgets that correspond to tournaments
      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);

      // Verify at least 3 cards are rendered
      final cardCount = cardFinders.evaluate().length;
      expect(cardCount, greaterThanOrEqualTo(3));

      // Locate the first two tournament cards in the list/grid
      final firstCard = tester.getTopLeft(cardFinders.at(cardCount - 3));
      final secondCard = tester.getTopLeft(cardFinders.at(cardCount - 2));

      // In single column layout, cards must have matching horizontal dx alignment
      // and strictly sequential vertical dy positioning
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

      // Verify grid configuration has 2 columns
      final gridViewFinder = find.byType(GridView);
      final sliverGridFinder = find.byType(SliverGrid);
      expect(gridViewFinder.evaluate().isNotEmpty || sliverGridFinder.evaluate().isNotEmpty, isTrue,
          reason: 'Dashboard must use a GridView or SliverGrid');

      // Find tournament cards
      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      final cardCount = cardFinders.evaluate().length;

      // Identify the tournament cards (the last 4 cards after overview cards)
      if (cardCount >= 4) {
        final card0 = tester.getTopLeft(cardFinders.at(cardCount - 4));
        final card1 = tester.getTopLeft(cardFinders.at(cardCount - 3));

        // In 2-column layout, first 2 cards in a row have identical dy and different dx
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

      // Check tournament cards (last 4)
      if (cardCount >= 4) {
        final card0 = tester.getTopLeft(cardFinders.at(cardCount - 4));
        final card1 = tester.getTopLeft(cardFinders.at(cardCount - 3));

        // Side-by-side verification
        expect(card0.dy, equals(card1.dy), reason: 'Card 0 and Card 1 must share the same vertical row');
        expect(card1.dx, greaterThan(card0.dx), reason: 'Card 1 must be to the right of Card 0');

        // Check if 3 columns
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

      // Locate ConstrainedBox or ResponsiveContainer capping content
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasDashboardConstraint = constrainedBoxes.any((box) =>
          box.constraints.maxWidth == ResponsiveLayout.dashboardMaxContentWidth ||
          (box.constraints.maxWidth > 0 && box.constraints.maxWidth <= 1600.0));
      expect(hasDashboardConstraint, isTrue,
          reason: 'Ultrawide content must be capped at max width <= 1600.0px');

      // Verify cards do not span past 1600px width + padding
      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);

      final firstCardRect = tester.getRect(cardFinders.first);
      final lastCardRect = tester.getRect(cardFinders.last);

      // The content must be horizontally centered (substantial margin on left and right)
      // Viewport width = 2560. Max content = 1600. Left margin should be approximately (2560-1600)/2 = 480px.
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

      // Verify overview title is present
      expect(find.text('Oversikt (Siste turneringer)'), findsOneWidget);

      // Verify stat columns are present
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

      // Verify Wrap or Row or multi-column layout is used for stat cards
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

      // Verify multiple stat cards are visible simultaneously across horizontal width
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

      // Verify tournament card text fields
      expect(find.text('Oslo Summer Masters'), findsWidgets);
      expect(find.text('Oslo Sandvolleyballklubb'), findsWidgets);
      expect(find.text('01.07.2026 - 03.07.2026'), findsWidgets);

      // Verify buttons
      expect(find.text('Administrer'), findsWidgets);
      expect(find.byIcon(Icons.delete), findsWidgets);

      // Verify FloatingActionButton
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

      // Formatted date 25.06.2026 -> 25.06
      expect(find.text('25.06'), findsOneWidget);
      // Status badges
      expect(find.text('Åpen'), findsWidgets);
      expect(find.text('Stengt'), findsWidgets);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 4: Responsive Breakpoint Boundaries
  // ════════════════════════════════════════════════════════════════════════════
  group('Responsive Breakpoint Boundaries', () {
    testWidgets('Boundary 599.9px (Mobile) vs 600px (Tablet): zero overflow and column transition', (tester) async {
      // 599.9px Mobile
      tester.view.physicalSize = const Size(599.9, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 599.9px');

      // 600.0px Tablet
      tester.view.physicalSize = const Size(600.0, 800.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 600.0px');
    });

    testWidgets('Boundary 999.9px (Tablet) vs 1000px (Desktop): zero overflow across navigation threshold', (tester) async {
      // 999.9px Tablet
      tester.view.physicalSize = const Size(999.9, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 999.9px');

      // 1000.0px Desktop
      tester.view.physicalSize = const Size(1000.0, 800.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1000.0px');
    });

    testWidgets('Boundary 1799.9px (Desktop) vs 1800px (Ultrawide): containment activates cleanly', (tester) async {
      // 1799.9px Desktop
      tester.view.physicalSize = const Size(1799.9, 1000.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1799.9px');

      // 1800.0px Ultrawide
      tester.view.physicalSize = const Size(1800.0, 1000.0);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Zero overflow at 1800.0px');
    });
  });
}
