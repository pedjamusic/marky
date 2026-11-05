# Code-quality verification

Date: 2026-11-05

Candidate: 0.2.2 (3), branch `codex/code-quality-bugfixes`.

## Automated verification

Implementation was reviewed by the supervising agent after separate session,
Markdown, and font/UI implementation passes.

- Xcode 27.2 (27B52), native arm64 macOS destination.
- **49 unit tests and 3 UI tests passed**, 0 skipped and 0 failures. The app and
  runners were signed locally, with the app sandbox enabled.
- No Swift source compiler warnings in the final test build. Xcode emitted an
  unrelated out-of-date iOS Simulator service message and its usual no-AppIntents
  metadata-extraction notices; the selected destination was macOS.
- `git diff --check` passed. Temporary diagnostic instrumentation was removed.
- An initial unsigned UI runner was killed before connecting. Local signing
  resolved startup; the signed end-to-end tests then executed successfully.
- The optimized Release build succeeded as version **0.2.2 (3)**, including the
  final glyph-size token cleanup. Its signature passed `codesign --verify --deep
  --strict`, and entitlements include the app sandbox and user-selected read-only
  file access. All three font resources are present in the built bundle.
- The Release candidate was launched and its reader was observed displaying an
  opened project. The user's current app state was left in place for acceptance.

Final test command:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MarkyBugfixSigned test \
  -only-testing:MarkyTests -only-testing:MarkyUITests/MarkyUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

Release build:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MarkyBugfixSigned build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

Local candidate: `/tmp/MarkyBugfixSigned/Build/Products/Release/Marky.app`.

The user reported **PASS** for the initial candidate on 2026-11-05. The individual
manual steps below were not reported separately. Tests exercise bookmark
activation order and scope balance through injected access; real picker-granted
access across a signed app relaunch is included in the manual checklist.

The native outline regression exposed a separate collapse bug: returning `false`
from `outlineView(_:shouldShowOutlineCellForItem:)` prevented native collapse on
the verified macOS runtime. The isolated policy change made the failing row-tap
and collapse-all regression pass. The sidebar now uses native disclosure controls
and retains stable item objects, as required by [AppKit's data-source
contract](https://developer.apple.com/documentation/appkit/nsoutlineviewdatasource/outlineview(_:child:ofitem:)).

## CodeRabbit follow-up

PR: https://github.com/pedjamusic/marky/pull/1

- The initially published commit `53f8245` passed a clean-checkout run of **49 unit
  tests and all 4 UI tests**, including the launch screenshot test.
- Review fixes passed **64 unit tests (67 runs including parameterized cases)**,
  with no failures or skips. The updated signed Release build and signature
  verification also passed.
- After the desktop was unlocked, all **6 UI tests passed**, with no failures or
  skips: folder keyboard navigation, row/disclosure toggles, collapse-all,
  document selection/search, visible nested-list indentation, and launch.
  The geometry test selects the first matching text node because SwiftUI exposes
  both a wrapper and a child with the same accessibility label; its measured
  parent/child indentation assertion remains intact.
- Fixes cover packages/non-regular files, fallback scope retention, pending
  restoration, confirmed-missing-only favorite pruning and concurrent edits,
  authorized alias migration without historical filesystem lookups, folder
  keyboard/search behavior, hover state, app-owned test fixtures, fence indentation,
  literal-aware outer styles, and cancellation before/after preparation.
- Unknown legacy project aliases are preserved and migrated when their original
  location is explicitly reopened under its active grant. Unrelated historical
  paths are not synchronously resolved during local favorite operations.

Follow-up unit command uses the same signed test command above with only
`-only-testing:MarkyTests`; the complete UI command uses
`-only-testing:MarkyUITests`. Final UI result bundle:
`/tmp/MarkyBugfixSigned/Logs/Test/Test-Marky-2026.11.05_23-55-44-+0100.xcresult`.
Final manual acceptance and merge remain pending.

## Manual acceptance

Use a signed, sandbox-enabled app for access-restoration checks. A build with code
signing disabled does not establish persistent sandbox access behavior.
Xcode adds test-only filesystem and automation exceptions to its UI-test build;
the UI suite verifies reader/navigation behavior, not production sandbox
isolation. The separately built Release candidate has no such exceptions.

1. Open a folder with Markdown files at the root and inside a subfolder. Select
   files, search, expand/collapse folders, and switch between favorites and files.
   Check selection and keyboard navigation remain usable.
2. Star two files. Open one file through Open File, toggle its star, then reopen
   the folder. Verify the other file's favorite survives.
3. Quit and relaunch with that folder open. Verify access and favorites restore.
   Repeat with a single file. If using removable/network storage, disconnect it,
   relaunch, reconnect, and reopen; inaccessible content must not erase favorites.
4. Try opening an unreadable or removed location while another project is open.
   Verify an understandable error appears and the prior project remains usable.
5. Open a large folder and immediately open another or close the project. Verify
   the latest action wins and the interface stays responsive.
6. Read a document containing literal inline backticks around bold/link syntax,
   a four-backtick fenced example containing three-backtick lines, ordered and
   nested lists, Unicode text, and mixed bold links. Verify code remains literal.
7. Switch all three typography modes and text-size presets. Confirm the bundled
   Literata/Fraunces appearance, serif bold styling, and nested-list indentation.
   Change settings while loading a large document and while switching files.
8. Check launch, reader, and Settings windows in Light, Dark, and System appearance,
   including focus changes, resizing, and closing the reader during a load.

Manual result: **initial candidate PASS reported by the user on 2026-11-05**.

The user subsequently requested a GitHub PR and automatic fixes for actionable
CodeRabbit feedback. Committing and pushing the review branch are authorized;
merging and deleting the branch wait for the review fixes to be verified and a
final user PASS.
