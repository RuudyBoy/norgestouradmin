# Handoff Report: Complete Screen, Page, Form, and Widget Inventory for Responsive Refactoring

**Agent**: `explorer_survey_2`  
**Working Directory**: `c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_survey_2`  
**Target Repository**: `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin`  
**Parent Agent**: `orchestrator_1` (id: `9d9d876f-c592-48a3-9249-10e10a358357`)  
**Timestamp**: 2026-09-29T13:22:00Z  

---

## 1. Observation

A full static and architectural analysis was performed on all 16 Dart files across `norges_tour_admin/lib`. The application consists of 11 distinct UI screens/pages/views, 12 dialogs, 3 major input forms, and multiple reusable components.

### 1.1 Complete Screen & Page Inventory

| # | Screen / Page / View | File Path | Primary Layout Type | Navigation / Entry Point |
|---|---|---|---|---|
| 1 | **AdminApp & AuthGate** | `lib/main.dart:21-80` | `MaterialApp` + `StreamBuilder` + `FutureBuilder` | Root entry point (`main()`) |
| 2 | **AdminLoginPage** | `lib/admin_login_page.dart:6-150` | `Scaffold` > `Center` > `SingleChildScrollView` > `ConstrainedBox(400)` > `Column` | Unauthenticated fallback from `AuthGate` |
| 3 | **AdminDashboard** | `lib/main.dart:82-416` | `Scaffold` > `Column` > (`AdminDashboardOverview` + `Expanded(ListView.builder)`) | Authenticated home screen |
| 4 | **AdminDashboardOverview** | `lib/admin_dashboard_overview.dart:5-200` | `Column` > `SizedBox(height: 120)` > `ListView.builder(horizontal)` | Embedded in `AdminDashboard` body |
| 5 | **AddTournamentPage** | `lib/add_tournament_page.dart:122-788` | `Scaffold` > `Center` > `ConstrainedBox(680)` > `SingleChildScrollView` > `Column` | FAB in `AdminDashboard` (`Navigator.push`) |
| 6 | **EditTournamentPage** | `lib/edit_tournament_page.dart:6-818` | `Scaffold` > `Center` > `ConstrainedBox(680)` > `ListView` | `TournamentControlPage` sub-menu & `TournamentSchedulePage` |
| 7 | **AllPlayersPage** | `lib/all_players_page.dart:7-410` | `Scaffold` > `ListView.builder` (cards) | Drawer in `AdminDashboard` (`Navigator.pushReplacement`) |
| 8 | **PlayerClaimsPage** | `lib/player_claims_page.dart:5-147` | `Scaffold` > `ListView.builder` (cards) | Drawer in `AdminDashboard` (`Navigator.push`) |
| 9 | **RegistrationsPage** | `lib/registrations_page.dart:5-744` | `Scaffold` > `TabBar` + `TabBarView` (2 tabs: Oversikt, Klasser) | AppBar action in `TournamentControlPage` |
| 10 | **MatchControlPage** | `lib/match_control_page.dart:5-410` | `Scaffold` > `Column` > (Status Row + `Expanded(Row([Home, Divider, Away]))`) | Click match card in `TournamentSchedulePage` / `TournamentControlPage` |
| 11 | **TournamentSchedulePage** | `lib/tournament_schedule_page.dart:5-930` | `Scaffold` > `Column` > (Category selector + `TabBarView` [Tidskjema, Kryssninger]) | Standalone page / schedule module |
| 12 | **TournamentControlPage** | `lib/tournament_control_page.dart:12-4412` | `Scaffold` > `Column` > (`_buildCategorySelector` + `Row([NavigationRail, VerticalDivider, Content])`) | Card button "Administrer" in `AdminDashboard` |
| 13 | ↳ **Control Tab 0: Dashboard** | `lib/tournament_control_page.dart:2280-2421` | `SingleChildScrollView` > `GridView.count` (4 stat cards) + `Wrap` chips | `_selectedNavIndex == 0` |
| 14 | ↳ **Control Tab 1: Kampprogram** | `lib/tournament_control_page.dart:1738-2050` | `Column` > 3 horizontal scroll rows + `Expanded(ListView.builder [ExpansionTiles])` | `_selectedNavIndex == 1` |
| 15 | ↳ **Control Tab 2: Oppsett** | `lib/tournament_control_page.dart:2810-3642` | `Column` > Sub-menu bar + `SingleChildScrollView` (Seeding, Groups `Wrap`, Playoff `Row`) | `_selectedNavIndex == 2` |
| 16 | ↳ **Control Tab 3: Lag** | `lib/tournament_control_page.dart:2716-2806` | `Column` > Auto-gen button + `Expanded(ListView.builder)` | `_selectedNavIndex == 3` |

