import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

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
      // Mobile
      expect(Responsive.isMobileWidth(400), isTrue);
      expect(Responsive.isTabletWidth(400), isFalse);
      expect(Responsive.isDesktopWidth(400), isFalse);
      expect(Responsive.isUltrawideWidth(400), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(400), isFalse);

      // Tablet
      expect(Responsive.isMobileWidth(800), isFalse);
      expect(Responsive.isTabletWidth(800), isTrue);
      expect(Responsive.isDesktopWidth(800), isFalse);
      expect(Responsive.isUltrawideWidth(800), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(800), isFalse);

      // Desktop
      expect(Responsive.isMobileWidth(1400), isFalse);
      expect(Responsive.isTabletWidth(1400), isFalse);
      expect(Responsive.isDesktopWidth(1400), isTrue);
      expect(Responsive.isUltrawideWidth(1400), isFalse);
      expect(Responsive.isDesktopOrLargerWidth(1400), isTrue);

      // Ultrawide
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
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
  });

  group('ResponsiveTwoColumn', () {
    testWidgets('renders Row on desktop and Column on mobile', (tester) async {
      // Test Desktop
      await tester.binding.setSurfaceSize(const Size(1200, 800));
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
      await tester.binding.setSurfaceSize(const Size(400, 800));
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

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
