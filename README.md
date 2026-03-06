# Marky

Marky is a native SwiftUI Markdown reader for macOS focused on fast local-folder browsing and clean reading.

## Current Highlights

- Open a single Markdown file or an entire folder from disk.
- Sidebar tree navigation with search and folder/file icons.
- Sidebar rows behave as full-width tappable blocks for easier file selection.
- Folder rows in the sidebar toggle expand/collapse when clicked (not only via disclosure icon).
- Active file is highlighted in theme blue with bold text while preserving native macOS text rendering.
- Branding assets are now integrated: custom app icon, mascot artwork, and Fraunces wordmark font for the launch title.
- Auto-restore of the last opened project via bookmark persistence.
- Security-scoped file access handling for sandbox-safe reads.
- Reader-first markdown rendering with tuned typography for headings, lists, checkboxes, quotes, links, bold, and inline code.
- Reader typography system now supports three markdown modes: All System, Serif Headings + System Body, and System Headings + Serif Body.
- Bundled Literata reader font files are now loaded from app resources for serif markdown modes.
- Fenced code blocks now render as literal monospaced blocks with markdown-safe styling.
- App Settings (`Cmd+,`) now includes appearance (System/Light/Dark) and markdown typography controls.
- Theme-driven sidebar gradient overlay that adapts to Light and Dark appearance.
- Theme-tokenized sidebar search/collapse controls for spacing and visual consistency.
- MVVM-oriented app state flow for the main screen (`ContentViewModel`) with a dedicated bookmark/session service layer.
- Typed project-session error handling for bookmark save/restore flows with user-safe UI messaging.
- Unified import/open routing in the ViewModel to keep panel and file-importer behavior consistent.

## Requirements

- macOS (Xcode destination currently targets modern macOS SDKs)
- Xcode 17+

## Run

1. Open `Marky.xcodeproj` in Xcode.
2. Select the `Marky` scheme.
3. Run the app (`Cmd+R`).

CLI build:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' build
```

CLI UI tests (example focused run):

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' test -only-testing:MarkyUITests/MarkyUITests/testSidebarSeedSearchAndSelectFlow -only-testing:MarkyUITests/MarkyUITests/testCollapseButtonUpdatesStateToken
```

## Repository Layout

- `Marky/`: app source code (SwiftUI app, views, theme, markdown rendering)
- `MarkyTests/`: unit tests
- `MarkyUITests/`: UI tests
- `AGENTS.md`: repository policy for coding agents

## Notes

- This repository follows a solo workflow with versioned changelog entries (no `Unreleased` section).

## Credits

- Icon set generation support: [icns-creator](https://github.com/alptugan/icns-creator) by alptugan.
