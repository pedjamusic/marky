# Marky

Marky is a native SwiftUI Markdown reader for macOS focused on fast local-folder browsing and clean reading.

## Current Highlights

- Open a single Markdown file or an entire folder from disk.
- Sidebar tree navigation with search and folder/file icons.
- Project-scoped Favorites section in the sidebar, with native star emoji for active favorites and one-click starring for frequently visited markdown files.
- Sidebar rows behave as full-width tappable blocks for easier file selection.
- Folder rows in the sidebar toggle expand/collapse when clicked (not only via disclosure icon).
- Active file is highlighted in theme blue with bold text while preserving native macOS text rendering.
- Branding assets are now integrated: custom app icon, mascot artwork, and Fraunces wordmark font for the launch title.
- Auto-restore of the last opened project via bookmark persistence.
- Security-scoped file access handling for sandbox-safe reads.
- Reader-first markdown rendering with tuned typography for headings (ATX & Setext), lists, task checkboxes, blockquotes, links, autolinks, bold, italic, strikethrough, and literal inline code.
- GitHub-style Markdown tables with per-column alignment (:---, :---:, ---:), escaped pipe handling, inline formatted cells, theme-tokenized borders and fills, and horizontal scrolling for narrow window widths.
- Expanded CommonMark and GFM styling: single/double/triple emphasis (`*` and `_`), intra-word underscore safety (`foo_bar_baz`), strikethrough (`~~`), backslash escapes, autolinks (`<url>`), thematic breaks (`---`, `***`, `___`), multi-line list continuations, and native image presentation.
- Reader typography system now supports three markdown modes: All System, Serif Headings + System Body, and System Headings + Serif Body.
- Markdown list markers now align to the reader rail and fenced code blocks render as dedicated scrollable code surfaces.
- Reader content now eases into view with subtle top and bottom edge fades while preserving the native titlebar/title behavior.
- Bundled Literata reader font files are now loaded from app resources for serif markdown modes.
- Fenced code blocks now render as literal monospaced blocks with markdown-safe styling.
- App Settings (`Cmd+,`) now includes appearance (System/Light/Dark) and markdown typography controls.
- Theme-driven sidebar gradient overlay that adapts to Light and Dark appearance.
- Theme-tokenized sidebar search/collapse controls for spacing and visual consistency.
- MVVM-oriented app state flow for the main screen (`ContentViewModel`) with a dedicated bookmark/session service layer.
- Typed project-session error handling for bookmark save/restore flows with user-safe UI messaging.
- Unified import/open routing in the ViewModel to keep panel and file-importer behavior consistent.
- Removed unused startup persistence scaffolding and tightened markdown/sidebar runtime paths to reduce wasted work during launch, search, file switching, and reader setting changes.
- Project targets now build with Swift 6 strict concurrency enabled to keep shared-state behavior explicit and safer as the app grows.

## Requirements

- macOS 26.2 or later.
- Xcode 27.2 with Swift 6 support (the verified toolchain).

## Run

1. Open `Marky.xcodeproj` in Xcode.
2. Select the `Marky` scheme.
3. Run the app (`Cmd+R`).

CLI build:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' build
```

CLI unit tests:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' test -only-testing:MarkyTests
```

CLI UI tests (example focused run):

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' test -only-testing:MarkyUITests/MarkyUITests
```

## Standalone C++ core build

The independent C++20 static-library scaffold and dependency-free CTest harness live in [core/](core/README.md). The Mac app continues to use its existing Swift implementation. From the repository root:

```bash
cmake -S core -B /tmp/MarkyCore-Debug -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/MarkyCore-Debug
ctest --test-dir /tmp/MarkyCore-Debug --output-on-failure --no-tests=error
```

Repeat with a separate Release build directory and `-DCMAKE_BUILD_TYPE=Release`. See the core README for prerequisites and deliberate harness failure checks; [T03.S1 evidence](docs/core-rewrite/T03-S1-CORE-BUILD.md) records executed configurations and limits.

## Repository Layout

- `core/`: standalone C++20 static core and CTest harness (not yet integrated into the app)
- `Marky/`: app source code (SwiftUI app, views, theme, markdown rendering)
- `MarkyTests/`: unit tests
- `MarkyUITests/`: UI tests
- `AGENTS.md`: repository policy for coding agents
- [C++ core rewrite roadmap](docs/core-rewrite/README.md): phased plan, approved contract, live progress, and session handoff.

## Notes

- This repository follows a solo workflow with versioned changelog entries (no `Unreleased` section).
- Current app version: `0.2.3` (`CURRENT_PROJECT_VERSION = 4`).
- Folder loading preserves the current project if another location cannot be read. Single-file access preserves favorites for other files in the same project.
- Detailed validation and manual acceptance steps are recorded in [the code-quality verification notes](docs/CODE_QUALITY_VERIFICATION.md).

## Credits

- Icon set generation support: [icns-creator](https://github.com/alptugan/icns-creator) by alptugan.
