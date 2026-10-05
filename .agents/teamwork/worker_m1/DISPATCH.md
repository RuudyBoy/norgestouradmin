## 2026-09-29T13:29:57Z
You are worker_m1.
Working directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\worker_m1
Original Request: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\ORIGINAL_REQUEST.md
Project Spec: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\orchestrator_1\PROJECT.md
Target Flutter App Directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin

Your assigned task: Implement Milestone M1: Responsive Framework & App Shell.

Reference Documents to read first:
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_1\handoff.md
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_1\proposed_responsive_layout.dart
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_1\proposed_responsive_layout_test.dart
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_2\handoff.md
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_2\proposed_admin_shell.dart
- c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_3\handoff.md

Your exclusive file write ownership:
1. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\theme\responsive_layout.dart` (new file)
2. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\test\responsive_layout_test.dart` (new file)
3. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\admin_shell.dart` (new file)
4. `c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin\lib\main.dart` (integrate AdminShell in AuthGate; adapt AdminDashboard scaffold/drawer)

STRICT BOUNDARIES (DO NOT TOUCH):
- `lib/simulator_logic.dart` (STRICTLY FROZEN)
- `lib/firebase_options.dart` (STRICTLY FROZEN)
- Do NOT alter, remove, or rename any Firebase auth logic, Firestore document references, queries, models, or core business rules.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implementation steps:
1. Write `norges_tour_admin/lib/theme/responsive_layout.dart` using the exact design from `proposed_responsive_layout.dart`.
2. Write `norges_tour_admin/test/responsive_layout_test.dart` using `proposed_responsive_layout_test.dart`.
3. Write `norges_tour_admin/lib/admin_shell.dart` using `proposed_admin_shell.dart`.
4. Update `norges_tour_admin/lib/main.dart`:
   - Import `admin_shell.dart` and `theme/responsive_layout.dart`.
   - In `AuthGate` (line 64), return `const AdminShell();` instead of `const AdminDashboard();`.
   - In `AdminDashboard`, set `automaticallyImplyLeading: !Responsive.isDesktopOrLarger(context)`, and `drawer: Responsive.isDesktopOrLarger(context) ? null : const AdminDrawer()`.
5. Run the required verification commands in `norges_tour_admin`:
   - `flutter test test/responsive_layout_test.dart`
   - `flutter analyze lib/theme/responsive_layout.dart lib/admin_shell.dart lib/main.dart` and `flutter analyze`
   - `flutter build web`
6. Document all commands, outputs, git diff statistics, and layout behavior across viewports in:
   `c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\worker_m1\handoff.md`.
7. Send a message to orchestrator_1 when complete.
