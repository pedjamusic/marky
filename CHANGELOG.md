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
- Refined viewer visuals by removing top-line masking edge fade.
