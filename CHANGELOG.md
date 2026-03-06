# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] - 2026-03-06

- Introduced a native SwiftUI markdown reader experience with local file/folder importing and split-view navigation.
- Added persistent project restore using bookmark data, including security-scoped access handling.
- Implemented markdown rendering improvements for typography and inline styles (headings, lists, checkboxes, quotes, links, bold, inline code).
- Updated sidebar UX by restoring open-sidebar behavior and widening split-view column sizing.
- Added a theme-driven, subtle static sidebar gradient overlay that adapts to Light and Dark appearance.
- Updated sidebar icons to use neutral system styling instead of accent coloring.
- Made sidebar rows full-width tappable while keeping native list interaction feel.
- Updated active-file sidebar styling to theme blue + bold using native text rendering to avoid glyph squish.
- Refactored project/session and sidebar/file-import state handling from `ContentView` into a dedicated ViewModel + service layer.
- Added deterministic UI tests for sidebar key flows (seeded open state, search/filter, file selection, collapse action state change).
- Replaced bookmark/session silent failures with typed error handling and user-safe messages, with new unit tests for failure mapping.
- Deduplicated file/folder import-open handling by routing panel and fileImporter paths through shared ViewModel import handlers.
- Tokenized sidebar search/collapse control layout and visuals (spacing, paddings, radius, icon/tint, and material) via `MarkyTheme` to remove hardcoded UI constants.
- Updated sidebar folder interaction so clicking a folder row toggles expand/collapse (not only the disclosure icon), with collapse-all wired to explicit expansion state.
- Refined viewer visuals by removing top-line masking edge fade.
