# Handoff Report: Milestone M1 Adaptive Navigation Shell (`AdminShell`)

## 1. Observation

### Existing Navigation Architecture
1. **`lib/main.dart` lines 38-80 (`AuthGate`)**:
   - Lines 63-65 directly return `const AdminDashboard()` upon verifying admin document in Firestore:
     ```dart
     if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
       return const AdminDashboard();
     }
     ```
2. **`lib/main.dart` lines 82-166 (`AdminDashboard` Scaffold & Drawer)**:
   - Returns a `Scaffold` with:
     - `appBar`: `AppBar(title: const Text("Admin Dashboard"), backgroundColor: Colors.blue[800])`
     - `drawer`: Hardcoded `Drawer` containing 4 `ListTile` items:
       - 'Turneringer': `Navigator.pop(context);`
       - 'Spillerdatabase': `Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AllPlayersPage()));`
       - 'Ventende Spillerkrav': `Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerClaimsPage()));`
       - 'Logg ut': `await FirebaseAuth.instance.signOut(); if (context.mounted) Navigator.pop(context);`
     - `floatingActionButton`: `FloatingActionButton.extended("Ny Turnering", ...)` pushing `AddTournamentPage()`.
     - `body`: `StreamBuilder<QuerySnapshot>` rendering `AdminDashboardOverview()` and `ListView.builder` of tournaments with "Administrer" buttons pushing `TournamentControlPage(...)`.
3. **`lib/all_players_page.dart` lines 188-343 (`AllPlayersPage` Scaffold & Drawer)**:
   - Returns a `Scaffold` with:
     - `appBar`: `AppBar(title: const Text("Spillerdatabase"), backgroundColor: AppColors.green, actions: [...])`
     - `drawer`: Hardcoded duplicate `Drawer` containing only 2 items ('Turneringer', 'Spillerdatabase'). Missing 'Ventende Spillerkrav' and 'Logg ut'.
     - 'Turneringer' executes `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));`
4. **`lib/player_claims_page.dart` lines 59-146 (`PlayerClaimsPage`)**:
   - Returns a `Scaffold` with:
     - `appBar`: `AppBar(title: const Text('Ventende Spillerkrav'), backgroundColor: AppColors.adminOrange)`
     - No `drawer` is defined. Relies strictly on being pushed with `Navigator.push` and popping with the back button.
5. **Detail Pages Navigation**:
   - All detail pages (`TournamentControlPage`, `AddTournamentPage`, `MatchControlPage`, `RegistrationsPage`, `TournamentSchedulePage`, `EditTournamentPage`) return independent `Scaffold` widgets and are invoked via `Navigator.push(context, MaterialPageRoute(...))`.
   - In all detail pages, Flutter's default `AppBar` automatically renders an `IconButton` leading back arrow (`Icons.arrow_back`) which invokes `Navigator.maybePop(context)`.

---

## 2. Logic Chain

### Why a Unified `AdminShell` is Required
1. **Desktop Viewport Requirements (`width >= 1000px`)**:
   - On PC/desktop monitors, hiding the primary navigation inside a mobile hamburger drawer forces extra clicks and leaves the left side of the screen underutilized.
   - A permanent left sidebar (`width: 260px`) provides instant 1-click switching between Turneringer, Spillerdatabase, Spillerkrav, and Logg ut, with clear active state highlights.
2. **Eliminating Redundant Hamburger Icons on Desktop**:
   - If a `Scaffold` has a `drawer: Drawer(...)`, Flutter's `AppBar` automatically displays a hamburger icon in the leading position.
   - On desktop, if the permanent sidebar is already visible, a hamburger icon is redundant and confusing.
   - By setting `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(...)` and `automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context)`, the hamburger icon is cleanly suppressed on desktop while remaining fully active on mobile (`width < 1000px`).
3. **Preserving Page Internal Logic and State (R2 Compliance)**:
   - `AllPlayersPage` is a `StatefulWidget` with private controllers and methods (`_showPlayerDialog()`, batch operations, randomizer).
   - `AdminDashboard` has tournament deletion dialogs and FAB handlers.
   - Wrapping them inside `AdminShell` (where desktop displays `Row(AdminSidebar, VerticalDivider, Expanded(activePage))` and mobile displays `activePage`) ensures that all private state, dialogs, floating action buttons, and Firestore streams continue operating with zero breaking changes.
4. **Zero Disruption to Detail Pages**:
   - Because detail pages are pushed with `Navigator.push(context, MaterialPageRoute(...))` to the root `Navigator`, detail pages open on top of the shell with their native back buttons.
   - Tapping back pops the route and returns directly to `AdminShell` at the same selected destination tab.
