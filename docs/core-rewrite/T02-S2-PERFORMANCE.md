# T02.S2 — Fixed large-input performance baseline

Measured 2026-11-06. User acceptance and Git execution are recorded separately in [STATUS](STATUS.md). **Accepted 2026-11-06: user reported PASS.** B05 measurement endpoint supplied; E19 in STATUS records acceptance separately from Git execution. The native follow-up below adds a successful full-project dense baseline and retains the original failures. This is measurement tooling for the existing Swift app; production source, settings, parser selection and app version are unchanged.

## Candidate and conditions

- Base revision: `f910e20f6a0eb0a296843aa7cfd327d0230075f9`, initially clean `main`. User authorized local branch `codex/t02-s2-performance-baseline`. The candidate adds the [native visual driver](../../tools/performance/NativeReaderProbe.swift), the [fixture runner](../../tools/performance/fixtures.py), [production-source probe](../../tools/performance/Probe.swift), [external memory observer](../../tools/performance/MemoryWatch.swift), [opt-in UI measurement](../../MarkyUITests/LargeInputPerformanceTests.swift), this report, raw results and roadmap bookkeeping.
- App **0.2.4 (5)**, macOS **27.0.1 / 26A434**, native arm64, Xcode **27.2 / 27B52**, macOS SDK **27.2**, Swift **6.4.2**. Source trees match [T02.S1](T02-S1-MAC-BASELINE.md): `Marky=dac6bed4de3733323395f61f12787630a0ef737f`, `MarkyTests=eb751867f68a6a47c80b82641d6c59d82e8b4c8f`, `Marky.xcodeproj=b5b6d34944c2d5b9671e6cefcc68d1ba2e598d3f`. Only a new test file changes the UI suite.
- MacBook Air **Mac16,12**, Apple **M4, 10 CPU cores (4 performance + 6 efficiency)**, **16 GiB RAM**; local temporary filesystem; AC power, charged battery. Thermal state is recorded per sample. Measurements are sequential, with compilation completed first; ordinary desktop/background activity is not controlled. No cold-disk/cache-flush claim.
- Probe: optimized `-O -whole-module-optimization`, Swift 6, complete concurrency checking, default MainActor isolation, MemberImportVisibility, arm64 macOS 26.2 target. It compiles the existing app sources except the app entry point, plus its own entry point. It is a separate unsandboxed executable, without the app lifecycle, UI or bundled-resource registration; all-system typography avoids bundled-font dependencies.
- UI app: optimized **Release**, `ENABLE_TESTABILITY=YES`, coverage explicitly **off**, serial test execution, local ad-hoc signing. Testability is needed because the scheme also builds existing `@testable` unit imports. The signed test app has sandbox/file/network entitlements **and Xcode test-only filesystem/Mach exceptions**. These measurements establish no picker-grant or restoration behavior. Retain these flags for comparison; do not compare this app's memory directly with the probe's memory.

Original executable/tooling hashes, raw samples and summaries are retained unchanged in [the initial measurement record](measurements/t02-s2-v1.json). The B05 follow-up and completed native visual baseline are retained separately in [the native record](measurements/t02-s2-native-v1.json). Temporary console logs/xcresult bundles are supplementary, not the sole evidence.

## Fixed inputs

`marky-t02-s2-v1` is synthetic, deterministic UTF-8/LF content, without private files, remote downloads, images or symlinks. Generate outside the repository; the generator refuses to overwrite an existing directory. Verification reconstructs the expected bytes and exact file/directory inventory, rather than trusting the manifest alone.

