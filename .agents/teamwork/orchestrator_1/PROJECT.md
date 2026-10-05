# Project: norges_tour_admin Desktop & Mobile Responsive Refactoring

## Architecture
- **Framework & SDK**: Flutter 3.41.2 / Dart 3.11.0 targeting Flutter Web and responsive viewports.
- **Routing & Navigation**: Retain imperative `Navigator.push` and `Navigator.pop` navigation to strictly satisfy R2 (no disruptive rewrite to GoRouter). Top-level admin navigation is unified via an adaptive shell with a persistent sidebar / navigation rail on desktop (`width >= 1000px`) and a drawer on mobile (`width < 1000px`).
- **Responsive Framework**: Centralized responsive design tokens and layout helpers (`lib/theme/responsive_layout.dart`) providing breakpoint checks:
  - Mobile: `< 600px`
  - Tablet: `600px <= width < 1000px`
  - Desktop: `1000px <= width < 1800px`
  - Ultrawide: `>= 1800px`
- **Content Containment**: Use `Center` and `ConstrainedBox` with standard max-width tokens (forms: 1100px; lists/dashboards: 1400-1600px; scoreboard: 800-960px) to prevent infinite stretching on ultrawide monitors.
- **Functional Integrity (R2)**:
  - 100% Frozen: `lib/simulator_logic.dart`, `lib/firebase_options.dart`.
  - All Firestore queries, writes, transactions, auth listeners, and tournament progression algorithms in hybrid files are strictly preserved.
  - Only presentation widgets, layout structures, and constraints are refactored.

---

## Feature Inventory
| # | Feature / Screen | Description | Milestone | Source |
|---|---|---|---|---|
| 1 | Responsive Layout Tokens & Helper | Centralized breakpoints (`isMobile`, `isTablet`, `isDesktop`, `isUltrawide`) & `ResponsiveContainer` | M1 | Survey |
| 2 | Adaptive App Shell Navigation | Permanent desktop sidebar/rail (>=1000px), mobile drawer (<1000px), unifying top-level destinations | M1 | Survey |
| 3 | AdminDashboard Tournament Grid | Responsive multi-column `GridView` for tournament cards replacing single-column stretched list | M2 | Survey |
| 4 | AdminDashboardOverview Stat Cards | Replace fixed horizontal scroll list with responsive `Row`/`Wrap` layout filling desktop width | M2 | Survey |
| 5 | AdminDashboard Ultrawide Containment | Wrap dashboard body in `Center` and `ConstrainedBox(maxWidth: 1600)` | M2 | Survey |
| 6 | AllPlayersPage Responsive Grid | Multi-column grid (`maxCrossAxisExtent: 360`) for player cards instead of full-width mobile cards | M3 | Survey |
| 7 | Player Create/Edit Dialog Layout | Desktop multi-column layout for input fields in `_showPlayerDialog` while keeping mobile single column | M3 | Survey |
| 8 | PlayerClaimsPage Layout | Desktop-optimized centered cards (`maxWidth: 1000`) with responsive actions | M3 | Survey |
| 9 | AddTournamentPage Responsive Form | 2-column form sections on desktop (>=900px, `maxWidth: 1100`), collapsible to 1-column on mobile | M4 | Survey |
| 10 | EditTournamentPage Responsive Form | 2-column form sections on desktop, responsive status cards, maxWidth 1100px containment | M4 | Survey |
| 11 | MatchControlPage Scoreboard | Centered scoreboard (`ConstrainedBox(maxWidth: 800-960)`) preventing wide separation on ultrawide | M5 | Survey |
| 12 | RegistrationsPage Stats & Cards | Fix mobile overflow in stats bar using `Wrap`/scroll; responsive grid for registration cards on desktop | M5 | Survey |
| 13 | TournamentSchedulePage Timeline | Responsive court schedule layout, tab navigation, and ultrawide containment (`maxWidth: 1400`) | M5 | Survey |
| 14 | TournamentControlPage Adaptive Nav | Adaptive navigation (bottom nav on mobile <700px, permanent rail on desktop >=700px) | M6 | Survey |
| 15 | TournamentControlPage Oppsett Bar | Eliminate mobile `RenderFlex` overflow by enabling horizontal scroll / wrap on subtabs and actions | M6 | Survey |
| 16 | TournamentControlPage Playoff Preview | Responsive bracket view (horizontal scroll on mobile/tablet, side-by-side on desktop) | M6 | Survey |
| 17 | TournamentControlPage Kampprogram Filters | Desktop wrapped filter chips instead of 3 stacked horizontal drag lists | M6 | Survey |
| 18 | TournamentControlPage Teams Grid | Responsive multi-column grid for teams on desktop instead of stretched list | M6 | Survey |
| 19 | TournamentControlPage Ultrawide Cap | Centered max-width containment (`maxWidth: 1600`) for tournament control hub | M6 | Survey |
| 20 | Automated & Visual E2E Verification | Complete verification with `flutter analyze`, `flutter build web`, and multi-resolution layout checks | M7 | Survey |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
| M1 | Responsive Framework & App Shell | `lib/theme/responsive_layout.dart`, `lib/admin_shell.dart`, `lib/main.dart` | none | **DONE** (Gate 3 Passed: 62/62 tests pass, 0 new analyze issues, clean web build, clean audit) |
| M2 | Admin Dashboard & Overview | `lib/main.dart` (`AdminDashboard`), `lib/admin_dashboard_overview.dart` | M1 | PLANNED |
| M3 | Player Database & Claims Views | `lib/all_players_page.dart`, `lib/player_claims_page.dart` | M1 | PLANNED |
| M4 | Tournament Creation & Edit Forms | `lib/add_tournament_page.dart`, `lib/edit_tournament_page.dart` | M1 | PLANNED |
| M5 | Match Control & Standalone Schedule | `lib/match_control_page.dart`, `lib/registrations_page.dart`, `lib/tournament_schedule_page.dart` | M1 | PLANNED |
| M6 | Tournament Operations Control Hub | `lib/tournament_control_page.dart` | M1 | PLANNED |
| M7 | Final Verification & Hardening | Full build compilation, static analysis, multi-resolution visual layout checks | M1-M6 | PLANNED |

