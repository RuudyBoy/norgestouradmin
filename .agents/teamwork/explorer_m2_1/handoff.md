# Handoff Report: AdminDashboard Responsive Redesign (Milestone 2)

**Author**: `explorer_m2_1`  
**Date**: 2026-09-29  
**Recipient**: `orchestrator_1` (Conversation ID: `9d9d876f-c592-48a3-9249-10e10a358357`)  
**Status**: Hard Handoff (Investigation & Specification Complete)

---

## 1. Observation

### Current Implementation & Code Locations
1. **Target File**: `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\main.dart`
   - `AdminDashboard` widget: lines 82–347.
   - Firestore StreamBuilder: lines 113–118:
     ```dart
     stream: FirebaseFirestore.instance
         .collection('tournaments')
         .orderBy('created_at', descending: true)
         .snapshots(),
     ```
   - Layout structure (lines 145–155):
     ```dart
     return Column(
       children: [
         const AdminDashboardOverview(),
         Expanded(
           child: ListView.builder(
             padding: const EdgeInsets.all(20),
             itemCount: docs.length,
             itemBuilder: (context, index) { ... },
           ),
         ),
       ],
     );
     ```
   - Tournament card layout (lines 165–337):
     A single vertical `Card` wrapping `ListTile` and a bottom action `Row` with `ElevatedButton("Administrer")` and `IconButton(Icons.delete)`.

2. **Responsive Tokens & Container Source**:
   - `lib/theme/responsive_layout.dart`:
     - Breakpoints: `mobileBreakpoint = 600.0`, `tabletBreakpoint = 1000.0`, `ultrawideBreakpoint = 1800.0` (lines 27–33).
     - Dashboard Max-Width: `dashboardMaxContentWidth = 1600.0` (line 46).
     - `ResponsiveContainer.dashboard` constructor (lines 359–369): wraps child in `Align(alignment: Alignment.topCenter)` and `ConstrainedBox(maxWidth: 1600)` with responsive padding (16px mobile, 24px tablet, 32px desktop).

3. **Behavioral Defects on PC & Ultrawide Displays**:
   - When rendered on desktop viewports (`width >= 1000px`, e.g. 1920×1080), the `AdminShell` dedicates 260px to `AdminSidebar`. The remaining 1659px is assigned to `AdminDashboard`.
   - `ListView.builder` forces every tournament card to stretch the entire 1659px (or 2300px+ on ultrawide).
   - In each card, the `CircleAvatar` and tournament title are anchored at the extreme left (x=20), while the "Administrer" button and delete icon are pushed to the extreme right (x=1639), leaving ~1500px of blank whitespace between them.
   - Only 3–4 tournaments are visible simultaneously on a 1080p desktop monitor despite ample horizontal real estate.
   - On ultrawide displays (`width >= 1800px`), there is no max-width containment on `AdminDashboard`, violating project constraint R1.

---

## 2. Logic Chain