5. **Stateful Coordination with Standalone Fallback**:
   - `AdminDrawer` and `AdminSidebar` check `final shell = AdminShell.of(context);`.
   - If found, `shell.setIndex(newIndex)` updates the active view with zero reload delay.
   - If not found (e.g. if a screen is tested in isolation), it falls back to `Navigator.pushReplacement`.

---

## 3. Caveats

1. **Dependency on Milestone M1_1 Tokens**:
   - `lib/admin_shell.dart` relies on `Responsive.isDesktopOrLarger(context)` and `AppColors`. The responsive framework file `lib/theme/responsive_layout.dart` created by Worker M1_1 must be committed alongside or before `lib/admin_shell.dart`.
2. **Page Content Refactoring Scheduled for Later Milestones**:
   - In Milestone M1, `AdminDashboard` tournament cards grid layout is scheduled for Milestone M2.
   - `AllPlayersPage` player cards grid and `PlayerClaimsPage` responsive layout are scheduled for Milestone M3.
   - Milestone M1 exclusively establishes the shell, sidebar, mobile drawer, and top-level routing coordination.
3. **Deep Linking / URL Routing**:
   - To strictly comply with R2 ("no disruptive rewrite to GoRouter"), imperative `Navigator` routing is preserved. Direct URL fragment switching in browser history is not included.

---

## 4. Conclusion & Implementation Plan

Milestone M1 navigation shell design is complete. The Worker agent should implement the following drop-in code and edits.

### File 1: Create `lib/admin_shell.dart`
Drop-in code path: `.agents/teamwork/explorer_m1_2/proposed_admin_shell.dart` (also quoted in full below).

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'all_players_page.dart';
import 'player_claims_page.dart';
import 'theme/app_colors.dart';
import 'theme/responsive_layout.dart';

/// Top-level navigation items supported by the Spike Dunk Admin Shell.
enum AdminNavDestination {
  tournaments(
    title: 'Turneringer',
    iconOutlined: Icons.emoji_events_outlined,
    iconFilled: Icons.emoji_events,
    index: 0,
  ),
  players(
    title: 'Spillerdatabase',
    iconOutlined: Icons.people_outline,
    iconFilled: Icons.people,
    index: 1,
  ),
  claims(
    title: 'Spillerkrav',
    iconOutlined: Icons.assignment_ind_outlined,
    iconFilled: Icons.assignment_ind,
    index: 2,
  );

  const AdminNavDestination({
    required this.title,
    required this.iconOutlined,
    required this.iconFilled,
    required this.index,
  });

  final String title;
  final IconData iconOutlined;
  final IconData iconFilled;
  final int index;
}

/// Unified adaptive shell for Spike Dunk Admin.
///
/// Provides:
/// - Desktop (width >= 1000px): Permanent left sidebar with branding, navigation items, and logout.
/// - Mobile / Tablet (width < 1000px): Clean pass-through to the active screen which renders
///   a standard AppBar with a hamburger menu opening [AdminDrawer].
/// - Zero disruption to detail navigation: detail pages pushed via [Navigator.push]
///   open over the shell with standard back button support.
class AdminShell extends StatefulWidget {
  /// The destination index to display initially (0 = Tournaments, 1 = Players, 2 = Claims).
  final int initialIndex;

  const AdminShell({
    super.key,
    this.initialIndex = 0,
  });

  /// Access the nearest [AdminShellState] to programmatically change tabs.
  static AdminShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AdminShellState>();

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  /// Sets the currently active top-level destination index.
  void setIndex(int index) {
    if (index >= 0 && index <= 2 && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  Widget _buildCurrentPage() {
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopOrLarger(context);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        body: Row(
          children: [
            // Permanent desktop navigation sidebar
            AdminSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == 3) {
                  // Logg ut
                  FirebaseAuth.instance.signOut();
                } else {
                  setIndex(index);
                }
              },
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0x1AFFFFFF),
            ),
            // Active page content
            Expanded(
              child: _buildCurrentPage(),
            ),
          ],
        ),
      );
    }

    // On mobile / tablet, render the active page directly.
    // The active page renders its own AppBar with hamburger icon opening AdminDrawer.
    return _buildCurrentPage();
  }
}