| Input | Fixed identity and workload |
| --- | --- |
| `project/LARGE.md` | **704,577 bytes**, SHA-256 `6d62af6f1566dbf10aeba6b32e8728c255a418c223a8da392f936ce91b504b9a`; 512 sections, **3,585 prepared/rendered blocks**. Heading, long formatted prose, combining characters, emoji/CJK, inline/fenced code, links/references, nested/task lists, quotes, aligned tables and thematic breaks. |
| `project` | **5,002 visible Markdown files / 601 visible directories including root**: README/LARGE plus 100 groups × 5 topics × 10 notes. Also 500 ignored text files, 100 hidden directories/files, 100 `.app` packages with nested Markdown, and 100 empty directories. Scanning must prune/exclude these entries. |
| `small` | One small replacement Markdown file, used to observe latest-project publication. `project/README.md` is the small initial reader document for launch and search measurements. |
| Entire generated input | **5,703 files / 908,579 bytes**. Sorted file inventory digest **`adf17448611256cc3c63a33c9d00ff9833aa84678e0b0163dbd90b936eb98e67`**: SHA-256 over each relative UTF-8 path, NUL, the file's hexadecimal SHA-256, LF. This excludes the generated manifest itself; exact directory inventory is checked separately. |

The app's existing seed path opens the generated folder through the real project-opening flow, then selects README. Fixture generation and verification are outside timing. Probe calls also validate block/file/directory counts and search output; the accepted 92-case compatibility corpus remains the semantic correctness baseline.

## Procedure and endpoints

For **each of eight probe scenarios**, run **one discarded fresh-process warm-up and five measured fresh processes**. Each large-folder UI iteration also starts a fresh app; discard the first of six iterations. The original XCTest dense-document observation is a separate failing run. The external native visual endpoint described below supplies a successful six-process series independently of that failed route. Filesystem/framework caches remain warm. No timed code generation/builds, concurrent probe/UI runs or benchmark processes are intentional. The early exploratory probe run overlapped compilation and is excluded from the final record.

Time uses monotonic system uptime. Report **median** time over five measured runs, and retain their range/raw values. Memory is the **largest process-lifetime peak among the five measured runs**, without subtracting startup/framework costs. Darwin `proc_pid_rusage(..., RUSAGE_INFO_V4, ...)` supplies `ri_lifetime_max_phys_footprint` (bytes); the probe additionally records `getrusage` peak RSS in bytes. These are kernel high-water marks, not periodic RSS samples or per-operation allocations. The sandboxed UI runner cannot read another process's usage. The external observer matches the exact test executable, polls its kernel high-water counter every nominal 50 ms, and joins results to the six PIDs recorded by the UI test. Each iteration holds the app for 250 ms after timing before termination. Thus short-lived peaks persist in the kernel counter until a subsequent read; the retained value is the largest observed kernel peak, not a guarantee about allocations during the final process-exit interval. Memory excludes the separate test/OCR runner and observer. The summarizer requires six ordered fresh PIDs, positive peaks and multiple successful reads; only an ESRCH exit race is allowed. Peak values can include transient/allocator-retained allocations, search and native layout.

| Scenario | Timed boundary and observable result |
| --- | --- |
| `prepare` | Decoded string → `MarkdownContentBlocks.prepare` → 3,585 blocks. `processing_ms` excludes read/decode; process elapsed/peak still include them. This is block/reference preparation; it does **not** include all inline semantics. |
| `render` | Decoded string → preparation **and native attributed inline rendering** → 3,585 blocks, all-system/default/light. This closes the inline/native-adapter cost omitted by preparation alone. |
| `document` | Default `MarkdownDoc.load`, including real read/decode/security-scope calls, preparation, native rendering/publication, count/error/loading checks and cleanup. No injected loader. No view layout. |
| `scan` | Real `FileNode.loadProjectTree` → complete filtered/sorted tree → file/directory count validation and cleanup. |
| `project` | Default `ContentViewModel.openPickedFolder` → `waitForProjectLoad` → tree validation → actual `note-09` search (500 matches) → validation and close. Includes indexing, favorites reconciliation, isolated preferences/bookmark persistence and cleanup. `search_ms` separately brackets the real setter/rebuild. |
| `cancel-document` | Start default document load; a detached task requests cancellation after a nominal 5 ms. Record actual request-to-completion, whether it preceded completion, published blocks and silent error/loading state. |
| `cancel-scan` | Start real async scan; request cancellation after a nominal 5 ms; require a `CancellationError`, then record actual request-to-completion. |
| `replace-project` | Start large project open, wait a nominal 5 ms, open `small`, await latest load. `replacement_ready_ms` ends at verified small-root publication; overall elapsed additionally includes **100 ms** settling observation, revalidation and close. That settling delay is not cancellation latency. |
| UI launch | `XCUIApplication.launch` → small README heading accessible in real reader. Includes launch, scan/index/project publication, native outline and reader setup, XCTest startup/readiness checks. |
| UI search | On the small reader, click/type `note-09` → a matching row exists in the expanded native outline. Includes synthesized typing, native filtering/layout and accessibility polling. The app then terminates; LARGE is tested separately. |
| Dense reader observation | Separately click LARGE (including native outline auto-scroll), then attempt to recognize the exact **Large Reading Fixture** heading in a screen image, with a nominal 30-second deadline checked only after the XCTest click returns. Retain screenshot, elapsed observation and external peak even when the assertion fails. This is a failed observation, not a processing-time median or successful full-document display. |