1. **Premise 1 (Stretching Elimination)**: Observation 3 establishes that single-column `ListView.builder` causes severe card distortion on screens wider than 1000px. Wrapping the layout in a responsive multi-column `GridView.builder` replaces the stretched cards with standard PC dashboard cards (~400–480px wide).
2. **Premise 2 (Breakpoint-Tailored Layouts)**:
   - On mobile (`< 600px`): Single-column `ListView.builder` preserves vertical touch scrolling and allows intrinsic card height without risking fixed-aspect-ratio clipping.
   - On tablet (`600px <= width < 1000px`): 2-column grid (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2)`) efficiently utilizes the 600–1000px width.
   - On desktop (`>= 1000px`): `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 480)` provides 2 columns at 1000–1280px (with 260px sidebar) and 3 columns at 1440–1600px.
3. **Premise 3 (RenderFlex Immunity via `mainAxisExtent`)**: In Flutter grids, `childAspectRatio` dynamically alters item height when item width varies, which causes bottom `RenderFlex` overflow when card width narrows. Pairing `childAspectRatio: 2.8` with `mainAxisExtent: 156.0` locks the card height to an exact 156px regardless of column width, providing 36px+ headroom above the card's 120px intrinsic height.
4. **Premise 4 (Ultrawide Containment)**: Wrapping the dashboard column in `ResponsiveContainer.dashboard(maxWidth: 1600)` centers the entire dashboard and restricts the content width to 1600px on displays >= 1800px (e.g. 2560px or 3440px), satisfying Requirement R1 and Milestone 2 Feature 5.
5. **Premise 5 (R2 Strict Preservation)**:
   - The query `FirebaseFirestore.instance.collection('tournaments').orderBy('created_at', descending: true).snapshots()` is unmodified.
   - The snapshot extraction (`data['name']`, `data['location']`, `data['start_date']`, `data['end_date']`, `data['image_url']`) is unmodified.
   - The navigation routes (`Navigator.push` to `TournamentControlPage` and `AddTournamentPage`) are unmodified.
   - The delete confirmation `AlertDialog` and Firestore `delete()` operation with SnackBar error handling are unmodified.

---

## 3. Caveats

1. **`AdminDashboardOverview` Scope**: `AdminDashboardOverview` is rendered as the top child inside `AdminDashboard`. While our containment container (`ResponsiveContainer.dashboard`) constrains its maximum width to 1600px, the internal stat cards inside `lib/admin_dashboard_overview.dart` currently use a horizontal scroll list. Refactoring those stat cards into a responsive `Row`/`Wrap` layout belongs to Milestone 2 Feature 4 and should be addressed in that file.
2. **Firebase Auth in Standalone Unit Tests**: `AdminDashboard` directly accesses `FirebaseFirestore.instance` in its `StreamBuilder`. Standalone widget tests must either mock Firestore streams or test the extracted presentation components (`_buildTournamentGrid`, `_TournamentCard`, and `ResponsiveContainer.dashboard`) with mock data.
3. **Card Margin in Grid vs List**: `Card` margins must be `EdgeInsets.zero` when inside `GridView` (because `crossAxisSpacing: 16` and `mainAxisSpacing: 16` manage spacing), and `EdgeInsets.only(bottom: 12)` when inside `ListView` on mobile. The extracted `_TournamentCard` encapsulates this via `isGrid`.

---

## 4. Conclusion & Proposed Implementation

### Summary of Changes in `lib/main.dart`
1. Body of `AdminDashboard` is wrapped in `ResponsiveContainer.dashboard(maxWidth: ResponsiveLayout.dashboardMaxContentWidth)` to center and bound ultrawide monitors.
2. The tournament list in `Expanded` is replaced with `_buildTournamentGrid(context, docs)`:
   - Mobile (`width < 600px`): `ListView.builder` (single column).
   - Tablet (`600px <= width < 1000px`): `GridView.builder` (2 columns, `crossAxisCount: 2`, `mainAxisExtent: 156`).
   - Desktop & Ultrawide (`width >= 1000px`): `GridView.builder` (`maxCrossAxisExtent: 480`, `childAspectRatio: 2.8`, `mainAxisExtent: 156`).
3. Extracted `_TournamentCard` private widget with `InkWell` tap handler for card-level navigation while preserving the explicit "Administrer" and "Slett" buttons and dialogs verbatim.
4. Strict R2 compliance: 0 changes to database queries, fields, auth flows, or navigation destinations.

### Drop-In Replacement Code for `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // brukes i AdminDashboard
import 'firebase_options.dart';
import 'add_tournament_page.dart';
import 'tournament_control_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'admin_dashboard_overview.dart'; // Importerer oversiktsmodulen
import 'admin_shell.dart';
import 'theme/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike Dunk Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin,
      builder: (context, child) {
        return Container(color: AppColors.adminBg, child: child);
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admins')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                return const AdminShell();
              }
              // Signed in but not an admin — sign out and show login.
              // signOut() trigger authStateChanges → rebuild, så den må
              // utsettes til etter build-fasen.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });
              return const AdminLoginPage();
            },
          );
        }
        return const AdminLoginPage();
      },
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.blue[800],
        foregroundColor: AppColors.adminText,
        automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context),
      ),

      // --- SIDEMENY (DRAWER) ---
      drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(),

      // --- FLYTENDE KNAPP FOR Å LAGE NY TURNERING ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTournamentPage()),
          );
        },
        label: const Text("Ny Turnering"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue[800],
        foregroundColor: AppColors.adminText,
      ),

      // --- LISTE / GRID OVER TURNERINGER ---
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .orderBy('created_at', descending: true) // Nyeste øverst
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: AppColors.adminTextSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Ingen turneringer enda. Trykk på knappen for å lage en!",
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Responsive containment: maks 1600px bredde for å hindre utstrekking på ultrawide
          return ResponsiveContainer.dashboard(
            maxWidth: ResponsiveLayout.dashboardMaxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard-oversikt (Statistikk for turneringer)
                const AdminDashboardOverview(),

                // Responsiv visning av turneringer (1 kolonne på mobil, 2 på nettbrett, grid på desktop)
                Expanded(
                  child: _buildTournamentGrid(context, docs),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTournamentGrid(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) {
    if (Responsive.isMobile(context)) {
      // Mobil (< 600px): enkel-kolonne liste
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>;
          final id = docs[index].id;
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: false,
          );
        },
      );
    } else if (Responsive.isTablet(context)) {
      // Nettbrett (600 - 1000px): 2 kolonner
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.6,
          mainAxisExtent: 156,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>;
          final id = docs[index].id;
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: true,
          );
        },
      );
    } else {
      // Desktop (>= 1000px) & Ultrawide: responsiv grid med maxCrossAxisExtent (480px)
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.8,
          mainAxisExtent: 156,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>;
          final id = docs[index].id;
          return _TournamentCard(
            id: id,
            data: data,
            isGrid: true,
          );
        },
      );
    }
  }
}

