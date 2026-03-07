# Changelog

All notable changes to this project are documented in this file.

## [0.2.0] - 2026-03-07

- Completed the first markdown typography system pass with three reader modes: All System, Serif Headings + System Body, and System Headings + Serif Body.
- Added three subtle reader text-size presets (Slightly Smaller, Default, Slightly Bigger) that scale the markdown typography token system consistently across headings, body copy, lists, quotes, and code blocks.
- Moved markdown typography decisions into explicit token-driven configuration via dedicated typography/content block modules instead of keeping style constants in the viewer.
- Improved markdown reading rhythm with restrained heading scale, clearer paragraph spacing, shared body/list leading, tighter list alignment, and safer left-rail marker layout.
- Restored fenced code block rendering as dedicated literal-content blocks with monospaced styling, padding, radius, and horizontal scrolling without line wrapping.
- Added stable markdown block parsing/rendering primitives for prose, lists, quotes, and code blocks while preserving the previously validated SwiftUI viewer behavior.
- Added and updated typography-focused renderer tests covering modes, heading scale, list handling, and fenced code block splitting.

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
- Added initial branding asset integration: custom app icon set generated from provided PNG, mascot image asset, and Fraunces-based “Marky” launch wordmark.
- Refined viewer visuals by removing top-line masking edge fade.
- Increased launch mascot size and set high-quality interpolation to reduce gritty edges and preserve glasses detail.
- Added icon tooling credit for `icns-creator` (alptugan) in project documentation.
- Added a tokenized markdown typography mode system with three combinations: all-system, serif-headings/system-body, and system-headings/serif-body.
- Updated markdown hierarchy/rhythm defaults (line length handling, heading scale/spacing, list/quote rhythm) and moved key style constants into explicit typography tokens.
- Added fenced code block rendering with literal-content protection and monospaced block styling.
- Added App Settings support for markdown typography mode and global appearance mode (System/Light/Dark), available via `Cmd+,`.
- Fixed appearance switching edge cases for immediate System reversion and reduced mode-switch flicker by rerendering from cached markdown text.
- Stabilized inline/code-block highlight background colors across appearance switches with explicit light/dark tokens.
- Added bundled Literata font resources and startup registration for all `.ttf` files under `Marky/Resources/Fonts`, enabling serif reader modes to use app-shipped fonts.
