# Original User Request

## 2026-09-29T13:14:28Z

# Teamwork Project Prompt

Refactor the Flutter admin web app's UI to be optimized primarily for desktop/PC usage while maintaining mobile responsiveness, without altering any content or underlying functionality.

Working directory: c:/Users/mygge/Documents/GitHub/norgestouradmin/norges_tour_admin
Integrity mode: development

## Requirements

### R1. Desktop-Optimized Layouts
Implement responsive design patterns (e.g., `LayoutBuilder`, `MediaQuery`, `Wrap`, `SliverGrid`) to optimize the UI for PC monitors. Use `Center` and `ConstrainedBox` to prevent infinite stretching on ultrawide monitors. Where appropriate, convert horizontal scrolling lists to grids or wrapped layouts, and arrange form fields in multiple columns when screen width permits. You may introduce standard desktop navigation patterns (like a permanent side menu) if it fits the screen, provided it doesn't break existing routes.

### R2. Strict Preservation of Functionality
Do not alter, remove, or rename any core logic, database interactions (Firebase), state management, or models. The refactoring must be strictly limited to the presentation layer (Widgets, layout structures, padding, and constraints).

## Acceptance Criteria

### Automated Verification
- [ ] The command `flutter analyze` must pass with no new errors or warnings in the modified files.
- [ ] The command `flutter build web` must complete successfully, confirming the app still compiles.

### UI Layout Integrity (Agent-as-judge)
- [ ] **Desktop View**: An independent agent judge verifies that at desktop resolutions (e.g., width > 1000px), the content utilizes the horizontal space efficiently (e.g., via grids or columns) rather than stretching a single mobile column across the screen.
- [ ] **Mobile View**: An independent agent judge verifies that at mobile resolutions (e.g., width < 600px), the layout gracefully collapses back to single columns without causing horizontal overflow (`RenderFlex` errors).
