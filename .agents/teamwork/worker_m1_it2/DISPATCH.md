## 2026-09-29T13:48:36Z
You are worker_m1_it2.
Working directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\worker_m1_it2
Original Request: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\ORIGINAL_REQUEST.md
Project Spec: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\orchestrator_1\PROJECT.md
Target Flutter App Directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin

Your assigned task: Implement Milestone M1 Iteration 2 Remediation.

Reference Documents to read first:
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_1\handoff.md
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_2\handoff.md
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_3\handoff.md

Your exclusive file write ownership:
1. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\admin_shell.dart`
2. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\player_claims_page.dart`
3. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\all_players_page.dart`
4. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\test\responsive_layout_test.dart`

STRICT BOUNDARIES (DO NOT TOUCH):
- `lib/simulator_logic.dart` (STRICTLY FROZEN)
- `lib/firebase_options.dart` (STRICTLY FROZEN)
- Do NOT alter, remove, or rename any Firebase auth logic, Firestore document references, queries, models, or core business rules.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implementation steps:
1. In `lib/admin_shell.dart`:
   - Fix `AdminNavDestination` enum: remove explicit `final int index;` so built-in `Enum.index` is used without collision (per explorer_m1_it2_1).
   - Implement lazy-loaded `IndexedStack` (using `Set<int> _loadedIndices`) in `AdminShell` (per explorer_m1_it2_1) to preserve page states, scroll positions, and streams across tab switching.
2. In `lib/player_claims_page.dart`:
   - Import `admin_shell.dart` and `theme/responsive_layout.dart`.
   - Update Scaffold:
     - `automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context)`
     - `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(selectedIndex: 2)`
3. In `lib/all_players_page.dart`:
   - Import `admin_shell.dart` and `theme/responsive_layout.dart`.
   - Update Scaffold:
     - `automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context)`
     - Replace legacy custom green Drawer with: `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer(selectedIndex: 1)`
4. In `test/responsive_layout_test.dart`:
   - Add the test cases from `explorer_m1_it2_3` verifying `IndexedStack` state preservation and mobile drawer navigation without user traps.
5. Run the required verification commands in `norges_tour_admin`:
   - `flutter test test/responsive_layout_test.dart`
   - `flutter analyze lib/admin_shell.dart lib/player_claims_page.dart lib/all_players_page.dart test/responsive_layout_test.dart`
   - `flutter build web`
6. Document all commands, outputs, git diff statistics, and layout behavior across viewports in:
   `c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\worker_m1_it2\handoff.md`.
7. Send a message to orchestrator_1 when complete.
