# Marky

Marky is a native Markdown reader for macOS focused on fast local-folder browsing and clean reading. A portable C++20 core interprets Markdown and project rules; SwiftUI and AppKit provide the Mac interface.

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

The C++20 static library and its dependency-free tests live in [core/](core/README.md). CMake/CTest 3.21+ presets provide Debug and Release configurations for macOS with Apple Clang, Windows with MSVC, and Linux with GCC. Run these commands from the repository root on macOS.

```bash
cd core
cmake --preset macos-appleclang-debug
cmake --build --preset macos-appleclang-debug
ctest --preset macos-appleclang-debug
```

Repeat with `macos-appleclang-release`. See the [core procedures](core/README.md) for platform prerequisites, Windows/Linux commands, deliberate failure/recovery checks, and manual CMake 3.20+ builds. [T03.S2 evidence](docs/core-rewrite/T03-S2-PLATFORM-BUILDS.md) distinguishes executed Mac smoke tests from unexecuted Windows/Linux configurations.

The core's [C interface and lifetime rules](core/README.md#c-interface-and-lifetime) describe ownership, borrowed views, status values, and cancellation. The sanitizer and stress procedure is in the [core README](core/README.md#sanitizer-mutation-and-stress-checks).

## Architecture

Xcode links the core as a [local static Swift package](core/README.md#xcode-integration). The app calls it only through the C header `core/include/MarkyCore.h`.

| Layer | Owns | Source |
| --- | --- | --- |
| Portable core (C++20) | Block and inline Markdown semantics, reference resolution, link and image data, Markdown-file eligibility, empty-folder pruning, project index and filtering, favorite membership and reconciliation | `core/src/` |
| Swift adapters | Copying core results into `Sendable` Swift values, cancellation tokens, translating native scan metadata and saved favorites into core inputs | `Marky/Services/CoreMarkdownParser.swift`, `Marky/Services/CoreCancellationToken.swift`, `Marky/FileNode.swift`, `Marky/Services/ProjectFavoritesStore.swift` |
| Native Mac services | File reads and text decoding, folder enumeration, security-scoped bookmarks and grants, preferences and favorites persistence, localized search matching and ordering, image loading, bundled fonts | `Marky/FileNode.swift`, `Marky/Services/`, `Marky/ViewModels/ContentViewModel.swift` |
| Mac presentation | Attributed text, typography and theme tokens, tables, images and preview, sidebar, settings, windows, menus, keyboard, accessibility | `Marky/MarkdownViewer.swift`, `Marky/MarkdownContentBlocks.swift`, `Marky/MarkdownTypography.swift`, the other views in `Marky/` |

Documents load off the main actor. Settings changes rerender the cached core document without reparsing it. The core makes no filesystem calls, so a future Windows or Linux app would supply its own native scanning, access, persistence, and interface. No such app exists yet.

The Swift Markdown parser and string renderer that preceded the core were removed in 0.2.5. Their [removal inventory](docs/core-rewrite/T12-S2-PRODUCTION-CUTOVER.md#swift-parser-removal-inventory-for-t18) and [verification](docs/core-rewrite/STATUS.md#t18s1-mac-run) are in the roadmap.

## Repository Layout

- `core/`: C++20 static core, CTest harness, and local Swift package for Xcode
- `Marky/`: Mac app source (SwiftUI and AppKit views, core adapters, native services, theme)
- `MarkyTests/`: unit tests, including the shared Markdown fixture corpus in `MarkyTests/Fixtures/`
- `MarkyUITests/`: UI tests and opt-in large-input performance tests
- `tools/`: inline data generator and performance probes
- `docs/`: verification procedures, Markdown showcase, and the core rewrite roadmap
- `AGENTS.md`: repository policy for coding agents
- [C++ core rewrite roadmap](docs/core-rewrite/README.md): phased plan, approved contract, live progress, and session handoff.

## Notes

- This repository follows a solo workflow with versioned changelog entries (no `Unreleased` section).
- The Xcode project sets the current app version to `0.2.4` (`CURRENT_PROJECT_VERSION = 5`). The undated `0.2.5` changelog entry collects changes made since then; the project version has not been raised yet.
- Folder loading preserves the current project if another location cannot be read. Single-file access preserves favorites for other files in the same project.
- Detailed validation and manual acceptance steps are recorded in [the code-quality verification notes](docs/CODE_QUALITY_VERIFICATION.md).

## Credits

- Icon set generation support: [icns-creator](https://github.com/alptugan/icns-creator) by alptugan.