The dense diagnostic avoids querying the large reader's accessibility tree after the click, but the launch/click still uses XCTest automation. The screen stayed on Loading in the inspected timeout captures; the native/automation cause is not fully isolated. This cannot establish standalone production-app behavior or accessibility usability; a separate untimed native check below showed first content outside this automation path. Window size is recorded per run and must match in T17. Light appearance, all-system/default typography and the same screen/UI automation endpoint are required for comparison. The screenshot is a temporary xcresult attachment for supervisor review, not a checked-in desktop image.

## Results

| Probe workload | Median time (ms) | Measured time range (ms) | Largest peak footprint (MiB) | Largest peak RSS (MiB) |
| --- | ---: | ---: | ---: | ---: |
| `prepare` | 104.24 | 101.43–106.11 | 9.47 | 14.92 |
| `render` | 907.63 | 904.48–927.94 | 83.05 | 95.92 |
| `document` | 908.43 | 900.88–913.56 | 82.99 | 95.89 |
| `scan` | 175.83 | 175.17–176.94 | 16.92 | 27.53 |
| `project` | 237.02 | 234.92–239.62 | 20.13 | 31.05 |
| `cancel-document` | 105.20 | 104.82–105.58 | 9.97 | 16.47 |
| `cancel-scan` | 6.43 | 6.40–6.43 | 3.64 | 14.31 |
| `replace-project` | 117.84 | 113.47–119.50 | 4.27 | 15.22 |

All 48 probe processes completed with expected output counts and nominal thermal state (`0`). There are **40 measured samples plus 8 discarded warm-ups**. The `project` total includes its separately timed search; cancellation/replacement totals are not normal processing times.

Separate model search median: **4.61 ms**, 500 matches. Document cancellation median from actual request to completion: **99.06 ms**; all five requests preceded completion and published zero blocks, with no error. Preparation continued until its existing outer cancellation check. Scan cancellation median: **0.075 ms**; all five returned `CancellationError`. Replacement project ready median: **3.84 ms**; the small root remained active through each 100 ms settling observation.

| Large-folder app workload | Median time (ms) | Measured range (ms) |
| --- | ---: | ---: |
| Launch to small reader | 1800.29 | 1776.01–4057.37 |
| Search to visible matching outline row | 3247.68 | 3183.79–11723.69 |

The large-folder UI test passed all six iterations (one warm-up/five measured); the largest measured app peak was **102.45 MiB**. All windows were **1252 × 833 points**, thermal state nominal. The external observer matched all six fresh PIDs, with 96–280 successful reads per measured app; one ESRCH exit race was allowed, and no permission error occurred. Search run 4 took 11.72 seconds and launch run 5 took 4.06 seconds; both remain in the evidence. Desktop activity and synthesized-event/accessibility polling costs are uncontrolled. This variability makes a single later UI comparison near 20% inconclusive without investigation/repetition; these numbers are not parser-only timings.

**Original XCTest dense-document result: failed.** The final original observation did not recognize the heading after **30.77 seconds** from click invocation; the retained screenshot still shows Loading. Its largest observed app peak was **1.246 GiB**, including automation/diagnostic/termination-side activity. This is not a clean document-processing peak or a valid successful time median. That XCTest route supplied no successful five-run dense-reader baseline; the later external native route below is a distinct measurement.