---

## Interface Contracts
### `ResponsiveLayout` (`lib/theme/responsive_layout.dart`)
```dart
class ResponsiveLayout {
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1000.0;
  static const double ultrawideBreakpoint = 1800.0;

  static const double defaultMaxContentWidth = 1440.0;
  static const double formMaxContentWidth = 1100.0;
  static const double scoreboardMaxContentWidth = 850.0;

  static bool isMobile(BuildContext context);
  static bool isTablet(BuildContext context);
  static bool isDesktop(BuildContext context);
  static bool isUltrawide(BuildContext context);

  static double contentPadding(BuildContext context); // 16 mobile, 24 tablet, 32 desktop
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  ...
}
```

### Top-Level Shell Contract
```dart
// AdminShell wraps top-level navigation:
// - Turneringer (AdminDashboard)
// - Spillerdatabase (AllPlayersPage)
// - Spillerkrav (PlayerClaimsPage)
// - Logg ut (FirebaseAuth.instance.signOut())
// Desktop (>= 1000px): Persistent sidebar / rail on the left.
// Mobile (< 1000px): Standard AppBar + Drawer.
// Detail pages pushed via Navigator.push(context, MaterialPageRoute(...)) retain their native full-page Scaffolds with back button.
```

---

## Code Layout
- `lib/theme/responsive_layout.dart`: Centralized breakpoints and layout utilities (new file).
- `lib/theme/app_colors.dart`: Color tokens (read-only / preserved).
- `lib/theme/app_theme.dart`: ThemeData configuration (preserved).
- `lib/admin_shell.dart`: Shared responsive navigation shell (or embedded in `lib/main.dart`).
- `lib/main.dart`: Root entry point, `AuthGate`, `AdminDashboard` tournament grid.
- `lib/admin_dashboard_overview.dart`: Responsive overview stats cards.
- `lib/all_players_page.dart`: Responsive player card grid & multi-column dialog.
- `lib/player_claims_page.dart`: Centered claims card view.
- `lib/add_tournament_page.dart`: Responsive 2-column tournament creation form.
- `lib/edit_tournament_page.dart`: Responsive 2-column tournament edit form.
- `lib/match_control_page.dart`: Centered scoreboard with constrained width.
- `lib/registrations_page.dart`: Responsive registration stats bar & card grid.
- `lib/tournament_schedule_page.dart`: Responsive court timeline and tabs.
- `lib/tournament_control_page.dart`: Adaptive navigation, wrapped Oppsett subtabs, responsive playoff bracket, desktop team grid.
- `lib/simulator_logic.dart`: STRICTLY FROZEN (DO NOT TOUCH).
- `lib/firebase_options.dart`: STRICTLY FROZEN (DO NOT TOUCH).