class _TournamentCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool isGrid;

  const _TournamentCard({
    required this.id,
    required this.data,
    required this.isGrid,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Ukjent';
    final location = data['location'] ?? 'Ukjent sted';
    final start = data['start_date'] ?? '?';
    final end = data['end_date'] ?? '?';
    final imageUrl = data['image_url'] ?? '';

    return Card(
      elevation: 2,
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TournamentControlPage(
                tournamentId: id,
                tournamentName: name,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[100],
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.emoji_events,
                        color: Colors.blue,
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.map,
                        size: 15,
                        color: AppColors.adminTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.adminTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "$start - $end",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: 12,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentControlPage(
                            tournamentId: id,
                            tournamentName: name,
                          ),
                        ),
                      );
                    },
                    child: const Text("Administrer"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    tooltip: 'Slett turnering',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Slett turnering"),
                          content: Text(
                            "Er du sikker på at du vil slette '$name'?\n\nDette kan ikke angres!",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Avbryt"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: AppColors.adminText,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Slett"),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('tournaments')
                              .doc(id)
                              .delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Turnering '$name' slettet.",
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Feil ved sletting: $e",
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. Verification Method

### Automated Checks
Run the following commands in `norges_tour_admin`:

1. **Static Analysis**:
   ```powershell
   flutter analyze
   ```
   **Verification Criteria**: Passes with 0 issues in `lib/main.dart` (pre-existing issues in unrefactored files are unchanged).

2. **Automated Test Suite**:
   ```powershell
   flutter test
   ```
   **Verification Criteria**: All 62 tests pass with 0 failures.

### Multi-Resolution Widget Layout Verification Recipe
Create a widget test (e.g. `test/admin_dashboard_responsive_test.dart`) verifying:
1. **Mobile Viewport (390×844)**:
   - Pump test widget with mock data at `Size(390, 844)`.
   - Assert `find.byType(ListView)` is present and `find.byType(GridView)` is not present.
   - Assert `find.byType(_TournamentCard)` items have single column layout without horizontal overflow.
2. **Tablet Viewport (820×1180)**:
   - Pump test widget at `Size(820, 1180)`.
   - Assert `find.byType(GridView)` is present.
   - Inspect `GridView`'s `gridDelegate`: assert `crossAxisCount == 2`.
3. **Desktop Viewport (1440×900)**:
   - Pump test widget at `Size(1440, 900)`.
   - Assert `find.byType(GridView)` is present.
   - Inspect `GridView`'s `gridDelegate`: assert `gridDelegate is SliverGridDelegateWithMaxCrossAxisExtent` and `maxCrossAxisExtent <= 500`.
4. **Ultrawide Viewport (2560×1440)**:
   - Pump test widget at `Size(2560, 1440)`.
   - Find `ResponsiveContainer.dashboard` and verify its descendant `ConstrainedBox` has `constraints.maxWidth == 1600.0`.
5. **R2 Functional Integrity**:
   - Tap "Administrer" button -> verify `NavigatorObserver` captures push to `TournamentControlPage`.
   - Tap "Slett" button -> verify `AlertDialog` with title "Slett turnering" opens.
