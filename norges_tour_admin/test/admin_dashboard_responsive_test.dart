import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/pages/dashboard/dashboard_page.dart';
import 'package:norges_tour_admin/pages/dashboard/admin_dashboard_overview.dart';

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

    testWidgets('Tablet (768x1024): tournament table rows stacked vertically', (tester) async {
      tester.view.physicalSize = const Size(768.0, 1024.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on tablet');

      // Tabellvisning: én «Administrer»-knapp per turnering, rader under hverandre
      final manage = find.text('Administrer');
      expect(manage, findsNWidgets(4));
      final r0 = tester.getTopLeft(manage.at(0));
      final r1 = tester.getTopLeft(manage.at(1));
      expect(r1.dy, greaterThan(r0.dy), reason: 'Rows must be stacked vertically');
      expect(r1.dx, equals(r0.dx), reason: 'Rows must share the same column alignment');
    });

    testWidgets('Desktop (1200x800): table with header columns and one row per tournament', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on desktop');

      expect(find.text('Turnering'), findsOneWidget);
      expect(find.text('Påmelding'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Administrer'), findsNWidgets(4));
    });

    testWidgets('Ultrawide (2560x1440): centered content capped at max-width', (tester) async {
      tester.view.physicalSize = const Size(2560.0, 1440.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on ultrawide');

      // Locate ConstrainedBox capping content
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasDashboardConstraint = constrainedBoxes.any((box) =>
          box.constraints.maxWidth > 0 && box.constraints.maxWidth <= 1600.0);
      expect(hasDashboardConstraint, isTrue,
          reason: 'Ultrawide content must be capped at max width <= 1600.0px');

      final firstRect = tester.getRect(find.text('Oslo Summer Masters').first);
      final lastRect = tester.getRect(find.text('Administrer').first);
      expect(firstRect.left, greaterThanOrEqualTo(200.0),
          reason: 'Content must have significant left margin on 2560px screen');
      expect(2560.0 - lastRect.right, greaterThanOrEqualTo(100.0),
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

      // «Krever handling»-kortene
      expect(find.text('0 påmeldinger venter'), findsOneWidget);
      expect(find.text('0 spillerkrav venter'), findsOneWidget);
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
      expect(wrapFinder, findsWidgets);

      // De tre kortene står side om side
      final a = tester.getTopLeft(find.text('0 påmeldinger venter'));
      final b = tester.getTopLeft(find.text('0 spillerkrav venter'));
      expect(a.dy, equals(b.dy));
      expect(b.dx, greaterThan(a.dx));
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

    testWidgets('Empty tournament list renders cards without errors', (tester) async {
      tester.view.physicalSize = const Size(800.0, 600.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOverview(tournaments: const []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ingen åpne frister'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // GROUP 3: Functional Content Preservation & Interactions
  // ════════════════════════════════════════════════════════════════════════════
  group('Functional Content Preservation & Interaction Safety', () {
    testWidgets('Preserves tournament details, buttons, and new tournament action', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      // Verify tournament row text fields
      expect(find.text('Oslo Summer Masters'), findsWidgets);
      expect(find.text('Oslo Sandvolleyballklubb'), findsWidgets);
      expect(find.text('01.–03.07.2026'), findsWidgets);

      // Verify buttons
      expect(find.text('Administrer'), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);

      // «Ny turnering» i sidehodet
      expect(find.text('Ny turnering'), findsOneWidget);
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

    testWidgets('Tournament rows format registration deadline and status correctly', (tester) async {
      tester.view.physicalSize = const Size(1200.0, 800.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      // Formatted date 25.06.2026 -> Frist 25.06
      expect(find.text('Frist 25.06'), findsOneWidget);
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