Verification: **106 Debug unit functions / 109 executions passed**, zero failures/skips, including all 92 compatibility fixtures. **All 8 existing Release UI tests passed**, and both new performance tests skipped correctly without opt-in flags. The combined Release invocation itself exited 65 because its unit bundle could not load; it is not an all-suite PASS. Debug unit retry exited 0. The dedicated large-folder performance test exited 0; the separate dense observation exited 65. That failure remains in the initial record; the follow-up below resolves the missing measurement endpoint. Signature verification (`codesign --verify --deep --strict --verbose=2`) passed for the measured Release app and Debug unit host. No Swift source compiler warnings were found; Xcode emitted its existing Simulator/AppIntents notices. The dense OCR diagnostic also logged OS text-recognition model fallback messages; its screenshot, not OCR alone, establishes the inspected Loading state.

The generator produced an identical manifest in an independent temporary directory. Negative controls changed README bytes and added an extra empty directory; verification rejected both. The UI summarizer joins every fresh PID to successful kernel reads and validates run order/window size. Source/tooling identities and raw summary arithmetic were audited; local document links/anchors and whitespace passed. Supervisor reviewed the probe, generator, observer, UI test and retained screenshots. Production source/settings, app version, compatibility corpus and semantic unit assertions remain unchanged.

## Reproduction

Run from the repository root on the identified Mac/toolchain. Use unused fixture/results/bundle/observer-stop paths when preserving another run; the generator and observer refuse existing input/stop locations. Close other Marky copies and keep the desktop available for the UI test. Do not run compilation or other test suites during timed measurements.

```bash
python3 tools/performance/fixtures.py generate /tmp/MarkyT02S2Fixtures
python3 tools/performance/fixtures.py verify /tmp/MarkyT02S2Fixtures

xcrun swiftc -O -whole-module-optimization -swift-version 6 \
  -strict-concurrency=complete -default-isolation MainActor \
  -enable-upcoming-feature MemberImportVisibility -target arm64-apple-macos26.2 \
  -module-cache-path /tmp/MarkyT02S2ModuleCache -parse-as-library \
  -o /tmp/MarkyT02S2Probe \
  $(rg --files Marky -g '*.swift' | rg -v 'MarkyApp.swift') \
  tools/performance/Probe.swift

xcrun swiftc -O -swift-version 6 -target arm64-apple-macos26.2 \
  -module-cache-path /tmp/MarkyT02S2ModuleCache -parse-as-library \
  tools/performance/MemoryWatch.swift -o /tmp/MarkyT02S2MemoryWatch

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MarkyT02S2 \
  -enableCodeCoverage NO build-for-testing ENABLE_TESTABILITY=YES \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

python3 tools/performance/fixtures.py measure /tmp/MarkyT02S2Fixtures \
  --probe /tmp/MarkyT02S2Probe --results /tmp/MarkyT02S2-probe-record.json

/tmp/MarkyT02S2MemoryWatch \
  /tmp/MarkyT02S2/Build/Products/Release/Marky.app/Contents/MacOS/Marky \
  /tmp/MarkyT02S2-folder-memory.stop > /tmp/MarkyT02S2-folder-memory.json &
marky_memory_pid=$!
TEST_RUNNER_MARKY_PERFORMANCE_ROOT=/tmp/MarkyT02S2Fixtures \
  xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MarkyT02S2 \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /tmp/MarkyT02S2-UI-folder-observed.xcresult \
  test-without-building -only-testing:MarkyUITests/LargeInputPerformanceTests/testFixedLargeFolder \
  ENABLE_TESTABILITY=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  > /tmp/MarkyT02S2-ui-folder-observed.log 2>&1
touch /tmp/MarkyT02S2-folder-memory.stop
wait "$marky_memory_pid"
python3 tools/performance/fixtures.py summarize-ui /tmp/MarkyT02S2Fixtures \
  --log /tmp/MarkyT02S2-ui-folder-observed.log \
  --memory /tmp/MarkyT02S2-folder-memory.json --results /tmp/MarkyT02S2-ui-final.json
```

The separate XCTest dense observation failed on this baseline. It uses a separate invocation of the same external observer:

