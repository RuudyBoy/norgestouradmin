## 2026-09-29T13:43:35Z
You are explorer_m1_it2_1.
Working directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_1
Original Request: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\ORIGINAL_REQUEST.md
Target Flutter App Directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin

Context: Milestone M1 Gate 1 failed on feedback from reviewer_m1_2:
AdminShell._buildCurrentPage() in `lib/admin_shell.dart` uses `switch (_selectedIndex)` which instantiates a brand new widget every time the user switches tabs, destroying scroll positions, form inputs, and causing Firestore streams to re-subscribe.

Your assigned task:
1. Inspect `lib/admin_shell.dart`.
2. Formulate the exact implementation change using `IndexedStack` in `AdminShell` so that `AdminDashboard()`, `AllPlayersPage()`, and `PlayerClaimsPage()` maintain their state across tab switching.
3. Check lazy loading vs eager initialization: ensure no runtime crashes or issues occur if screens initialize in `IndexedStack`.
4. Provide the exact drop-in code snippet for `lib/admin_shell.dart` for the Worker.
5. Write your handoff report to:
   c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_1\handoff.md
When done, notify orchestrator_1 via send_message.