---

### 1.2 Form & Dialog Inventory

| Dialog / Form | Location | Trigger / Context | Layout Structure | Responsive Issues Identified |
|---|---|---|---|---|
| **Add Tournament Form** | `lib/add_tournament_page.dart:341-744` | New tournament creation | Single-column 680px constrained scroll view with 12+ rows | 680px column causes excessive vertical scrolling on desktop; rigid date/time button rows crowd on small mobile screens |
| **Edit Tournament Form** | `lib/edit_tournament_page.dart:246-605` | Tournament editing | Single-column 680px constrained `ListView` | Single-column form on desktop; status cards row (`Expanded` + `Expanded`) crowds on mobile |
| **Player Registration / Edit Dialog** | `lib/all_players_page.dart:17-183` (`_showPlayerDialog`) | FAB "Ny Spiller" or card tap | `AlertDialog` > `SingleChildScrollView` > `Column` > 3 input `Row`s | On mobile (<400px), 2 text fields / dropdowns per row inside an `AlertDialog` have narrow touch targets and cramped labels |
| **Delete All Players Confirm Dialog** | `lib/all_players_page.dart:261-276` | AppBar trash button | `AlertDialog` | Standard confirm dialog, responsive |
| **Delete Tournament Confirm Dialog** | `lib/main.dart:345-367` | Card delete button | `AlertDialog` | Standard confirm dialog, responsive |
| **Category Admin Dialog** | `lib/edit_tournament_page.dart:608-664` (`_CategoryAdminDialog`) | Edit tournament -> "Administrer klasser" | `AlertDialog` > `SizedBox(width: 400)` > `StreamBuilder` > `ListTile`s | Fixed 400px width; on mobile screens <420px, can trigger horizontal clipping if margins are tight |
| **Category Edit Dialog** | `lib/edit_tournament_page.dart:672-725` (`_editCategory`) | Edit icon in Category Admin | `AlertDialog` > `Column(mainAxisSize: min)` | Standard form in modal |
| **Category Delete Confirm Dialog** | `lib/edit_tournament_page.dart:729-748` (`_deleteCategory`) | Trash icon in Category Admin | `AlertDialog` | Standard confirm dialog, responsive |
| **Category Add Dialog** | `lib/edit_tournament_page.dart:750-816` (`_addCategory`) | "Ny klasse" button | `AlertDialog` > `Column(mainAxisSize: min)` | Standard form in modal |
| **Batch Approve Registrations Dialog** | `lib/registrations_page.dart:109-127` (`_acceptAllPending`) | "Godkjenn alle" in stats bar | `AlertDialog` | Standard confirm dialog, responsive |
| **Seeding Preview Dialog** | `lib/registrations_page.dart:152-194` (`_showSeedingPreview`) | Bar chart icon in stats bar | `AlertDialog` > `SizedBox(width: 400)` > `ListView.builder` | Fixed 400px width; could fill desktop better |
| **Match Edit Info Dialog** | `lib/match_control_page.dart:221-267` (`_showEditInfoDialog`) | Edit button in AppBar | `AlertDialog` > `Column([time, court])` | Standard small modal |
| **Set Won Dialog** | `lib/match_control_page.dart:58-82` (`_showSetWonDialog`) | Score triggers set completion | `AlertDialog` (barrierDismissible: false) | Standard modal |
| **Auto-Schedule Dialog** | `lib/tournament_schedule_page.dart:804-880` (`_showGenerateDialog`) | "Auto-skjema" button in AppBar | `AlertDialog` > `Column(ListTiles + format summary)` | Standard modal |
| **Schedule Match Quick Edit Dialog** | `lib/tournament_schedule_page.dart:884-928` (`_editMatchDialog`) | Tap match card in schedule | `AlertDialog` > `Column([court, time])` | Standard modal |
| **Add Team Dialog** | `lib/tournament_control_page.dart:160-183` (`_showAddTeamDialog`) | FAB "Nytt Lag" in Lag tab | `AlertDialog` > `SingleChildScrollView` > `Column` | Dropdowns with full player names in modal |
| **Delete Team Confirm Dialog** | `lib/tournament_control_page.dart:309-324` (`_confirmDeleteTeam`) | Delete button in Lag tab | `AlertDialog` | Standard confirm dialog, responsive |
| **Referee QR Dialog** | `lib/tournament_control_page.dart:328-340` (`_showQrDialog`) | QR icon for match | `AlertDialog` > `QrImageView` | Centered QR code, responsive |
| **Reset Tournament Confirm Dialog** | `lib/tournament_control_page.dart:1108-1123` (`_resetTournament`) | Popup menu "Nullstill hele turneringen" | `AlertDialog` | Standard confirm dialog, responsive |
| **Match Edit Dialog** | `lib/tournament_control_page.dart:1164-1180` (`_showMatchEditDialog`) | Tap match card in Oppsett | `AlertDialog` > `SingleChildScrollView` > `Column` | Standard modal |
| **Team Edit / Move Dialog** | `lib/tournament_control_page.dart:1326-1360` (`_showTeamEditDialog`) | Edit button in Lag tab | `AlertDialog` > `Column([name, seed, group])` | Standard modal |
| **Confirm & Swap Seeding Dialog** | `lib/tournament_control_page.dart:3651-3665` (`_confirmAndSwap`) | Tap two teams in Seeding view | `AlertDialog` | Standard modal |
| **Unpublish Category Confirm Dialog** | `lib/tournament_control_page.dart:3830-3845` (`_unpublishCategory`) | "Avpubliser" button | `AlertDialog` | Standard modal |