/// Permanent left sidebar navigation widget for desktop screens (width >= 1000px).
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.adminSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.adminOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.adminOrange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spike Dunk',
                        style: TextStyle(
                          color: AppColors.adminText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Kontrollpanel',
                        style: TextStyle(
                          color: AppColors.adminTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Color(0x1AFFFFFF),
              height: 1,
              thickness: 1,
            ),
          ),

          const SizedBox(height: 16),

          // ── Section Label ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              'MENY',
              style: TextStyle(
                color: AppColors.adminTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ── Navigation Destinations ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SidebarTile(
                  title: AdminNavDestination.tournaments.title,
                  icon: selectedIndex == 0
                      ? AdminNavDestination.tournaments.iconFilled
                      : AdminNavDestination.tournaments.iconOutlined,
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 4),
                _SidebarTile(
                  title: AdminNavDestination.players.title,
                  icon: selectedIndex == 1
                      ? AdminNavDestination.players.iconFilled
                      : AdminNavDestination.players.iconOutlined,
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 4),
                _SidebarTile(
                  title: AdminNavDestination.claims.title,
                  icon: selectedIndex == 2
                      ? AdminNavDestination.claims.iconFilled
                      : AdminNavDestination.claims.iconOutlined,
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Bottom Logout Action ──────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Color(0x1AFFFFFF),
              height: 1,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _SidebarTile(
              title: 'Logg ut',
              icon: Icons.logout,
              isDestructive: true,
              isSelected: false,
              onTap: () => onDestinationSelected(3),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Single interactive destination tile in the [AdminSidebar].
class _SidebarTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color itemColor;
    final Color bgColor;

    if (widget.isDestructive) {
      itemColor = _isHovered ? const Color(0xFFF87171) : const Color(0xFFEF4444);
      bgColor = _isHovered
          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
          : Colors.transparent;
    } else if (widget.isSelected) {
      itemColor = AppColors.adminOrange;
      bgColor = AppColors.adminOrange.withValues(alpha: 0.15);
    } else {
      itemColor = _isHovered ? AppColors.adminText : AppColors.adminTextSecondary;
      bgColor = _isHovered
          ? AppColors.adminSurfaceElevated
          : Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.adminOrange.withValues(alpha: 0.3),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: itemColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified mobile drawer widget used on screens with viewport width < 1000px.
class AdminDrawer extends StatelessWidget {
  /// The index of the active destination (0 = Tournaments, 1 = Players, 2 = Claims).
  final int selectedIndex;

  const AdminDrawer({
    super.key,
    required this.selectedIndex,
  });

  void _handleNavigation(BuildContext context, int destinationIndex) {
    Navigator.pop(context); // Close mobile drawer

    final shellState = AdminShell.of(context);
    if (shellState != null) {
      shellState.setIndex(destinationIndex);
    } else {
      // Fallback navigation when the page is rendered outside AdminShell
      if (destinationIndex == selectedIndex) return;
      switch (destinationIndex) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
          break;
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AllPlayersPage()),
          );
          break;
        case 2:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlayerClaimsPage()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.adminSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ───────────────────────────────────────────────
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.adminSurfaceElevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.adminOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Spike Dunk Admin',
                  style: TextStyle(
                    color: AppColors.adminText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Kontrollpanel',
                  style: TextStyle(
                    color: AppColors.adminTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Turneringer ───────────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 0
                  ? AdminNavDestination.tournaments.iconFilled
                  : AdminNavDestination.tournaments.iconOutlined,
              color: selectedIndex == 0
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.tournaments.title,
              style: TextStyle(
                color: selectedIndex == 0
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 0,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 0),
          ),

          // ── Spillerdatabase ───────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 1
                  ? AdminNavDestination.players.iconFilled
                  : AdminNavDestination.players.iconOutlined,
              color: selectedIndex == 1
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.players.title,
              style: TextStyle(
                color: selectedIndex == 1
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 1,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 1),
          ),

          // ── Spillerkrav ───────────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 2
                  ? AdminNavDestination.claims.iconFilled
                  : AdminNavDestination.claims.iconOutlined,
              color: selectedIndex == 2
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.claims.title,
              style: TextStyle(
                color: selectedIndex == 2
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 2
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 2,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 2),
          ),

          const Divider(color: Color(0x1AFFFFFF)),

          // ── Logg ut ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text(
              'Logg ut',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
```

---

### File 2: Minimal Edits to `lib/main.dart`

1. **Add Imports**:
   ```dart
   import 'admin_shell.dart';
   import 'theme/responsive_layout.dart';
   ```

2. **In `AuthGate.build` (line 64)**:
   ```dart
   // BEFORE:
   if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
     return const AdminDashboard();
   }

   // AFTER:
   if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
     return const AdminShell();
   }
   ```

3. **In `AdminDashboard.build` (lines 86-96)**:
   ```dart
   // BEFORE:
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: const Text("Admin Dashboard"),
         backgroundColor: Colors.blue[800],
         foregroundColor: AppColors.adminText,
       ),
       drawer: Drawer(
         ... 70 lines of inline drawer ...
       ),

   // AFTER:
   Widget build(BuildContext context) {
     final isDesktop = Responsive.isDesktopOrLarger(context);

     return Scaffold(
       appBar: AppBar(
         title: const Text("Admin Dashboard"),
         backgroundColor: Colors.blue[800],
         foregroundColor: AppColors.adminText,
         automaticallyImplyLeading: !isDesktop,
       ),
       drawer: isDesktop ? null : const AdminDrawer(selectedIndex: 0),
   ```

---

### File 3: Minimal Edits to `lib/all_players_page.dart`

1. **Add Imports**:
   ```dart
   import 'admin_shell.dart';
   import 'theme/responsive_layout.dart';
   ```

2. **In `_AllPlayersPageState.build` (lines 188-193 and 306-343)**:
   ```dart
   // BEFORE:
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: const Text("Spillerdatabase"),
         backgroundColor: AppColors.green,
         actions: [...],
       ),
       drawer: Drawer(
         ... 38 lines of duplicate drawer ...
       ),

   // AFTER:
   Widget build(BuildContext context) {
     final isDesktop = Responsive.isDesktopOrLarger(context);

     return Scaffold(
       appBar: AppBar(
         title: const Text("Spillerdatabase"),
         backgroundColor: AppColors.green,
         automaticallyImplyLeading: !isDesktop,
         actions: [...],
       ),
       drawer: isDesktop ? null : const AdminDrawer(selectedIndex: 1),
   ```

---

### File 4: Minimal Edits to `lib/player_claims_page.dart`

1. **Add Imports**:
   ```dart
   import 'admin_shell.dart';
   import 'theme/responsive_layout.dart';
   ```

2. **In `PlayerClaimsPage.build` (lines 61-66)**:
   ```dart
   // BEFORE:
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: const Text('Ventende Spillerkrav'),
         backgroundColor: AppColors.adminOrange,
       ),
       body: ...

   // AFTER:
   Widget build(BuildContext context) {
     final isDesktop = Responsive.isDesktopOrLarger(context);

     return Scaffold(
       appBar: AppBar(
         title: const Text('Ventende Spillerkrav'),
         backgroundColor: AppColors.adminOrange,
         automaticallyImplyLeading: !isDesktop,
       ),
       drawer: isDesktop ? null : const AdminDrawer(selectedIndex: 2),
       body: ...
   ```

---

## 5. Verification Method

### Automated Checks
1. **Static Analysis**:
   ```bash
   cd c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin
   flutter analyze
   ```
   **Expected**: 0 new errors, 0 new warnings across all touched files.

2. **Web Build Compilation**:
   ```bash
   flutter build web
   ```
   **Expected**: Build completes successfully.

### Manual / Viewport Responsive Layout Checks
1. **Desktop Resolution (`width = 1200px` or `1440px`)**:
   - Verify permanent left sidebar (`width: 260px`) is visible.
   - Brand header displays "Spike Dunk" logo and "Kontrollpanel".
   - Verify "Turneringer", "Spillerdatabase", "Spillerkrav" and "Logg ut" tiles exist.
   - Clicking between tiles switches the active view without reloading routes.
   - Verify active tile has orange highlight (`AppColors.adminOrange.withValues(alpha: 0.15)`).
   - Verify `AppBar` in the content pane has **no hamburger icon**.
   - Clicking "+ Ny Turnering" FAB pushes `AddTournamentPage` with standard back button.
   - Clicking "Administrer" on a tournament pushes `TournamentControlPage` with back button.
   - Clicking back arrow returns smoothly to `AdminShell` at the same selected tab.
2. **Mobile Resolution (`width = 390px`)**:
   - Verify left sidebar is **not visible**.
   - `AppBar` has standard hamburger menu icon.
   - Tapping hamburger menu opens `AdminDrawer`.
   - Tapping "Spillerdatabase" switches the view to `AllPlayersPage` and closes drawer.
   - Tapping "Logg ut" calls Firebase signOut and redirects to login screen.
3. **Ultrawide Resolution (`width = 2560px`)**:
   - Left sidebar remains anchored at 260px.
   - Content expands cleanly into remaining space without distortion.

### Invalidation Conditions
- If hamburger icon appears on desktop screens (width >= 1000px).
- If detail page back button fails to return to the active shell tab.
- If switching tabs causes `AuthGate` to reload or drops admin credentials.