```bash
/tmp/MarkyT02S2MemoryWatch \
  /tmp/MarkyT02S2/Build/Products/Release/Marky.app/Contents/MacOS/Marky \
  /tmp/MarkyT02S2-dense-memory.stop > /tmp/MarkyT02S2-dense-memory.json &
marky_memory_pid=$!
TEST_RUNNER_MARKY_PERFORMANCE_ROOT=/tmp/MarkyT02S2Fixtures \
TEST_RUNNER_MARKY_PERFORMANCE_DENSE=1 \
  xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MarkyT02S2 \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /tmp/MarkyT02S2-UI-dense-final.xcresult \
  test-without-building -only-testing:MarkyUITests/LargeInputPerformanceTests/testDenseDocumentObservation \
  ENABLE_TESTABILITY=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  > /tmp/MarkyT02S2-ui-dense-final.log 2>&1
touch /tmp/MarkyT02S2-dense-memory.stop
wait "$marky_memory_pid"
```

Always signal/wait for the observer after the test, including failed runs. Preserve the nonzero dense-test result; do not count the later `touch`/`wait` exit status as test success. The observer must be running before launching the app. `MARKY_DENSE_OBSERVATION` identifies the PID to join with its memory record. The helper's 50 ms loop retrieves a kernel lifetime high-water mark; it does not estimate peaks by sampling current RSS.

The runner sets `MARKY_UI_TEST_SEED=1` for probe child processes solely to select the existing isolated test-preferences behavior. It does not call seed/bootstrap or replace loaders. Each model instance owns/cleans its random test defaults suite. The UI test uses the existing seed/test-defaults path; user bookmarks/favorites are not used. Without `TEST_RUNNER_MARKY_PERFORMANCE_ROOT`, the large-folder test skips; the dense test also requires `TEST_RUNNER_MARKY_PERFORMANCE_DENSE=1`. Neither runs as part of ordinary UI regression.

## Retained failures and limits

Two earlier Release UI executions selected the **same** LARGE file, then queried `reader.staticTexts["Large Reading Fixture"]`. Both failed with **“Failed to get matching snapshots: Timed out while evaluating UI query”** after about 60 seconds. This is neither a successful 60-second load nor evidence that parsing took 60 seconds. The second attempt's two-second `/usr/bin/sample` trace has all **997 sampled main-thread stacks** under XCTest snapshot matching → AppKit accessibility children → SwiftUI accessibility/focus responder traversal. The sample reported roughly **1.0 GiB physical footprint**. This attributes that sampled interval to accessibility work; it does not prove there were no layout costs elsewhere. The same input is retained, and visual timing does not close large-document accessibility acceptance.

Failed bundles: `/tmp/MarkyT02S2-UI.xcresult` and `/tmp/MarkyT02S2-UI-diagnostic.xcresult`; trace `/tmp/MarkyT02S2-native-sample.txt`. The durable record retains the failure wording and sampled call-chain summary rather than depending on those paths. The subsequent nominal 120-second visual attempt also failed to recognize the heading. A bounded 30-second diagnostic and the final dense observation retained screenshots; both inspected captures still show Loading. Final bundle: `/tmp/MarkyT02S2-UI-dense-final.xcresult`. At that checkpoint, the full-project native/automation cause was not fully isolated. A separate untimed signed non-test single-file check displayed first content, as detailed below; it is not a comparable five-run baseline. No production fix is included. At that checkpoint B05 blocked a comparable dense-reader full-app baseline and later native parity/accessibility acceptance; it is not permission to substitute model timings for the missing app result.

### Untimed native isolation check

After the timed runs/regression checks, a **temporary isolated copy of the unchanged S1 Release app** was given bundle ID `rocks.toodear.Marky.PerformanceBaseline` and re-signed ad hoc with the original four entitlements (sandbox, user-selected read-only files, network client and get-task-allow). No test-only filesystem/Mach exceptions or XCTest injection were added. Strict signature verification passed. Original S1 executable SHA-256 before re-signing: `471660af7e2dc91b30d26d9df6233eb5f3a54bbb34e2ac6cae3b0257fdd985e0`; re-signed executable: `4cede5d308f21d0bb8e21fb7fe52327a7ecf8b454d59451120b06a93462c15bd`, CDHash `ad35348da104829a618662934e13eb428f8d5495`. Re-signing changes signature bytes; app sources were not edited.