---

### 1.3 Resolution-by-Resolution Analysis

#### 1.3.1 Mobile View (< 600px width)
*Direct Observations from Code*:
1. **`TournamentControlPage` (`lib/tournament_control_page.dart:2219-2255`)**:
   ```dart
   Row(
     children: [
       NavigationRail(
         selectedIndex: _selectedNavIndex,
         ...
       ),
       const VerticalDivider(width: 1, thickness: 1),
       Expanded(child: _buildNavContent()),
     ],
   )
   ```
   On mobile (<600px, e.g. 360-390px phone screens), `NavigationRail` occupies ~80px width docked permanently on the left. This squeezes the entire app content area into ~280px!
2. **`TournamentControlPage` Oppsett Sub-menu (`lib/tournament_control_page.dart:2867-2909`)**:
   ```dart
   Container(
     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
     child: Row(
       children: [
         _buildOppsettSubTab('Gruppespill'),
         const SizedBox(width: 8),
         _buildOppsettSubTab('Sluttspill'),
         const SizedBox(width: 8),
         _buildOppsettSubTab('Seeding'),
         const Spacer(),
         if (hasMatches) ...[
           _buildPublishButtonInline(),
           const SizedBox(width: 12),
         ],
         ElevatedButton.icon(...),
       ],
     ),
   )
   ```
   Inside the remaining ~280px, there is an unscrollable `Row` with 3 tab buttons, a `Spacer()`, an optional publish button, and a "Rediger turnering" `ElevatedButton.icon`. The combined intrinsic minimum width exceeds 460px. On mobile, this produces severe `RenderFlex` overflow errors ("A RenderFlex overflowed by XXX pixels on the right").
3. **`TournamentControlPage` Playoff Preview (`lib/tournament_control_page.dart:3627-3638`)**:
   ```dart
   Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: brackets
         .map((b) => Expanded(
               child: Padding(
                 padding: EdgeInsets.only(
                     right: b != brackets.last ? 16 : 0),
                 child: bracketColumn(b),
               ),
             ))
         .toList(),
   )
   ```
   If 4 brackets exist (A, B, C, D), placing them in a `Row` of `Expanded`s inside a 280px container allocates only ~65px per bracket. Match cards, team names, and scores become totally crushed and unreadable.
4. **`RegistrationsPage` Stats Bar (`lib/registrations_page.dart:302-328`)**:
   ```dart
   Container(
     child: Row(
       children: [
         _statChip("Alle", counts['all']!, ...),
         const SizedBox(width: 6),
         _statChip("Venter", counts['pending']!, ...),
         const SizedBox(width: 6),
         _statChip("Godkjent", counts['accepted']!, ...),
         const SizedBox(width: 6),
         _statChip("Vente", counts['waitlist']!, ...),
         const Spacer(),
         IconButton(icon: Icon(Icons.bar_chart), ...),
         TextButton.icon(label: Text("Godkjenn alle"), ...),
       ],
     ),
   )
   ```
   The stats bar `Row` has 4 chips (~240px) + `Spacer` + `IconButton` (48px) + `TextButton.icon` (~130px) = ~420px minimum width. On screens <420px width, this causes a horizontal `RenderFlex` overflow.
