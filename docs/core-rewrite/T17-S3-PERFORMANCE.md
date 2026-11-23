# T17.S3 fixed-baseline performance

**User PASS accepted the corrected candidate on 2026-11-23.** The fixed comparisons meet the 20% limit at the matched processing and peak-memory endpoints. The full scan peaks at 16.03 MiB, below the original 16.92 MiB. [Corrected candidate](#corrected-candidate-measurements) · [Initial raw measurements](measurements/t17-s3-performance.json) · [Acceptance record](STATUS.md#verification-and-acceptance-evidence)

Measured 2026-11-23 on `codex/t17-s3-performance` from `b0799b09b125c644fb798ce3c8ee3696e64f9acd`. The initial Release app was built from that revision. The corrected app includes the uncommitted scanner and favorites changes on that branch.

## Conditions

Both builds ran on a Mac16,12 MacBook Air with an M4, 10 CPU cores, 16 GiB RAM, and AC power. This run used macOS 27.2.1 (26B131), Xcode 27.2 (27B52), the macOS 27.2 SDK, and Swift 6.4.2. The accepted T02 baseline used macOS 27.0.1 (26A434) on the same hardware and compiler. The original model and folder runs recorded nominal thermal state. The original dense visual run recorded fair thermal state. The original T02 records remain the fixed reference for the 20% gate. The T02 Swift source rebuilt from `31ebae6bb8733c46cb23ebcbd263625f882a38b2` provides a control on the current OS and desktop. [T02 report](T02-S2-PERFORMANCE.md) · [Contract](CONTRACT.md#verification-and-performance)

The generated `marky-t02-s2-v1` fixture passed the exact file, directory, and byte inventory checks. The large document is 704,577 bytes with SHA-256 `6d62af6f1566dbf10aeba6b32e8728c255a418c223a8da392f936ce91b504b9a`. The tree contains 5,002 visible Markdown files and 601 visible directories, including its root. The complete fixture inventory digest is `adf17448611256cc3c63a33c9d00ff9833aa84678e0b0163dbd90b936eb98e67`.

Each series uses fresh processes, with one discarded warm-up and five measured runs. The median uses monotonic elapsed time. Memory uses the largest process-lifetime kernel peak among the five measured runs. The standalone probe records both physical footprint and peak RSS. The app observer records the app's physical footprint and joins by PID. The app measurements use Light appearance, All System typography, and default reader size. The native visual endpoint includes screenshot and OCR time, while app memory excludes the capture and OCR process.

## Model probe update

The standalone probe calls the same production parser and native renderer as `MarkdownDoc.load`. It preserves real file loading, native rendering and model publication in the document scenario. The search timer now ends after the production view model publishes its asynchronous result. The probe checks all 3,585 document blocks, the 5,002-file tree, and all 500 search matches. The first attempt stopped at the old synchronous search assertion. Its completed samples are retained as a diagnostic.

The prepare boundary differs between the readers. The Swift implementation prepared blocks and references there. The core also parses inline semantics and copies them into Swift. The render and document endpoints cover the same observable work. The T12 decision treated preparation as a diagnostic for the T12 cutover. The T17 measurement records it separately for review under OWE-T02. [Approved T12 scope](STATUS.md#t12-reader-cutover-performance-endpoints)

## Model results

The sequential series showed large runtime swings even within one configuration. Two follow-up series interleaved the binaries at each scenario and reversed their order on alternating runs. Each binary still ran one warm-up and five measured processes per scenario. The second interleaved run began after a cooldown and recorded fair thermal state throughout. It had tighter document-load ranges on both sides. Its results appear below. Time is in milliseconds and peak physical footprint is in MiB. The JSON includes both interleaved runs and the sequential runs, with peak RSS and secondary timers.

| Endpoint | T02 recorded time / peak | Rebuilt Swift time / peak | Integrated time / peak | Integrated range |
| --- | ---: | ---: | ---: | ---: |
| Prepare | 104.24 / 9.47 | 104.66 / 9.38 | 20.69 / 19.61 | 20.09–32.95 |
| Native attributed render | 907.63 / 83.05 | 913.52 / 82.78 | 484.59 / 88.30 | 479.79–487.93 |
| Document load and publication | 908.43 / 82.99 | 908.49 / 82.75 | 479.04 / 87.64 | 471.86–482.62 |
| Complete tree scan | 175.83 / 16.92 | 177.57 / 16.94 | 186.14 / 20.83 | 183.99–187.61 |
| Project open, search, and close | 237.02 / 20.13 | 242.21 / 19.77 | 193.73 / 21.38 | 192.67–200.72 |

Scan footprint exceeded the recorded T02 peak by 23.1% and the rebuilt Swift peak by 23.0%. The other complete runs reproduced the footprint increase. Scan RSS increased by 12.7% against recorded T02. Scan time increased by 5.9% against recorded T02 and by 4.8% against the rebuilt control in the tighter repeat.

The tighter repeat put the document median 47.3% below both references, with 5.6% more peak footprint than recorded T02. In the first interleaved run, the integrated document median exceeded recorded T02 by 39.0% while the rebuilt Swift median rose by 41.2%. The first interleaved run's ranges were 490.18–1,562.04 ms for the integrated probe and 920.70–3,059.06 ms for the rebuilt control. The sequential render run also exceeded recorded T02 by 54.0%. The spread and temperature difference leave a fixed runtime comparison open.

Separate one-second process samples of repeated workloads found scan work primarily under `NativeProjectScan.enumerate`, including directory listing and URL canonicalization. Render samples concentrated in `MarkdownContentBlocks.render`, including native font and attributed-text work. Time samples locate the work. Allocation profiling remains necessary to attribute the scan's peak increase.

Model search published 500 matches in every complete run. The tighter repeat's median was 3.43 ms, compared with 4.61 ms in recorded T02 and 4.43 ms in the rebuilt control.

### Cancellation and replacement

| Request to completion or publication | T02 recorded median | Rebuilt Swift median | Integrated median | Integrated range |
| --- | ---: | ---: | ---: | ---: |
| Cancel document | 99.056 ms | 98.638 ms | 0.271 ms | 0.242–0.296 ms |
| Cancel scan | 0.075 ms | 0.065 ms | 1.644 ms | 1.506–2.103 ms |
| Replacement ready | 3.835 ms | 6.614 ms | 7.525 ms | 6.794–7.752 ms |

Every interleaved document cancellation arrived before completion and published zero blocks. Every scan cancellation returned `CancellationError`. The small replacement project stayed current through every 100 ms settling check. The sequential integrated scan cancellation median was 0.098 ms. The interleaved medians were 2.162 ms and 1.644 ms. The tighter repeat's replacement publication was 13.8% slower than the rebuilt control and 96.2% slower than the original recording. The rebuilt control also lost time against the original recording. Both short timings need investigation. The JSON includes total process time and memory for all three scenarios.

## Large-folder app results

Both Release apps completed all six iterations of `testFixedLargeFolder`. The app reached the small reader and exposed a matching row after typing `note-09`. All six PIDs per build matched the external kernel observer. Both builds recorded 1470 × 830 points and fair thermal state. T02 recorded 1252 × 833 points and nominal thermal state, so the current series supplies a same-desktop comparison.

| Metric | T02 recorded | Rebuilt Swift | Integrated | Integrated range |
| --- | ---: | ---: | ---: | ---: |
| Launch to reader median | 1,800.29 ms | 1,711.26 ms | 1,683.03 ms | 1,583.34–1,725.80 ms |
| Search to outline median | 3,247.68 ms | 3,196.86 ms | 2,844.29 ms | 2,798.03–3,424.77 ms |
| Largest app peak | 102.45 MiB | 101.33 MiB | 103.59 MiB | |

The integrated launch and search medians were 1.6% and 11.0% lower than the rebuilt control. The peak was 2.2% higher. Search ranges overlap and include XCTest input and accessibility costs.

## Dense reader first viewport

The unchanged native driver rejected both app windows at its original 1252 × 833-point geometry check. A temporary diagnostic allowed the actual 1470 × 830-point window and retained the native click, capture cadence, OCR settings, reader assertions, and memory observer. Its first runs located `LARGE.md` visually but failed the exact OCR filename check during setup. The retry used the T12 approach of normalizing the recognized filename before clicking the row. Both builds then completed all six fresh-app observations. Each timed result required **Large Reading Fixture** and **Section 0000** in the reader. The current app's reviewed capture also shows formatted text, lists, a table, and a code block.

| Series | Median time | Measured range | Largest app peak |
| --- | ---: | ---: | ---: |
| T02 accepted native visual baseline | 14,801.92 ms | 11,929.95–14,861.29 ms | 2,120.88 MiB |
| Rebuilt Swift | 10,324.50 ms | 10,189.90–15,033.47 ms | 3,519.16 MiB |
| Integrated | 963.38 ms | 943.01–982.37 ms | 156.61 MiB |

The current app recorded fair thermal state throughout. The rebuilt control recorded a mix of nominal and fair. Its eager layout and the current lazy layout also allocate different amounts of native text layout at first paint. The large improvement is consistent with the T12 comparison. The changed desktop geometry leaves the fixed native comparison open. The capture covers the first viewport. Peak after scrolling the full document remains unmeasured. [T12 layout evidence](T12-S1-READER-COMPARISON.md#native-first-viewport-and-peak-footprint)

## Initial verification checkpoint

Profile the scan's allocation peak and cancellation delay, then repeat the fixed comparison after corrections. Verify replacement publication under the original conditions. Reproduce the folder and dense native measurements at 1252 × 833 points with their recorded thermal conditions. OWE-T02 and the T17 performance receipts stay open. Both benchmark apps passed strict signature verification. The measurements used Release UI test builds with test entitlements. The branch is uncommitted and user acceptance is pending.

## Project scanner correction

The scan now builds each document URL from its already resolved directory and the document's own filename. The scratch variants returned identical ordered trees for the fixed fixture and additional alias, symlink, and escaped-name fixtures. Removing the temporary URL lookup table instead increased scan peak from 21.27 to 22.61 MiB in the same diagnostic series. Reusing the directory reduced the peak to 16.05 MiB.

Temporary cancellation traces showed the handler and core request returning promptly. In the slower traces, the worker was still in a synchronous directory listing or the sibling sort. The scanner now checks cancellation in the sort comparator. The worker still finishes the filesystem call already in progress and retains the existing grant and token lifetime until it exits. A streaming Foundation enumerator reduced some cancellation delays on the fixture and pushed scan peak above 25 MiB. The candidate retains the shallow listing.

The scan now reads the current locale once and uses it for every case-insensitive comparison. This keeps one collation policy throughout the scan and avoids repeated implicit locale lookup. In the interleaved prototype, scan cancellation median fell from 1.741 to 0.067 ms. Twelve fresh processes per side were measured. The sort comparisons matched the previous implementation on 400 filename pairs in each of five locales, including Turkish dotted I, Swedish accents, Unicode normalization, and mixed-case filenames. The full T02 fixture still contains 5,002 Markdown files.

Replacement traces separated scope acquisition, scanning, root publication, and bookmark persistence. The small scan took less than 1 ms in every trace. Favorites reconciliation and bookmark persistence accounted for most of the remaining wait. The favorites store now skips writing an unchanged project entry and still persists each alias migration. The prototype median for replacement readiness fell from 4.983 to 4.483 ms over twelve interleaved processes per side. The ranges overlapped. The final fixed series includes bookmark persistence in the original timer.

### Corrected candidate measurements

Both builds finished the complete model scenario sequence twice in alternating order, with nominal thermal state, one warm-up, and five measured fresh processes per scenario. These series use the signed app's production Swift code with the optimized core package. Raw output retains both series and the rebuilt Swift control. [Correction record](measurements/t17-s3-correction.json)

| Model endpoint | Fixed T02 median / peak | Candidate median / peak | Candidate repeat median / peak |
| --- | ---: | ---: | ---: |
| Attributed render | 907.63 ms / 83.05 MiB | 493.74 ms / 88.20 MiB | 507.84 ms / 88.19 MiB |
| Document load | 908.43 ms / 82.99 MiB | 496.31 ms / 87.91 MiB | 520.87 ms / 88.03 MiB |
| Complete scan | 175.83 ms / 16.92 MiB | 103.34 ms / 16.00 MiB | 115.72 ms / 16.03 MiB |
| Open project, search, and close | 237.02 ms / 20.13 MiB | 109.51 ms / 16.55 MiB | 134.58 ms / 16.59 MiB |
| Model search | 4.61 ms | 3.46 ms | 3.98 ms |

The scan peak fell below the fixed T02 peak in both series. The 20% ceiling was 20.31 MiB. The greatest candidate scan peak in those series was 16.03 MiB. The prepare-only peak was 19.36 and 19.34 MiB. The core prepares inline semantics at that boundary. The matched render and load boundaries include inline and attributed work for both readers.

Scan cancellation median was 0.069 ms in the first series, against 0.068 ms for the rebuilt control and 0.075 ms in T02. In the noisier repeat, the candidate and rebuilt control rose to 1.464 and 1.598 ms. Small-project publication took 2.937 ms and 5.924 ms for the candidate. The rebuilt control took 3.034 ms and 5.579 ms. The second candidate series included a 160.17 ms sample. Every scan cancellation returned `CancellationError`. Every replacement preserved the small root through settling. Both series preserved the document cancellation outcome of zero published blocks.

The corrected apps reached the original 1252 × 833-point window. A launch-time window frame override set the geometry for both apps. The display temporarily used a larger session mode and returned to the original mode afterward. The driver normalizes the sidebar filename during setup, before timing the click. Its timed capture cadence and reader recognition are unchanged. The candidate's dense viewport series recorded fair thermal state in all six fresh processes, as in T02. Its median was **952.32 ms** (945.56–992.41 ms) versus **14,801.92 ms** in T02. Its largest observed app peak was **152.42 MiB** versus **2,120.88 MiB**. The rebuilt control's six native samples used nominal thermal state. They are retained as a current-OS diagnostic.

The first corrected large-folder series also reached 1252 × 833 points in all six processes. It measured 1,975.09 ms to launch (1,862.98–2,081.22 ms), 3,722.24 ms to search (3,552.47–3,925.11 ms), and 97.52 MiB peak. Those values are inside the numerical limit. The machine recorded fair thermal state for the whole series. T02 recorded nominal thermal state for this endpoint.

A second fair series reproduced the numerical result. The nominal retry used a temporary 2560 × 1600 session display so the app could host the 1252 × 833-point window with less display work. All six apps recorded nominal thermal state. The display returned to its original mode. The launch median was **1,676.32 ms** (1,670.32–1,704.69 ms), 6.9% below T02. Search was **2,841.61 ms** (2,819.59–2,843.86 ms), 12.5% below T02. Peak was **96.95 MiB**, 5.4% below T02. Every run produced a searchable outline and matched a fresh app PID to the kernel memory observer.

The corrected build passed 131 unit tests. Three focused Release UI tests passed. They cover project search and document selection, favorite filtering, and dense-document navigation. The separately built Release app passed strict signature verification and retains the app sandbox and read-only picker grant. Its executable SHA-256 is `e362b64d6c6a6a76ac6bc7f6f0a06bb9ec7aafe7aa9f7403aadd1196cccf50b9`.

### Signed review candidate

The review app is `/private/tmp/MarkyT17Resolve.ANKF2l/signed/Build/Products/Release/Marky.app`. Start it with isolated preferences.

```sh
open -n /private/tmp/MarkyT17Resolve.ANKF2l/signed/Build/Products/Release/Marky.app \
  --env MARKY_TEST_DEFAULTS_SUITE=Marky.T17S3.Review.ANKF2l
```

1. Open `/private/tmp/MarkyT17S3.w2dlxK/fixture/project` and search for `note-09`. Choose a result and check that its Markdown opens.
2. Open `/private/tmp/MarkyT17S2.rfsfEX/CancellationProject` and press Command-Shift-W to close it. Check that the welcome screen stays visible. Reopen the small folder at `/private/tmp/MarkyT17S3.w2dlxK/fixture/small` and check that its document appears.

## Reproduction

Run from the repository root with `T17_RUN` set to a fresh temporary directory. Build both apps before taking samples. Use the Release build flags and observer commands in the T02 report. For the rebuilt Swift control, run the original commands in an exported copy of `31ebae6`. For the current probe, use the SwiftPM object and module map emitted by the current Release build. [T02 reproduction](T02-S2-PERFORMANCE.md#reproduction)

```sh
python3 tools/performance/fixtures.py generate "$T17_RUN/fixture"
python3 tools/performance/fixtures.py verify "$T17_RUN/fixture"

T17_DERIVED="$T17_RUN/current-build"
xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$T17_DERIVED" \
  -enableCodeCoverage NO -parallel-testing-enabled NO build-for-testing \
  ENABLE_TESTABILITY=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

xcrun swiftc -O -whole-module-optimization -swift-version 6 \
  -strict-concurrency=complete -default-isolation MainActor \
  -enable-upcoming-feature MemberImportVisibility -target arm64-apple-macos26.2 \
  -module-cache-path "$T17_RUN/swift-cache" -parse-as-library \
  -Xcc "-fmodule-map-file=$T17_DERIVED/Build/Intermediates.noindex/GeneratedModuleMaps/MarkyCore.modulemap" \
  -Xcc "-I$PWD/core/include" -lc++ -o "$T17_RUN/IntegratedProbe" \
  $(rg --files Marky -g '*.swift' -g '!MarkyApp.swift') \
  tools/performance/Probe.swift "$T17_DERIVED/Build/Products/Release/MarkyCore.o"

python3 tools/performance/fixtures.py measure "$T17_RUN/fixture" \
  --probe "$T17_RUN/IntegratedProbe" --results "$T17_RUN/integrated-model.json"
```

For the fixed UI tests, give the desktop enough usable space for a 1252 × 833-point window. Forward the frame preference name and saved frame string from the correction record as `TEST_RUNNER_MARKY_PERFORMANCE_FRAME_KEY` and `TEST_RUNNER_MARKY_PERFORMANCE_FRAME` to XCTest. For the standalone native driver, use `MARKY_PERFORMANCE_FRAME_KEY` and `MARKY_PERFORMANCE_FRAME`. The wrappers assert the recorded window size after each run. Use the same arguments for the current app and the rebuilt Swift control. Keep screenshot capture, OCR, and memory observation outside the app process. [Raw configuration](measurements/t17-s3-correction.json)