Using native Open File/Go to Folder, the same `project/LARGE.md` was picked. The supervisor **observed Large Reading Fixture, Section 0000 and formatted prose in the actual native window**. The sidebar contained only LARGE.md (single-file scope), and the window differed from the full-project test window. CUA accessibility inspection was slow/incomplete, including a no-windows-available response during the transition, but its later screenshot showed the reader content. The isolated copy was quit and its process absence verified; the ordinary app's bookmark/favorites domain was not used. The native file panel added `project/.DS_Store` **after all timed runs**. Final fixture verification caught this extra OS metadata; only that generated temporary file was removed, restoring the original exact inventory/bytes. No measured sample used the changed inventory.

This narrows B05 to a **measurement/automation/opening-conditions question**, not an established failure to render the document in all native conditions. Several variables differ: no XCTest injection, non-testable S1 Release binary, separate bundle ID/defaults, native file-only grant instead of the full-project seed, and window geometry. There is **no processing-time median or peak-memory result from this single-file check**, no causal attribution to one changed variable, no restoration claim and no B05 closure from that check alone. The full-project follow-up below supplies the missing measurement without a frontend fix.

The first restricted probe compilation failed because Xcode macro sandbox execution was unavailable; execution-access retry passed. Initial Release `build-for-testing` attempts failed because the scheme's unit targets import a Release module without testability; limiting `-only-testing` did not avoid building that target. The explicit testability override resolved this without changing project settings. Coverage was then explicitly disabled before final measurements. A first large-folder run reached its endpoint but failed direct `proc_pid_rusage` from the sandboxed UI runner (`-1`); the external observer resolved this collection route, with all six PIDs verified. The full Release regression invocation later passed the eight existing UI tests and correctly skipped both new opt-in tests, but failed loading the unit bundle because ad-hoc Release library validation reported different Team IDs. Units were therefore run separately in the repository's normal Debug configuration; no measured binary or security setting was changed to bypass that failure. Existing iOS Simulator service and no-AppIntents notices are unrelated to the selected native macOS destination. Keep failed attempts distinct from measured samples.

Normal regression commands, run after measurements:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MarkyT02S2 \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /tmp/MarkyT02S2-Regression.xcresult \
  test-without-building -only-testing:MarkyTests -only-testing:MarkyUITests \
  ENABLE_TESTABILITY=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MarkyT02S2Debug \
  -enableCodeCoverage NO -resultBundlePath /tmp/MarkyT02S2-Unit-Debug.xcresult \
  test -only-testing:MarkyTests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

The fixtures measure one fixed mixed document/tree, not every size/syntax distribution, network/image decoding, cold I/O, unavailable volumes, signed grant restoration, full scroll-through, VoiceOver or long-session memory growth. The default preparation loop has no internal cancellation polling; do not treat silent cancellation as prompt resource release. Project replacement's 100 ms observation is bounded, not a proof that all obsolete OS work has completed.

### Repeatable full-project native visual endpoint

The follow-up uses [NativeReaderProbe.swift](../../tools/performance/NativeReaderProbe.swift), outside XCTest, with the **same Release app executable** and its existing test-only entitlements. NSWorkspace launches a fresh app with the original full-project seed, Light/all-system/default settings and **1252 × 833-point** window. Production sources, app identity, signature, input bytes and project scope are unchanged. The driver verifies Ready Fixture, scrolls the real native sidebar to visually locate LARGE.md, and posts a native CGEvent click. No accessibility API is called by this driver, and no XCTest bundle is injected. The user explicitly approved this input/screenshot driver on 2026-11-06. It requires existing macOS event-posting and window-capture permissions; it does not request or change privacy settings.

Timing begins immediately before posting the click, **after sidebar positioning**, and ends after a Marky-only window capture is recognized as containing both **Large Reading Fixture** and **Section 0000** in the reader. This includes real document read/decode, preparation, attributed rendering, view publication/layout and screenshot/OCR observation overhead. It excludes project startup/scan and sidebar positioning, which are setup here and measured separately above. It is a first-visible-viewport endpoint, not a full scroll-through. The driver uses Vision's `.fast`, en-US recognition with language correction off, at nominal 250 ms intervals. It records the last absent capture start and first successful capture start as well as confirmation time. These are observation timestamps, not exact pixel-presentation instants. The nominal observation limit is 60 seconds; synchronous capture/OCR may overrun it. An outer 600-second subprocess limit bounds the six-run command.