5. **`MatchControlPage` Scoreboard (`lib/match_control_page.dart:337-389`)**:
   The 50/50 horizontal split between home and away teams in portrait orientation leaves ~170px per team. Big score buttons (`padding: 24`, `size: 32`) alongside minus buttons take ~156px, leaving almost zero margin. Long team names wrap heavily.

#### 1.3.2 Tablet View (600px - 1000px width)
*Direct Observations from Code*:
1. **`AdminDashboard` (`lib/main.dart:221-410`)**:
   Cards stretch across 600-1000px width.
2. **`AllPlayersPage` (`lib/all_players_page.dart:361-406`)**:
   Each player `Card` spans the full 600-1000px width in a single column `ListView`, leading to a visually sparse item with excessive horizontal gap between avatar on the left and edit/delete icons on the right.
3. **`PlayerClaimsPage` (`lib/player_claims_page.dart:88-142`)**:
   Claim cards stretch across the full width.
4. **`AddTournamentPage` & `EditTournamentPage` (`lib/add_tournament_page.dart:342`, `lib/edit_tournament_page.dart:248`)**:
   Both forms are constrained to `maxWidth: 680` and centered. On a 768px or 900px tablet, this looks well-centered, though it requires significant vertical scrolling.
5. **`TournamentControlPage` Dashboard Tab (`lib/tournament_control_page.dart:2369`)**:
   `GridView.count(crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2)`. At 600-1000px, 4 stat cards fit comfortably across the width.

#### 1.3.3 Desktop View (> 1000px width, e.g. 1200px - 1600px)
*Direct Observations from Code*:
1. **`AdminDashboard` (`lib/main.dart:82-416`)**:
   - Navigation: Relies on mobile `Drawer` hidden behind a hamburger icon (`appBar` with default hamburger, `drawer: Drawer(...)`). On desktop monitors, users must click the hamburger icon every time to switch between Tournaments, Player Database, and Player Claims.
   - List View: `ListView.builder` renders cards stretching 1200-1600px wide. A single tournament item occupies the entire screen width with dead empty space between title and buttons.
2. **`AdminDashboardOverview` (`lib/admin_dashboard_overview.dart:37-55`)**:
   - Explicit horizontal scrolling list (`ListView.builder(scrollDirection: Axis.horizontal)`) with fixed width `Container(width: 260)`. On a 1440px desktop monitor, only 3 cards are shown on the far left, leaving 600+ pixels of empty space to the right, yet still implemented as a horizontal scroller.
3. **`AllPlayersPage` (`lib/all_players_page.dart:361-406`)**:
   - Single-column `ListView.builder` stretches player cards across 1200-1600px. High visual imbalance, poor space efficiency. No table, multi-column grid, or filtering layout.
4. **`TournamentControlPage` Kampprogram Tab (`lib/tournament_control_page.dart:1861-1896`)**:
   - Contains 3 stacked horizontal scroll views (`SingleChildScrollView(scrollDirection: Axis.horizontal)`): one for Status ('Alle', 'Live', 'Kommende', 'Ferdig'), one for Rounds, one for Courts. On desktop, with 1200+ pixels available, horizontally dragging or trackpad-scrolling 3 individual rows is clumsy and inefficient.
5. **`TournamentControlPage` Teams Tab (`lib/tournament_control_page.dart:2758-2800`)**:
   - `ListView.builder` renders single-column team cards across 1200-1600px.
6. **`MatchControlPage` (`lib/match_control_page.dart:336-390`)**:
   - `Row` with two `Expanded` children splits the entire 1200-1600px monitor into two 600-800px halves. Home team score and + / - buttons sit at x=300px, away team score and + / - buttons sit at x=1100px. Operating this during a match requires large head turns and mouse pointer sweeps across the screen.

#### 1.3.4 Ultrawide View (> 1800px width, e.g. 2560px or 3440px)
*Direct Observations from Code*:
1. **Unconstrained Infinite Stretching**:
   - `AdminDashboard` (`lib/main.dart`): Tournament cards stretch to 3440px.
   - `AllPlayersPage` (`lib/all_players_page.dart`): Player cards stretch to 3440px.
   - `PlayerClaimsPage` (`lib/player_claims_page.dart`): Claim cards stretch to 3440px.
   - `RegistrationsPage` (`lib/registrations_page.dart`): Registration cards stretch to 3440px.
   - `MatchControlPage` (`lib/match_control_page.dart`): Home and away teams separated by up to 3000px!
