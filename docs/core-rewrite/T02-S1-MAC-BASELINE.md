# T02.S1 — Current Mac baseline

Measured: 2026-11-06. Acceptance and Git execution are recorded separately in [STATUS](STATUS.md). This slice records the existing app's build and test baseline; fixed performance inputs and measurements belong to T02.S2.

## Candidate identity

- Source revision: `32c6451cc2cd13ec7ed73f859de66d2eae337782` (accepted T01 closeout).
- Working tree was clean before execution. Local branch `codex/t02-s1-mac-baseline` was created at that revision after explicit user authorization. The only candidate edits are this report, its phase discovery link and STATUS; app source, tests, assets, build settings and compatibility expectations remain unchanged.
- App version from project settings: **0.2.4 (5)**. The README's older version note is not the candidate identity.
- Source tree identities (`git rev-parse HEAD:<directory>`):

| Directory | Git tree |
| --- | --- |
| `Marky` | `dac6bed4de3733323395f61f12787630a0ef737f` |
| `MarkyTests` | `eb751867f68a6a47c80b82641d6c59d82e8b4c8f` |
| `MarkyUITests` | `ba7e28ce7410cc2b4d83dbf495cf19c54b0b99f2` |
| `Marky.xcodeproj` | `b5b6d34944c2d5b9671e6cefcc68d1ba2e598d3f` |

The 92-fixture [compatibility corpus](../../MarkyTests/Fixtures/markdown-compatibility.json) has SHA-256 `c66388eb8fb862dab8bf83c8f6c4d738dc978b6cf8ba09f5afbce21dd96eadb4`. Tests consume MD-001–MD-092 unchanged. UI fixtures remain defined in [MarkyUITests.swift](../../MarkyUITests/MarkyUITests.swift) and the [launch test](../../MarkyUITests/MarkyUITestsLaunchTests.swift); each seeded interaction run generates an app-owned fixture location.

## Environment and commands

- macOS **27.0.1**, build **26A434**, native **arm64** destination.
- Xcode **27.2 (27B52)**, macOS **27.2 SDK**; project deployment target **26.2**, Swift language mode **6.0**.
- Apple Swift **6.4.2**, `swiftlang-6.4.2.1.9 clang-2100.4.1.1`; Apple Clang **21.0.0**, `clang-2100.4.1.1`.
- Local ad-hoc signing: `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`. This is a local candidate, with no distribution/notarization claim.
- Debug and Release use separate newly created derived-data directories. The execution-access retry reused their partial compilation outputs from the failed restricted attempts. Builds ran concurrently; their elapsed times are not performance measurements.

Run from the repository root, following the [README commands](../../README.md) and [signed verification procedure](../CODE_QUALITY_VERIFICATION.md):

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MarkyT02S1 \
  -resultBundlePath /tmp/MarkyT02S1-Debug-Executed.xcresult \
  test -only-testing:MarkyTests -only-testing:MarkyUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

xcodebuild -scheme Marky -project Marky.xcodeproj -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MarkyT02S1Release build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

Console logs are `/tmp/MarkyT02S1-Debug-Executed.log` and `/tmp/MarkyT02S1-Release-Executed.log`. The explicit result-bundle path must be unused when reproducing a run; choose a fresh path for a justified rerun.

## Results

The execution-access Debug command exited **0**, `TEST SUCCEEDED`, on 2026-11-06, 14:10:32–14:12:03 Europe/Belgrade. The Release command exited **0**, `BUILD SUCCEEDED`.

| Check | Fresh result |
| --- | --- |
| Unit suite | **106 test functions / 109 executions** including parameters; both corpus checks and all 92 fixtures passed |
| UI suite | **8 tests passed**: seven interaction tests plus launch |
| Combined xcresult | **114 test functions / 117 executions**, zero failures, skips or expected failures |
| Release build | Passed, optimized arm64, version **0.2.4 (5)** confirmed in built Info.plist |
| Debug and Release signatures | Both passed `codesign --verify --deep --strict --verbose=2` |
| Screenshot review | Supervisor inspected table geometry, horizontal scrolling and launch attachments; fixture rows render, the last table row is visible and the scrolled eighth-column target is visible |

The xcresult summary reports 114 top-level tests and 117 device executions; the difference is the two parameterized functions' five total argument runs. The 92 corpus entries run within the production-corpus test, not as 92 separately counted test functions. No test result was skipped by the attachment export messages saying a test had no matching screenshot.