The external, unchanged MemoryWatch starts before app launch and joins all six fresh app PIDs. Its 50 ms kernel high-water observations include startup, scan, document display, a 250 ms post-endpoint hold and observed shutdown activity. Driver/OCR memory is a separate process and excluded from app peaks. The driver releases OCR temporaries after each capture and records its own cumulative kernel peak as a diagnostic. Keep the same driver, polling, recognition mode, frame size, build, preferences, project scope, warm-up/run count and thermal conditions for T17. This replaces the **missing** successful dense baseline; it does not turn an earlier XCTest failure into a timing sample or establish accessibility usability.

Reproduce after compiling, with other Marky copies closed and the desktop available. Use new output, stop, log and result paths. The Python wrapper always stops/waits for the observer and preserves a failed driver status. Keep failed captures/results distinct from successful samples.

```bash
xcrun swiftc -O -swift-version 6 -strict-concurrency=complete \
  -target arm64-apple-macos26.2 -module-cache-path /tmp/MarkyT02S2ModuleCache \
  -parse-as-library tools/performance/NativeReaderProbe.swift -o /tmp/MarkyB05ReaderProbe

python3 tools/performance/fixtures.py verify /tmp/MarkyT02S2Fixtures
python3 - <<'PY'
import pathlib, subprocess
output = pathlib.Path('/tmp/MarkyB05-Native-repeat')
stop = pathlib.Path(str(output) + '.stop')
assert not output.exists() and not stop.exists()
app = '/tmp/MarkyT02S2/Build/Products/Release/Marky.app'
with open(str(output) + '-memory.json', 'w') as memory, open(str(output) + '.log', 'w') as log:
    observer = subprocess.Popen(['/tmp/MarkyT02S2MemoryWatch', app + '/Contents/MacOS/Marky', str(stop)], stdout=memory)
    try:
        result = subprocess.run(['/tmp/MarkyB05ReaderProbe', app, '/tmp/MarkyT02S2Fixtures', str(output)],
                                stdout=log, stderr=subprocess.STDOUT, timeout=600)
    finally:
        stop.touch()
        observer_status = observer.wait(timeout=15)
    raise SystemExit(result.returncode or observer_status)
PY
python3 tools/performance/fixtures.py summarize-native /tmp/MarkyT02S2Fixtures \
  --log /tmp/MarkyB05-Native-repeat.log --memory /tmp/MarkyB05-Native-repeat-memory.json \
  --results /tmp/MarkyB05-Native-repeat.json
```

The final series (one warm-up/five measured fresh apps) passed with **median 14,801.92 ms**, measured range **11,929.95–14,861.29 ms**, and maximum observed app peak **2,223,901,360 bytes / 2.071 GiB**. All six windows matched 1252 × 833 points; all thermal samples were **fair (`1`)**, unlike the earlier nominal probe/folder samples. Every measured PID had 303–360 successful memory reads; two ESRCH exit races were retained, with no permission failures. The driver peak was **81,920,816 bytes / 78.13 MiB**, separately excluded from app peaks. Supervisor inspected all six endpoint captures: heading, Section 0000, prose, lists, table and code were visible. Final app-only captures: `/tmp/MarkyB05-Native-v2/run-0-after.png` through `run-5-after.png`; hashes are in the durable record.

A preceding exploratory six-run native series also succeeded, but drifted from 11.74 to 21.62 seconds (median 17.14 seconds). A subsequent CPU snapshot found several unrelated Node workers consuming most cores; a second snapshot showed that batch gone before the final series. Other desktop activity remained uncontrolled. The final driver also bounds temporary OCR allocations with an autorelease pool and records its own memory. These changes were combined for measurement hygiene, so no single causal attribution is made. Both series remain in the native JSON; only the final series supplies the selected baseline. Its range is still about 25% from smallest to largest. The endpoint is repeatably reachable, but a later comparison near the 20% gate needs repetition/investigation under matched conditions; this is not a precise parser timing or a claim of laboratory stability.

