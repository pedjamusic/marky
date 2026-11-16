# T12.S2 macOS reader cutover

`MarkdownDoc` parses every document with `CoreMarkdownParser` in Debug and Release. It caches the core document for settings changes. The Swift comparison renderer remains available to the tests. The production load path has one parser and reports failures through the reader's error view.

The [approved T12.S1 comparison](T12-S1-READER-COMPARISON.md#cutover-performance-decision) clears the 20% limit at all three matched endpoints. T12.S2 changes which parser the app calls. The core and native rendering code are the same as in that comparison. T17 owns the next fixed-baseline performance run.

## Review the signed candidate

Use the standalone arm64 Release build, Marky 0.2.4 (5). Quit any other Marky copy before launching it. Keep the same app and defaults suite when checking restoration.

```sh
open -n -a /tmp/MarkyT12S2.cvKmKk/candidate/Build/Products/Release/Marky.app \
  --env MARKY_TEST_DEFAULTS_SUITE=Marky.T12S2Review
```

1. Use **Open Folder** to open `/tmp/MarkyT12S2.cvKmKk/review/project`. Open `01-Start.md`. Check the nested list and quote, table alignment, literal link syntax in the code span, and inline image alt text. Hover over **Example** in the table and click it to open the link.
2. Click **Grant Folder Access…** on the mascot and choose `/tmp/MarkyT12S2.cvKmKk/review/art`. Check the caption and open the image preview. The missing image should still show a fallback.
3. Select `02-Large.md`. Scroll from **Section 0000** to a later section and back. If you use VoiceOver, move between headings in the reader. Change the typography, text size, and appearance in Settings. Switch quickly from `02-Large.md` to `03-Latest.md` and check that **Latest selection** stays visible.
4. Open `04-Invalid.md` and check for the encoding error. Return to `01-Start.md` and check that normal reading resumes.
5. Star `01-Start.md`, quit with the folder open, and relaunch with the command above. Check that the folder and favorite return and that you can read the document. Use **Open File** to open `/tmp/MarkyT12S2.cvKmKk/fixtures/small/README.md`. Quit and relaunch again. Check that **Replacement Fixture** reopens.

The user reported **PASS** for this build on 2026-11-16. [Acceptance ledger](STATUS.md#verification-and-acceptance-evidence)

## Candidate and verification record

- Local branch `codex/t12-s2-reader-cutover` from `main` at `b42623e2f182df00b4ec95fab6eecf952a181444`. The working diff carries the approved performance amendment from `fd1338e`. The app and test diff SHA-256 is `cee53f3f94467272db850a6180b6e2b7d9ccbef306e91b017c65ed7f4873b396` (`git diff --binary -- Marky MarkyTests MarkyUITests`).
- The standalone executable SHA-256 is `0c16ed0419611eef51875e284aa1c4ed0a98c76f416b05e39ccc3ff7cb5edb25`. `codesign --verify --deep --strict` passed. The local ad hoc signature has app sandbox, read-only user-selected files, outgoing network, and local debugging entitlements. The standalone build has hardened runtime and has no XCTest filesystem or Mach exceptions. Its executable links the C++ parser statically and contains no comparison launch flag.
- On macOS 27.2.1 (26B131) arm64, Xcode 27.2 (27B52), and Swift 6.4.2, all 127 Release unit tests passed. Coverage includes the 92 shared native parity fixtures, stale loads, cancellation, settings during a suspended load, UTF-8 and UTF-16, and read failure recovery. All 12 Release UI tests passed, including the launch test, the ten reader and sidebar tests, and large-document navigation. The initial combined invocation passed the UI suite and could not load the ad hoc unit bundle. The unit-only retry disabled hardened runtime for the test host and passed.
- Apple Clang 21.0.0 and CMake 4.4.5 passed CTest 3/3 in both Debug and Release with warnings treated as errors. The fixed T02.S2 document matched its recorded SHA-256 `6d62af6f1566dbf10aeba6b32e8728c255a418c223a8da392f936ce91b504b9a`. Windows/MSVC and Linux/GCC execution remains under B03.
- The standalone app opened the review folder through the native picker, rendered the first document, loaded the sibling image after a folder grant, and opened the preview. Switching from the large file to the small file displayed **Latest selection**. The invalid file showed the UTF-8/UTF-16 error, and the first document recovered. Quit and relaunch restored both the folder grant and, separately, the single-file grant. The user reported overall PASS without individual results for settings, link activation, favorites restoration, or VoiceOver.

Run these commands from the repository root. Set `T12_BUILD` to a new temporary directory.

```sh
python3 tools/performance/fixtures.py generate "$T12_BUILD/fixtures"
python3 tools/performance/fixtures.py verify "$T12_BUILD/fixtures"

for config in Debug Release; do
  cmake -S core -B "$T12_BUILD/core-$config" -DCMAKE_BUILD_TYPE="$config" \
    -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
  cmake --build "$T12_BUILD/core-$config" --parallel 4
  ctest --test-dir "$T12_BUILD/core-$config" --output-on-failure
done

TEST_RUNNER_MARKY_PERFORMANCE_ROOT="$T12_BUILD/fixtures" \
  xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$T12_BUILD/tests" \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -only-testing:MarkyUITests/MarkyUITests -only-testing:MarkyUITests/MarkyUITestsLaunchTests \
  -only-testing:MarkyUITests/LargeInputPerformanceTests/testDenseDocumentNavigation \
  ENABLE_TESTABILITY=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$T12_BUILD/tests" \
  -enableCodeCoverage NO -parallel-testing-enabled NO -only-testing:MarkyTests \
  ENABLE_TESTABILITY=YES ENABLE_HARDENED_RUNTIME=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$T12_BUILD/candidate" \
  CLANG_ENABLE_CODE_COVERAGE=NO ENABLE_TESTABILITY=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

## Swift parser removal inventory for T18

- `Marky/MarkdownContentBlocks.swift` contains `MarkdownSourceBlock`, `MarkdownPreparedBlock`, `MarkdownPreparedListItem`, and the legacy fence, block, reference, list, table, and image recognition. The Swift `prepare` and `render` overloads supply the comparison fixtures. `render(coreDocument:…)` and the native rendered types are used by the production reader.
- `MarkdownRenderer` in `Marky/MarkdownViewer.swift` contains the string-based `render` and `renderInline` overloads and their link and inline parsing helpers. The core overload takes runs carrying the parser's semantic decisions and applies native fonts, colors, and link attributes.
- `MarkyTests/MarkdownCompatibilityTests.swift` and the legacy-specific Swift renderer assertions exercise those implementations. Migrate relevant expectations to the core or native adapter before removing the old paths. The `prepare` and `render` scenarios in `tools/performance/Probe.swift` still describe the historical Swift baseline. T17 must point these scenarios at the integrated reader and match the endpoints recorded in [T02.S2](T02-S2-PERFORMANCE.md#reproduction).
