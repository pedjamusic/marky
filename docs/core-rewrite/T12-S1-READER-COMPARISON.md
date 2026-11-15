# T12.S1 reader parity and performance

Measured 2026-11-15 on Mac16,12 (M4, 10 cores, 16 GiB), macOS 27.2.1 (26B131), Xcode 27.2 (27B52), macOS SDK 27.2, Swift 6.4.2. The Mac ran on AC power. The branch starts from clean `main/f5e5b73fe9671e12f8999ec8999c6ecabf900612`. The comparison builds use Marky 0.2.4 (5).

[Raw measurements and cases](measurements/t12-s1-reader-comparison.json) · [T02 baseline](T02-S2-PERFORMANCE.md) · [T12 exit](phases/05-mac-document-integration.md#t12--parity-and-production-document-cutover)

## Reader parity

The initial comparison matched all 92 shared fixtures, the showcase, and the fixed large document. Two targeted cases dropped the nested quote indicator in the core. A multiline code span normalized the source newline to a space. A multiline image description combined the break and the surrounding text into a single run. The Mac adapter had been adding indicators only after standalone line-break runs.

The Mac adapter now passes its existing indicator when it creates the core document. The core applies the prefix before inline parsing, as the Swift reader does. The ordinary C creation calls still expose undecorated quote runs. Quote line accessors in both modes preserve original depth and source bytes. The Mac adapter can now discard the per-run source end it previously used to insert indicators.

The candidate matched all 102 comparison cases. The comparison included UTF-8 display text, block structure, heading levels, list depths and markers, table alignments and contents, image metadata, and effective UTF-16 font, style, link, color, tracking and paragraph ranges. The cases cover the 92 shared fixtures, eight targeted quote and Unicode cases, [the showcase](../MARKDOWN_SHOWCASE.md), and the 3,585-block T02 document. The attributed range comparison used Light appearance, All System typography and default size.

The new parameterized Mac test failed with the old quote path and passed with the fix. It also checks a code span whose whitespace trimming depends on the prefix, trailing spaces, spanning links and emphasis, and an image alt string containing both a decoded entity newline and a physical line break. The portable test checks prefix ownership, inline source range, unchanged quote source and depth, and invalid prefix arguments.

## The fixed document and comparison boundaries

The driver verified the complete `marky-t02-s2-v1` file and directory inventory. The document has 704,577 bytes and SHA-256 `6d62af6f1566dbf10aeba6b32e8728c255a418c223a8da392f936ce91b504b9a`. Each series discards one fresh-process warm-up and uses five measured fresh processes per reader. The model reports monotonic median time and the largest kernel peak physical footprint. The render and load probes verify all 3,585 rendered blocks. Cancellation requests precede completion and both readers publish zero blocks.

The model probe covers three boundaries. Prepare starts with decoded input. Render also builds the native attributed blocks. Document load includes the actual read and decode, preparation, native rendering and model publication. The Release probe links the same optimized SwiftPM object as the comparison app. The native probe measures window layout.

The native timer starts at the click on `LARGE.md`. It ends when window capture and OCR confirm **Large Reading Fixture** and **Section 0000**. It includes actual load, publication, layout and observation overhead. Settings match T02 at 1252 × 833 points, with the same project, Light appearance, All System typography and default size. Sidebar filename recognition tolerates OCR punctuation and the file icon. This setup is outside the timer. The T02 memory observer supplies an app-only high-water mark. The OCR and capture process is separate.

The semantic and native measurements use separate endpoints. The Swift prepare endpoint ends before inline parsing. By that point the core has parsed inline semantics and copied prepared blocks and runs into Swift. Both representations overlap briefly. This measures a real memory cost at a boundary that performs different work. The end-to-end render, load and native results cover the same observable work.

### Model time and peak footprint

| Endpoint | T02 Swift | Current Swift | Current core |
| --- | ---: | ---: | ---: |
| Prepare | 104.24 ms / 9.47 MiB | 100.65 ms (100.38–101.66) / 9.47 MiB | 19.19 ms (18.70–19.29) / 19.42 MiB |
| Render | 907.63 ms / 83.05 MiB | 889.79 ms (877.98–894.62) / 80.36 MiB | 480.20 ms (471.96–485.42) / 87.59 MiB |
| Document load | 908.43 ms / 82.99 MiB | 893.66 ms (886.50–899.74) / 80.42 MiB | 478.48 ms (474.67–483.13) / 87.55 MiB |
| Cancel request to completion | 99.06 ms / 9.97 MiB | 97.38 ms (96.56–98.76) / 10.00 MiB | 0.26 ms (0.24–0.28) / 8.64 MiB |

The candidate core load median is 46.5% lower than the paired Swift median. Its peak footprint is 8.9% higher. The preparation-only peak remains 19.42 MiB for core versus 9.47 MiB for Swift, with the different work described above. Dropping the copied source end had little effect on this peak.

### Native first viewport and peak footprint

| Layout and parser | Median and range | Largest app peak |
| --- | ---: | ---: |
| Original T02 recording, eager Swift | 14,801.92 ms (11,929.95–14,861.29) | 2,120.88 MiB |
| Original T02 source rebuilt today, eager Swift | 10,131.30 ms (10,107.32–10,491.13) | 3,518.07 MiB |
| Current code before changes, eager Swift | 11,790.78 ms (11,761.08–11,809.10) | 3,631.44 MiB |
| Paired eager core control | 11,466.69 ms (11,394.24–11,514.17) | 3,650.41 MiB |
| Paired candidate, lazy Swift | 1,405.86 ms (1,361.95–1,430.21) | 145.52 MiB |
| Paired candidate, lazy core | 941.03 ms (935.56–958.18) | 153.05 MiB |

The first layout-only trial replaced the document block stack with a SwiftUI lazy stack. It reached the first viewport in 982 ms on the core route, with a 155 MiB peak. The final interleaved run alternates the eager core control and both candidate routes. The lazy core median falls 91.8% and its peak falls 95.8% against the eager core control. The narrow probes still spend about half a second loading and building attributed text for the complete document. The rest of the old wait was largely view creation and native text layout, as shown by the separate process samples. The lazy stack lays out blocks as the viewport approaches them. These samples cover first display and the post-endpoint hold. Memory after reading the entire document is unmeasured. [LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack) · [Picking container views](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

The original T02 native recording used macOS 27.0.1 and fair thermal state. The rebuilt original Swift source reached 3,518 MiB even before reader changes on today's nominal-thermal setup. This reproduces most of the higher eager footprint observed before the layout change. The OS, thermal state, and observation setup changed together. The interleaved eager control and candidate use the current setup and the same driver and observer.

## Native accessibility and acceptance

The opt-in dense-document test finds the first accessible heading, scrolls to a later section, scrolls back, and uses the outline keyboard selection to return to the small document. It passed with both parsers on the unchanged fixture. Earlier eager-layout diagnostics could answer shallow accessibility queries after first paint. The new test exercises actual navigation. VoiceOver and real file-grant restoration still require manual acceptance.

### Verification commands

Run the Mac regressions from the repository root. Set `T12_BUILD` to a new temporary directory and `T12_FIXTURE` to a generated T02 fixture directory.

```sh
python3 tools/performance/fixtures.py generate "$T12_FIXTURE"
python3 tools/performance/fixtures.py verify "$T12_FIXTURE"

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$T12_BUILD/debug" \
  -parallel-testing-enabled NO -only-testing:MarkyTests \
  -only-testing:MarkyUITests/MarkyUITests test

TEST_RUNNER_MARKY_PERFORMANCE_ROOT="$T12_FIXTURE" xcodebuild -scheme Marky \
  -project Marky.xcodeproj -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$T12_BUILD/optimized" -enableCodeCoverage NO -parallel-testing-enabled NO \
  -only-testing:MarkyUITests/LargeInputPerformanceTests/testDenseDocumentNavigation \
  ENABLE_TESTABILITY=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

All 127 Mac unit tests and 10 regular UI tests passed. The separate dense test ran both paths and passed. Independent macOS CMake and CTest passed 3/3 in Debug and Release with `-Wall -Wextra -Wpedantic -Werror`. The dedicated native corpus test now runs the 92 cases in the ordinary Mac suite. Windows and Linux execution remain tracked under B03.

The performance runs follow the [T02 reproduction commands](T02-S2-PERFORMANCE.md#reproduction) with the optimized SwiftPM object linked into the standalone model probe and the existing core test route enabled in the Release comparison app. The model runner alternates Swift and core in `prepare`, `render`, `document` and `cancel-document`. The native driver rotates eager core, lazy Swift and lazy core across fresh app launches and joins external peaks by PID. The comparison app binaries use the original T02 testability, signing and coverage flags. The full per-process samples, identities and measured case results are in the raw record. Local driver sources and full logs are in `/tmp/MarkyT12S1Fix.EE0vdu`.

### Signed review candidate

The standalone signed Debug app is at `/tmp/MarkyT12S1Fix.EE0vdu/signed/Build/Products/Debug/Marky.app`. Strict signature verification passed. Its entitlements include the app sandbox, user-selected read-only file access, outgoing network access, and local debugging. Debug library SHA-256 `6f90fff799acf837bd6ca3e3cd5233db8e30bf8a21f95c49d99662b9d4a47946`. Optimized comparison executable SHA-256 `5692190aa3ac41684fa5da825eb6144a1cc65906f8331061d70b977ce2b0d753`.

```sh
open -n -a /tmp/MarkyT12S1Fix.EE0vdu/signed/Build/Products/Debug/Marky.app \
  --env MARKY_TEST_DEFAULTS_SUITE=Marky.T12S1Review --args --core-reader-test
```

1. Open `/tmp/MarkyT12S1Fix.EE0vdu/review/Quote-Parity.md`. Check the nested markers inside the code span and image description, and confirm the spanning emphasis retains its styling.
2. Open `/tmp/MarkyT12S1Fix.EE0vdu/fixtures/project` and select `LARGE.md`. Scroll several sections, return to the top, and switch to `README.md` with the outline keyboard selection.
3. Open the showcase and check narrow-window wrapping, link hover and the standalone image preview. Reopen the signed app in the same review suite to exercise folder grant restoration. If using VoiceOver, check the large document's heading navigation.

User PASS accepted the readout and layout candidate, which landed on main through [PR #6](https://github.com/pedjamusic/marky/pull/6). The preparation-only comparison still needs disposition under the 20% gate. The end-to-end model render, model load, and native viewport show comparable work and meet the gate on the fixed fixture.

The production default remains Swift. The Debug parser argument selects the core for review. T12.S2 is queued behind disposition of the preparation memory comparison.