The original XCTest repro failed again at **74,160.16 ms**, screen Loading; its blocking click exceeded the nominal observation deadline. A two-second sample placed all **974 main-thread samples** under NSHostingView layout → SwiftUI accessibility focus-update/responder traversal. A separate same-app/full-project NSWorkspace launch without XCTest injection, driven by CUA, also timed out in AX/window inspection; its later one-second sample placed **540 main-thread samples** under accessibility focus-update actions. The CGEvent/window-capture route then supplied six successful final endpoints without changing app bytes, folder scope, geometry or settings. This establishes a working measurement route and demonstrates that removing XCTest injection alone is insufficient. It does **not** prove that every difference is caused by one API, fix the accessibility traversal, or establish VoiceOver behavior. Remaining accessibility/native acceptance is **B06**, owned by T12; it is separate from the completed visual baseline.

Follow-up checks: final driver and external observer exited 0; optimized Swift 6 strict-concurrency compilation emitted no warnings; signature and exact fixture inventory/bytes passed. Negative controls for an invisible endpoint, duplicate PID, missing memory and wrong geometry all rejected output. The modified summarizer reproduced the original folder JSON exactly. Original record SHA-256 stayed `4a3ec80fdc8ece1446b9bd6c516ffbfc7f011beb99895d49e12ba2311890e9a5`; production/test/settings trees and measured app hash remained unchanged. Unit/UI regression suites were not rerun for this tooling-only follow-up; E17's same-source evidence retains its original limits. No restoration, complete-document navigation or accessibility acceptance is claimed.

The summarizer requires six ordered fresh processes, a discarded first warm-up, positive observed peaks with multiple reads, matching geometry, both visible endpoint assertions and ordered capture timestamps. Only ESRCH exit races are allowed. Endpoint screenshots remain temporary app-only review artifacts; raw values and durable conclusions live in the linked JSON/report.

## Comparison and handoff

T02.S2 and T02 are **accepted/done**: the user reported **PASS** ("pass") on 2026-11-06 for the final E18 candidate; E19 records acceptance. The final native series supplies the dense full-app median/peak that B05 lacked; the blocker is resolved for measurement. B06 retains the unresolved accessibility traversal for T12 native acceptance. No production change was needed for the measurement. The raw records retain their measurement-time status; STATUS owns subsequent acceptance and integration. Accepting the baseline does not pass the future replacement regression gate or native accessibility acceptance. User PASS authorizes commit, local main merge, main push and merged task-branch cleanup under repository policy; executed operations are recorded separately in STATUS. T02.S1 evidence remains valid with its original scope.

T17.S3 must preserve **v1 bytes, identities, scenario order, one warm-up/five measured fresh processes, optimized flags, memory definitions, appearance/typography, window size and large-folder UI endpoint**, plus the native driver/endpoint and its fair thermal state for dense-document comparisons. Recompile the probe's entry points against the integrated production implementation; a renamed adapter is not permission to omit read/decode/native rendering/publication/layout. Carry forward all original metrics and cancellation outcomes. Explain unavoidable endpoint/build/hardware changes and keep incomparable results open.

Under the [approved contract](CONTRACT.md#verification-and-performance), compare each processing-time median and maximum measured process peak against **baseline × 1.20**. Evaluate semantic and full model/app costs separately so moving work into the native adapter cannot hide a regression. Large-folder UI numbers contain automation overhead; investigate variability near the gate rather than asserting parser speed from them. The future replacement comparison and regression gate remain open under OWE-T02; a baseline alone does not pass that gate. Accessibility failures remain a separate native acceptance obligation.

The accepted T02.S2 candidate is authorized for integration under repository Git policy; STATUS records actual execution. The next roadmap selection is T03.S1, not started by this acceptance. Preserve B06 and OWE-T02 for their named consumers. Any future native presentation fix must be reviewed explicitly and applied consistently to baseline/replacement candidates with affected measurements revalidated. Neither accepting this report nor changing the observation route waives the 20% gate.
