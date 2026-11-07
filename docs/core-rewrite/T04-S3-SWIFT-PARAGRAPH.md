# T04.S3 Swift value adapter and native paragraph proof

The Mac test host sends a Swift string through the [C document interface](../../core/include/MarkyCore.h), receives owned Swift text, and displays it in a native AppKit text control in a hosted integration test. The existing Swift reader remains the selected production path through T12. This slice adds no parser selection, UI route, syntax, dependency, file access or version change.

## Swift interface

- Add one app-internal adapter with one async parse operation accepting a `String` and returning an immutable `Sendable` Swift document value. Its paragraphs are owned Swift strings in block order. Empty input produces zero paragraphs. All nonempty input produces one literal paragraph under the current core contract.
- Keep the interface independent of SwiftUI, AppKit, URLs and raw C declarations. Use explicit non-main-actor isolation for the value and worker under the app's MainActor default. Start the worker off the main actor and preserve cancellation from the calling task. Keep all C document handle and view access within a synchronous worker scope.
- Borrow UTF-8 bytes by length, including bytes after an embedded NUL. Use the returned paragraph view and its byte count while the document is alive. Decode strictly and copy into owned Swift storage. Preserve the exact UTF-8 sequence, including decomposed Unicode and line endings. Release each acquired document once via scoped cleanup before returning or throwing. Treat an unexpected result, view, status or malformed UTF-8 from the core as a typed internal failure.
- Map invalid arguments, allocation failure and internal failure to Swift error categories. Map cancellation from Swift or the core to `CancellationError` so callers can treat it as silent cancellation. Keep payloads free of paths and source text.
- Give each operation its own C cancellation token. Forward task cancellation with a cancellation handler and make the token's owning reference survive both worker use and any overlapping request. Immutable ownership around the documented thread-safe request operation is the only justification for unchecked sendability. Check Swift cancellation before starting and again after copying so a task observing cancellation at the publication point throws even if the C call won the race. Handle release must cover cancellation and failure.

## Native proof

Use a hosted `MarkyTests` integration test. Await the real adapter, then construct a standard `NSTextField` label on the main actor using an attributed string from the returned paragraph. Assert the label's attributed text matches the fixture byte for byte. This uses the AppKit SDK's native label initializer and inherits the system control's behavior. Keep the proof in the test target. [AppKit label initializer](https://developer.apple.com/documentation/appkit/nstextfield/init(labelwithattributedstring:)), [Apple macOS HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards).

## Verification

- Exercise empty input, exact length-delimited transfer with decomposed Unicode, non-ASCII text, emoji and an embedded NUL, native label consumption, already-cancelled work, and overlapping independent operations. Verify text after the worker returns. Compare UTF-8 bytes because Swift string equality permits canonical equivalence.
- Check actual handle cleanup across the Swift adapter. Use a disposable instrumented or leak-checking build with a deliberate missing-release control to demonstrate that the check detects an omitted release. Keep diagnostics, counters and fault seams out of the delivered app and production core. T04.S2's standalone checks remain the core-level evidence for mid-call cancellation and injected failures.
- Run Xcode Debug with the focused proof and full MarkyTests suite, and build Release with the local package. Inspect link inputs and runtime dependencies to confirm that Xcode uses the static core. Run the existing focused sidebar selection and document reading smoke. Record commands, exact candidate and limits in the evidence and status ledger.
- The hosted proof covers the language interface and native text handoff. Acceptance is review of the adapter and executed evidence. Full reader parity, sandbox restoration and Windows/Linux execution belong to their existing roadmap gates.

## Reviewed candidate and results

Prepared on 2026-11-07 in an isolated source snapshot of clean `main/1c304d759476306c97a71d048d74d5c2db4a46c4`. The [adapter](../../Marky/Services/CoreMarkdownParser.swift) and [hosted tests](../../MarkyTests/CoreMarkdownParserTests.swift) are the only build input additions. Review removed a check against the input length so the adapter consumes the core's semantic result and validates its returned view.