2. **Extreme Narrow Form Disconnect**:
   - `AddTournamentPage` (`lib/add_tournament_page.dart:342`) and `EditTournamentPage` (`lib/edit_tournament_page.dart:248`): `ConstrainedBox(maxWidth: 680)` creates a tiny 680px strip down the middle of a 3440px monitor with 1380px of empty black margins on either side.

---

## 2. Logic Chain

1. **Premise 1 (R1 & Acceptance Criteria)**: The prompt and `ORIGINAL_REQUEST.md` require desktop optimization for PC monitors while preserving mobile responsiveness. Desktop monitors must utilize horizontal space efficiently (via grids, multi-column forms, responsive wrapping, and permanent side navigation) rather than stretching single mobile columns, and mobile views must collapse gracefully without `RenderFlex` overflows.
2. **Premise 2 (Preservation of Functionality R2)**: Firebase queries, document field paths, state management, models, and business logic must remain completely untouched; only layout, constraints, and presentation widgets are to be refactored.
3. **Observation-to-Deduction Step 1**:
   - *Observation*: `main.dart:95-166` and `all_players_page.dart:306-342` use `Drawer`, which is hidden behind a hamburger button on all platforms.
   - *Deduction*: Desktop users are forced into mobile navigation patterns. A shared `NavigationRail` or adaptive desktop scaffold layout will immediately enhance desktop workflow without changing routing or business logic.
4. **Observation-to-Deduction Step 2**:
   - *Observation*: `tournament_control_page.dart:2219-2225` has a permanent `NavigationRail` docked inside a `Row` without screen width checking, while `tournament_control_page.dart:2867-2909` has an unscrollable top sub-menu `Row` containing 5+ widgets.
   - *Deduction*: On mobile screens (<600px), docking `NavigationRail` leaves only ~280px for content, guaranteeing `RenderFlex` overflow on the Oppsett sub-menu and severe squishing on the playoff bracket row.
   - *Required Action*: Replace the fixed `NavigationRail` with an adaptive navigation scaffold: `bottomNavigationBar` on mobile (<600px), and `NavigationRail` on tablet/desktop (>=600px).
5. **Observation-to-Deduction Step 3**:
   - *Observation*: `admin_dashboard_overview.dart:37-55` uses a fixed `ListView.builder(scrollDirection: Axis.horizontal)` with `Container(width: 260)`.
   - *Deduction*: This directly violates requirement R1 ("Where appropriate, convert horizontal scrolling lists to grids or wrapped layouts").
   - *Required Action*: Replace horizontal `ListView` with a responsive `Wrap` or `Row` with flexible cards or responsive `GridView`.