Release candidate: `/tmp/MarkyT02S1Release/Build/Products/Release/Marky.app`. Its executable SHA-256 is `471660af7e2dc91b30d26d9df6233eb5f3a54bbb34e2ac6cae3b0257fdd985e0`; bundle CDHash is `e056f9d1322cd829d521be5726f79028d21f8f70`. It is ad-hoc signed with hardened runtime and no TeamIdentifier. Signed entitlements contain app sandbox, user-selected read-only files, network client and the existing `get-task-allow`. They contain neither of the test-only temporary-exception keys. The Debug test app additionally contains absolute-path read-only `/` and test-manager Mach lookup exceptions; it must not be used as production sandbox evidence.

Reproduce report/signature inspection:

```bash
xcrun xcresulttool get test-results summary \
  --path /tmp/MarkyT02S1-Debug-Executed.xcresult --compact
xcrun xcresulttool get test-results tests \
  --path /tmp/MarkyT02S1-Debug-Executed.xcresult --compact
xcrun xcresulttool export attachments \
  --path /tmp/MarkyT02S1-Debug-Executed.xcresult \
  --output-path /tmp/MarkyT02S1-attachments --filter '*.png'
codesign --verify --deep --strict --verbose=2 \
  /tmp/MarkyT02S1Release/Build/Products/Release/Marky.app
codesign --verify --deep --strict --verbose=2 \
  /tmp/MarkyT02S1/Build/Products/Debug/Marky.app
codesign -dvvv /tmp/MarkyT02S1Release/Build/Products/Release/Marky.app
codesign -d --entitlements - \
  /tmp/MarkyT02S1Release/Build/Products/Release/Marky.app
shasum -a 256 \
  /tmp/MarkyT02S1Release/Build/Products/Release/Marky.app/Contents/MacOS/Marky
```

Summary/tree exports are also stored at `/tmp/MarkyT02S1-summary.json` and `/tmp/MarkyT02S1-tests.json`. Screenshots and their manifest remain in `/tmp/MarkyT02S1-attachments`; full-desktop attachments are not copied into the repository. Their conclusions and the reproducible commands above survive removal of temporary artifacts.

No Swift source compiler warnings appeared in the successful logs. Xcode logged the unrelated out-of-date iOS Simulator service, no-AppIntents metadata notices, debugger-version lookup and one UI display-rectangle diagnostic. The selected destination was native macOS and all tests passed; xcresult reports no runtime warnings. Initial restricted xcresult inspection also failed because it could not write its report cache; the authorized inspection/export retry succeeded without rerunning tests.

## Coverage and limits

The full unit suite covers Markdown preparation/rendering, the shared corpus, fonts, native outline behavior, project scanning, favorites, injected access lifetimes, failure preservation, cancellation and settings changes during suspended loads. UI tests cover search/selection, folder row/disclosure/collapse/keyboard interactions, nested-list indentation, table geometry/horizontal scrolling, and launch.

These are existing assertions, not new coverage. Passing injected scope/bookmark checks or seeded UI tests does not establish picker-granted sandbox restoration. The UI-test app receives Xcode test-only filesystem/automation exceptions. The separate Release candidate is the candidate for any real access acceptance.

No fresh manual picker/relaunch/restoration, unavailable-volume, remote-image/network, all-appearance/typography or large-input performance acceptance is claimed. Existing historical acceptance is not relabeled as this baseline. No app behavior or interaction changed, so S1 acceptance is review of this evidence and the focused documentation diff. A signed app alone does not prove restoration behavior.

The initial restricted-shell Debug test and Release build both exited **65** before tests: `sandbox-exec: sandbox_apply: Operation not permitted` prevented Swift macro expansion, producing missing macro and cascading compilation errors. Logs remain `/tmp/MarkyT02S1-Debug.log` and `/tmp/MarkyT02S1-Release.log`; the failed test bundle is `/tmp/MarkyT02S1-Debug.xcresult`. They are failed environment attempts, not passing tests or an established app defect. Both commands were retried with required execution access, without source or setting changes.

## Handoff

T02.S1 is **accepted/done**: the user reported **PASS** ("pass") on 2026-11-06 for E14 and the focused three-file documentation diff. E15 records acceptance separately from Git execution. The source revision, counts, signatures and limits above remain unchanged; no new app manual flow is claimed by this documentation-only delivery. Executed integration is recorded in STATUS. T02.S2 must establish its fixed inputs, timing medians, peak memory and cancellation observations on an identified comparable candidate; none are supplied by this slice. T12.S1 consumes the accepted baseline checks with their limits. T17.S3 consumes the later S2 measurement evidence under the contract's 20% regression gate. Windows/Linux execution discovery remains B03 and is unaffected.