| Input or output | SHA-256 |
| --- | --- |
| `Marky/Services/CoreMarkdownParser.swift` | `a22b82e05044b4bc472f8def56934103eee2ebd65da5f9fea3a542764d8646f3` |
| `MarkyTests/CoreMarkdownParserTests.swift` | `bc70d908222ed45dc37ec16f657d6ad9e9a3d24ca02fd8058e792d0b95f33690` |
| Release `Marky.app/Contents/MacOS/Marky` | `e878c33808f2af007fcc92ed45c22dea21a1f0fac78766fdb68edd59bcb684d9` |

Executed on arm64 macOS 27.2 (26B123), Xcode 27.2 (27B52), macOS SDK 27.2, Apple Swift 6.4.2, Apple Clang 21.0.0 (clang-2100.4.1.1) and CMake/CTest 4.4.5. From the candidate root, set `checks` to a fresh writable output directory.

```bash
xcode_args=(-project Marky.xcodeproj -scheme Marky -destination 'platform=macOS,arch=arm64'
  -disableAutomaticPackageResolution -disablePackageRepositoryCache LD_GENERATE_MAP_FILE=YES)

xcodebuild "${xcode_args[@]}" -configuration Debug -derivedDataPath "$checks/xcode-debug" \
  -resultBundlePath "$checks/marky-debug.xcresult" -parallel-testing-enabled NO \
  -only-testing:MarkyTests \
  -only-testing:MarkyUITests/MarkyUITests/testSidebarSearchAndSelectionDisplaysDocument test
xcodebuild "${xcode_args[@]}" -configuration Release -derivedDataPath "$checks/xcode-release" build

for config in Debug Release; do
  cmake -S core -B "$checks/core-$config" -DCMAKE_BUILD_TYPE="$config" \
    -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)"
  cmake --build "$checks/core-$config" --parallel 3
  ctest --test-dir "$checks/core-$config" --output-on-failure --no-tests=error
done
```

- The Debug run passed 110 unit tests, including all four adapter tests, plus one sidebar selection and reader UI test. The result bundle reports 111 passing tests, zero failures and zero skips. Restricted execution initially stopped during SwiftPM cache writes. Both Xcode runs passed with normal local build and test access.
- Xcode compiled the local package in both configurations and passed `MarkyCore.o` once to each app link. The Debug app's `Marky.debug.dylib` contains the document create and release symbols. The Release link map attributes the create symbol to the static object. Runtime dependency and bundle inspection found no separate MarkyCore library.
- Release 0.2.4 (5) passed `codesign --verify --deep --strict`. Its entitlements include the app sandbox and user-selected read-only file access. The app is at `/tmp/MarkyT04S3.N9oa6l/checks/xcode-release/Build/Products/Release/Marky.app`. The reader UI smoke used the Debug test runner.
- Fresh standalone Mac Debug and Release builds each passed 2/2 CTest suites. The C interface, C++ source, build manifests and production reader are identical to the base revision.

### Handle lifetime and cancellation check

A disposable Swift executable compiled the unchanged adapter with `-swift-version 6 -strict-concurrency=complete -default-isolation MainActor -warnings-as-errors`. It linked a C++20 copy of `Document.cpp` with live-document and live-token counters, post-construction pause and failure injection. The probe sources and commands used the scratch area `/tmp/MarkyT04S3.N9oa6l/checks/lifetime`. Neither the candidate package nor the app contains this instrumentation.

- Success returned byte-identical Swift text after both handle counters reached zero. Empty input also left both counters at zero.
- Injected allocation and unexpected C++ failures after document construction produced the corresponding Swift errors. Accessor failure and malformed result bytes produced an internal failure. All paths left both counters at zero.
- A second parse completed independently while the first worker held a constructed C document and token. Cancelling the paused task requested its token, caused the C call to return cancellation and produced Swift `CancellationError`. Both counters returned to zero. The optimized probe passed 30 consecutive runs.
- In separate disposable Swift copies, removing document release, token release or cancellation forwarding each caused exit 1 with the matching failure diagnostic. The original probe passed again after the controls.

The user reported **PASS** ("pass") on 2026-11-07 for the reviewed adapter and executed proof. The four-file candidate was applied directly to clean `main` per the user's small-change workflow and matched the reviewed snapshot before acceptance bookkeeping. [Status and integration evidence](STATUS.md). The native proof checks the AppKit control's attributed text. Screen appearance, VoiceOver, sandbox restoration and production parser parity have separate acceptance gates. Linux/GCC and Windows/MSVC execution remain with B03/OWE-T03.