6. **Observation-to-Deduction Step 4**:
   - *Observation*: `all_players_page.dart:361-406`, `main.dart:222-410`, `registrations_page.dart:370-383`, and `player_claims_page.dart:88-142` all use unconstrained single-column `ListView.builder`s rendering `Card`s.
   - *Deduction*: On desktop (>1000px) and ultrawide (>1800px), these cards stretch to full screen width.
   - *Required Action*: Implement `GridView.builder` with `SliverGridDelegateWithMaxCrossAxisExtent` (or responsive crossAxisCount) for player cards and registration cards, and wrap lists in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1200-1400), ...))` to cap ultrawide stretch.
7. **Observation-to-Deduction Step 5**:
   - *Observation*: `add_tournament_page.dart:342` and `edit_tournament_page.dart:248` cap width at 680px as a single vertical column, forcing extensive scrolling on desktop monitors.
   - *Deduction*: Desktop monitors have ample width to display form sections in two distinct columns (e.g. Left: General info + Type; Right: Schedule, Format, Capacity, Gender/Status).
   - *Required Action*: Use `LayoutBuilder` to render a 2-column form grid at >= 900px width with max-width ~1100px, collapsing to single-column on mobile.

---

## 3. Concrete Screen-by-Screen Refactoring Recommendations

### Recommendation Matrix

| Screen / Component | Mobile (<600px) Pattern | Tablet (600-1000px) Pattern | Desktop (>1000px) Pattern | Ultrawide (>1800px) Pattern |
|---|---|---|---|---|
| **App Navigation / Shell** | `Drawer` or `NavigationBar` at bottom | Collapsed `NavigationRail` | Extended / standard `NavigationRail` | Standard `NavigationRail` + centered content |
| **`AdminDashboard`** | 1-column list with `Card`s | 2-column `GridView` or capped 700px list | 2 or 3-column `GridView` of tournament cards | 3 or 4-column `GridView`, `ConstrainedBox(maxWidth: 1400)` |
| **`AdminDashboardOverview`** | Horizontal scroll or 1-column stack | 2-3 card `Row` / `Wrap` | Responsive 3-card `Row` or `Wrap` filling width | Centered `Wrap`, `ConstrainedBox(maxWidth: 1200)` |
| **`AddTournamentPage`** | 1-column form, padding 16px, stacked dates if <400px | 1-column form, padding 24px, maxWidth 700px | 2-column sectioned form, maxWidth 1100px | Centered 2-column form, maxWidth 1100px |
| **`EditTournamentPage`** | 1-column form, status cards stacked vertically | 1-column form, maxWidth 700px | 2-column sectioned form (Info left, Format/Classes right) | Centered 2-column form, maxWidth 1100px |
| **`AllPlayersPage`** | 1-column `ListView` with compact cards | 2-column `GridView` (`maxCrossAxisExtent: 380`) | 3-4 column `GridView` with search/filter bar | 4-6 column `GridView`, `ConstrainedBox(maxWidth: 1600)` |
| **`PlayerClaimsPage`** | Vertical card with stacked action buttons | 1-column card list, maxWidth 800px | Centered 1-2 column cards, maxWidth 1000px | Centered cards, `ConstrainedBox(maxWidth: 1000)` |
| **`RegistrationsPage`** | `Wrap` for stats bar, single-column cards | Responsive stats bar, 1-2 col cards | 2-3 column grid of registrations, maxWidth 1400px | 3-4 column grid, `ConstrainedBox(maxWidth: 1400)` |
| **`MatchControlPage`** | 50/50 split portrait / landscape | Centered scoreboard, maxWidth 700px | Centered scoreboard, `ConstrainedBox(maxWidth: 800)` | Centered scoreboard, `ConstrainedBox(maxWidth: 800)` |
| **`TournamentSchedulePage`** | Time slot + wrapped match cards | 2-3 match cards per time slot | Court-based grid or wrapped slots, maxWidth 1400px | Centered schedule, `ConstrainedBox(maxWidth: 1400)` |
| **`TournamentControlPage`** | `NavigationBar` at bottom, scrollable Oppsett subtabs | `NavigationRail`, scrollable subtabs | Permanent `NavigationRail`, inline subtabs, side-by-side brackets | Permanent `NavigationRail`, centered content, maxWidth 1600px |

---

## 4. Hardcoded Dimensions & Overflow Risk Index

1. **`lib/registrations_page.dart:302`**:
   - `Row` containing 4 stats chips, `Spacer()`, `IconButton()`, and `TextButton.icon()`.
   - Minimum width ~420px. Overflows on mobile devices with <420px viewport width.
   - **Fix**: Use `Wrap(spacing: 8, runSpacing: 8, children: [...])` or `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
2. **`lib/tournament_control_page.dart:2867-2909`**:
   - Unscrollable `Row` containing 3 subtabs, `Spacer()`, publish button, and edit button.
   - Intrinsic width ~460px. When inside mobile layout next to NavigationRail, overflows severely.
   - **Fix**: Wrap sub-menu in a `SingleChildScrollView(scrollDirection: Axis.horizontal)` on mobile or use `Wrap`.
3. **`lib/tournament_control_page.dart:3627-3638`**:
   - Unconditional `Row` with `brackets.map((b) => Expanded(bracketColumn(b)))`.
   - With 4 brackets, each column is crushed to ~65px on mobile.
   - **Fix**: Wrap in `LayoutBuilder`: if width < 900px, use horizontal scrolling `SingleChildScrollView(scrollDirection: Axis.horizontal)` or tabbed bracket view; if >= 900px, use side-by-side columns with minimum width per bracket.
4. **`lib/tournament_control_page.dart:1861-1896`**:
   - 3 separate horizontal scroll views stacked vertically for status, round, and court filters.
   - **Fix**: On desktop (width >= 900px), display filter chips in a clean multi-line `Wrap` so all options are accessible without dragging.
