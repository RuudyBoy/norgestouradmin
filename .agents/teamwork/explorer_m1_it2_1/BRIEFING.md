# BRIEFING — 2026-09-29T13:47:35Z

## Mission
Investigate `lib/admin_shell.dart` and design the exact `IndexedStack` solution to preserve navigation state across tabs.

## 🔒 My Identity
- Archetype: explorer
- Roles: explorer, investigator, synthesist
- Working directory: c:\Users\mygge\Documents\GitHub\norgestouradmin\.agents\teamwork\explorer_m1_it2_1
- Original parent: 9d9d876f-c592-48a3-9249-10e10a358357
- Milestone: M1 Iteration 2

## 🔒 Key Constraints
- Read-only investigation — do NOT implement directly in source code
- Formulate exact IndexedStack implementation in `AdminShell`
- Evaluate eager vs lazy initialization impact on Firestore streams / controllers
- Provide exact drop-in code snippet for Worker in handoff.md

## Current Parent
- Conversation ID: 9d9d876f-c592-48a3-9249-10e10a358357
- Updated: 2026-09-29T13:47:35Z

## Investigation State
- **Explored paths**: `lib/admin_shell.dart`, `lib/main.dart`, `lib/all_players_page.dart`, `lib/player_claims_page.dart`, `lib/admin_dashboard_overview.dart`, `test/responsive_layout_test.dart`, `test/adversarial_breakpoints_challenge_test.dart`.
- **Key findings**:
  1. `lib/admin_shell.dart:40:13` had a fatal Dart compile error: `An enum can't declare a non-abstract member named 'index'`. Enums in Dart already provide `int get index` natively.
  2. `AdminShell._buildCurrentPage()` used `switch (_selectedIndex)` which re-instantiated widgets on every tab switch, destroying scroll positions, text inputs, and recreating Firestore listeners.
  3. All three destination screens (`AdminDashboard`, `AllPlayersPage`, `PlayerClaimsPage`) are safe for `IndexedStack`. None throw errors or depend on transient route arguments.
  4. Formulated recommended Lazy-loaded `IndexedStack` (using `Set<int> _loadedIndices`) and Eager `IndexedStack` variations. Lazy loading avoids fetching the entire player collection on initial dashboard load while permanently preserving state once visited.
- **Unexplored areas**: None.

## Key Decisions Made
- Recommend lazy-loaded `IndexedStack` using `_loadedIndices` to prevent unnecessary Firestore reads on initial launch, while maintaining 100% state persistence across all subsequent tab switches.
- Document the `AdminNavDestination` enum compilation fix required for `flutter test` to compile.

## Artifact Index
- handoff.md — Complete 5-component handoff report for Worker and Orchestrator.
