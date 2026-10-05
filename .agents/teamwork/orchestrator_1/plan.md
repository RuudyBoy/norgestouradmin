# Project Execution Plan

## Objective
Refactor the Flutter admin web app's UI (`c:\Users\mygge\Documents\GitHub\norgestouradmin\norges_tour_admin`) to optimize for desktop/PC monitors while retaining mobile responsiveness, without altering any business logic, data models, or Firebase interactions.

## Phase 0: Survey & Discovery
1. Spawn 3 Explorers in parallel to investigate the Flutter app codebase:
   - Explorer 1: App structure, navigation/routing, entry points, layout wrapper / scaffold, theme / responsive utilities.
   - Explorer 2: Screens / pages inventory (admin dashboard, list views, detail views, forms, dialogs), current layouts, and UI issues on desktop vs mobile.
   - Explorer 3: Baseline verification setup (`flutter analyze`, `flutter build web`, existing tests if any), dependencies, and constraints.
2. Synthesize reports into `PROJECT.md` with full Feature/Screen Inventory.

## Phase 1: Decomposition & Milestone Planning
1. Decompose UI refactoring into logical milestones (e.g. Shared Shell & Responsive Framework, Main Screens, Detail/Form Views).
2. Establish explicit interface contracts and layout guidelines (`PROJECT.md`).

## Phase 2: Milestone Iteration & Execution
For each milestone:
1. Dispatch Explorer(s) to formulate concrete widget refactoring plan.
2. Dispatch Worker to implement changes, run `flutter analyze` and `flutter build web`.
3. Dispatch Reviewers to evaluate code quality, layout patterns, and responsiveness.
4. Dispatch Challengers to test edge resolutions (ultrawide > 1800px, standard desktop 1200px, tablet 768px, mobile < 600px).
5. Dispatch Forensic Auditor to verify integrity (no core logic / Firebase / model changes, genuine responsive implementations).
6. Gate evaluation.

## Phase 3: Final Verification & Hardening
1. Complete automated verification: `flutter analyze` and `flutter build web`.
2. Independent UI Layout Integrity review across resolutions.
3. Final report to Sentinel.
