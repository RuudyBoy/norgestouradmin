## 2026-09-29T13:24:00Z
Formulate the concrete implementation design for Milestone M1's adaptive navigation shell (`lib/admin_shell.dart` or adaptive layout in `lib/main.dart`).
1. Read ORIGINAL_REQUEST.md and PROJECT.md.
2. Inspect `lib/main.dart`, `lib/all_players_page.dart`, and `lib/player_claims_page.dart` to understand how top-level navigation currently works (Drawers in `main.dart` and `all_players_page.dart`).
3. Design the unified `AdminShell`:
   - Desktop view (width >= 1000px): Permanent left sidebar / navigation rail showing brand header ("Spike Dunk Admin"), navigation items:
     1. Turneringer (icon: `Icons.emoji_events_outlined`) -> `AdminDashboard`
     2. Spillerdatabase (icon: `Icons.people_outline`) -> `AllPlayersPage`
     3. Spillerkrav (icon: `Icons.assignment_ind_outlined`) -> `PlayerClaimsPage`
     4. Logg ut (icon: `Icons.logout`) -> `FirebaseAuth.instance.signOut()`
   - Mobile view (width < 1000px): Standard `AppBar` with hamburger menu opening the `Drawer`, retaining full mobile drawer behavior.
   - Show how detail pages (like `TournamentControlPage`, `AddTournamentPage`, `MatchControlPage`) continue to be pushed with `Navigator.push`, ensuring zero breaking changes to routes or back buttons.
4. Provide the exact drop-in code for the Worker.
5. Write your comprehensive handoff report to:
   c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_2\handoff.md
When done, notify orchestrator_1 via send_message.