5. **`lib/admin_dashboard_overview.dart:37-55`**:
   - Hardcoded `height: 120` on `SizedBox` and `width: 260` on `_TournamentStatCard`.
   - **Fix**: Use `Wrap` or responsive row where cards adapt dynamically to screen width.
6. **`lib/add_tournament_page.dart:344`**:
   - Hardcoded `padding: const EdgeInsets.all(32)` inside `SingleChildScrollView`.
   - Leaves only 296px width on 360px phones.
   - **Fix**: Responsive padding: `EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24)`.
7. **`lib/match_control_page.dart:336-390`**:
   - Unconstrained `Expanded(child: Row(children: [Expanded, Container, Expanded]))`.
   - Separates home and away scores by up to 3000px on ultrawide monitors.
   - **Fix**: Wrap scoreboard row in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 800), ...))`.

---

## 5. Caveats

1. **No Source Code Modified**: In accordance with the Explorer archetype instructions, no code changes or edits to Flutter files have been made in this phase.
2. **Simulated Matches Logic**: `lib/simulator_logic.dart` was inspected and verified to contain only Firestore business logic and data simulation without UI components. It requires no responsive modifications.
3. **Execution Environment**: `flutter analyze` was not run locally because terminal command execution required interactive user authorization. Baseline verification and compilation checks are specifically assigned to `explorer_survey_3` and subsequent Worker agents.
4. **Web Browser Viewport Variations**: Analysis covers the standard breakpoints (<600px mobile, 600-1000px tablet, >1000px desktop, >1800px ultrawide). Browser zoom levels (125%, 150%) on Windows PC laptops should be tested by the Challenger agent.

---

## 6. Conclusion

The `norges_tour_admin` application contains 11 core UI screens and 12 dialogs. Currently, the UI exhibits two contrasting failure modes:
1. **Desktop & Ultrawide Weakness**: 7 out of 11 screens render single-column mobile lists that stretch infinitely across wide displays (up to 3440px), creating massive dead space and extreme mouse travel. Navigation relies on a mobile `Drawer` hidden behind a hamburger icon, and `AdminDashboardOverview` forces horizontal scrolling despite abundant horizontal real estate.
2. **Mobile Overflow Vulnerabilities**: In `TournamentControlPage`, a permanent `NavigationRail` docked on the left squashes content to ~280px, causing immediate horizontal `RenderFlex` overflows in the Oppsett sub-menu and crushing 4-bracket playoff views into unreadable 65px slivers. Similar overflow risks exist in `RegistrationsPage`'s stats row.

A phased refactoring following the recommended patterns (Adaptive Navigation Shell, `GridView` with `SliverGridDelegateWithMaxCrossAxisExtent`, 2-column desktop forms with `LayoutBuilder`, `ConstrainedBox(maxWidth)` containment, and `Wrap`-based metric/filter bars) will achieve the desktop PC optimization required by R1 while eliminating all mobile overflow risks, with zero changes to Firebase or core business logic.

---

## 7. Verification Method

To independently verify the observations and findings in this report:

1. **Verify Screen & Dialog Counts**:
   - Inspect files in `norges_tour_admin/lib` using `view_file` or `find_by_name`.
   - Verify `showDialog` occurrences via ripgrep:
     `rg "showDialog" lib/`
2. **Verify Layout Observations**:
   - Inspect `lib/main.dart` lines 220-250 to confirm single-column `ListView.builder` stretching on `AdminDashboard`.
   - Inspect `lib/admin_dashboard_overview.dart` lines 37-55 to confirm fixed horizontal `ListView.builder`.
   - Inspect `lib/tournament_control_page.dart` lines 2219-2255 to confirm unconditional `Row` docking `NavigationRail`.
   - Inspect `lib/tournament_control_page.dart` lines 2867-2909 to confirm unscrollable sub-menu `Row`.
   - Inspect `lib/tournament_control_page.dart` lines 3627-3638 to confirm unscrollable 4-bracket `Row`.
   - Inspect `lib/registrations_page.dart` lines 302-328 to confirm 6-item stats `Row`.
3. **Invalidation Conditions**:
   - The findings in this report would be invalidated if any of the cited screens already contained adaptive breakpoint checks (e.g. `LayoutBuilder` switching navigation or wrapping bracket rows). Line-by-line inspection confirms none of these 11 screens currently implement adaptive navigation or multi-column desktop forms.
