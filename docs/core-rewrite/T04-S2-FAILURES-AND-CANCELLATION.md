# T04.S2 failure and cancellation specification

This slice extends the [T04.S1 C document interface](T04-S1-DOCUMENT-INTERFACE.md) under the [core lifetime contract](CONTRACT.md#boundary-and-lifetime). The Swift value adapter and native paragraph proof belong to T04.S3.

## C interface

- Keep the existing status values and append `MARKY_STATUS_CANCELLED`. Preserve `marky_document_create` as the entry point for callers that have no token. `marky_document_create_cancellable` takes an optional token and has the same input and result ownership rules.
- `marky_cancellation_token_create` returns an owned, initially active token. Its writable output slot is cleared on failure. `marky_cancellation_token_request` sets a sticky flag and is safe to call repeatedly from multiple threads. There is no reset. A null token disables cancellation, and requesting or releasing a null token has no effect.
- A token may be shared by overlapping calls. Each call borrows it until return. Its owner must wait for all borrowing calls and requesters to finish before releasing it once. Completed documents and their views are independent of the token. Concurrent operations must use separate output slots and keep each input buffer readable and stable for its call.
- Validate arguments first. On any non-success status, a supplied document output slot is null. For valid calls, check cancellation before copying input, after copying and before allocating the result, and before publishing the result. The literal paragraph uses one library copy. Cancellation is cooperative and cannot interrupt that copy. A request racing the last check may yield a complete result.
- Translate `std::bad_alloc` to `MARKY_STATUS_ALLOCATION_FAILURE` and unexpected exceptions to `MARKY_STATUS_INTERNAL_ERROR`. A failure raised during construction takes precedence over a later cancellation check. The local text and any unpublished result are destroyed before returning. No C++ exception crosses the C interface.

## Verification design

Use a private, CMake test-only build of the same document implementation to inject failures before token allocation, after the text copy, and after document construction. Pause a worker after the text copy and before publication to request cancellation from another thread at each stage. Count destroyed documents in the fault executable to verify cleanup after construction. Keep these checkpoints out of both production archives. Keep the ordinary CTest executable linked to the production archive.

Check that failure and cancellation clear output slots, subsequent calls succeed, repeated requests remain effective, shared tokens work across calls, and concurrent creates produce independent results with exact bytes. Use allocation and race sanitizers on the failure and concurrency cases. Compile and run C and Swift consumers against the production interface.

## Candidate

Prepared on 2026-11-07 from clean `main/5eb7a1b2bd6e2b6577e9b599061caa36846fc72a`. The isolated source is at `/tmp/MarkyT04S2.uI3OzT/source`. The verified patch is at `/tmp/MarkyT04S2.uI3OzT/T04-S2.patch`.

After branch approval, all nine applied files on `codex/t04-s2-failures-and-cancellation` matched the snapshot before handoff bookkeeping. The build inputs below are identical. Fresh [manual CMake builds](../../core/README.md#manual-build-without-presets) with the explicit macOS SDK and the same warning flags each passed 2/2 CTest in Debug and Release on the branch.

| Build input | SHA-256 |
| --- | --- |
| `core/CMakeLists.txt` | `868c7831bc4d9b1a2f035b1a8cec80ba48322c7d464fb22809c0360d00b8ddf0` |
| `core/CMakePresets.json` | `79796bf1f744050aa2b0b1bbbf3395f40f6f176b42fa9e0efd4b69db5cc52fa5` |
| `core/Package.swift` | `ae89fee1aabd744875aee90fab0dd307caa0a466602cce32f25b45f37449a0a0` |
| `core/include/MarkyCore.h` | `d4d4ff3e61688e6c3ca6bb2aef9ddd7520e5786d4e5a398dfed91f1bdc68ac24` |
| `core/src/Document.cpp` | `3fa1790f19f6b51c2b9b2c90f4c3a6815200087a6815f8b01ac932a767c29587` |
| `core/tests/CoreTests.cpp` | `3369a0326c0a4f733bb82ea09fccfee990d2e498e3410f6208feb384c6e3511b` |
| `core/tests/DocumentFaultTests.cpp` | `751c9e2843dbd53a9ac5158d520ba691f16ffe74df2082694315db6f43ba175a` |
| `core/tests/DocumentTestCheckpoints.h` | `d60e544572227832b9705a4044d4fd90756df338ca8f9bdd0635858048a7a662` |

## Verification results

Executed on macOS 27.2 (26B123), arm64, with Apple Clang 21.0.0 (clang-2100.4.1.1), CMake/CTest 4.4.5, Xcode 27.2 (27B52), macOS SDK 27.2 and Apple Swift 6.4.2. In the commands below, run from the candidate root and set `checks` to a writable output directory outside the source tree.

- The standalone Debug and Release presets each passed 2/2 CTest suites. Each deliberate harness failure returned CTest exit 8 with the expected diagnostic, then both suites passed again. Release passed 100 repeats of each suite.

  ```sh
  (
    cd core
    for preset in macos-appleclang-debug macos-appleclang-release; do
      cmake --preset "$preset" -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
        -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
      cmake --build --preset "$preset" --parallel 3
      ctest --preset "$preset"
      cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset "$preset"
      ctest --preset "$preset"
    done
    ctest --preset macos-appleclang-release --repeat until-fail:100
  )
  ```

- ASan/UBSan and TSan each passed 2/2. Apple Clang's AddressSanitizer reported that leak detection is unsupported on this host. A separate `leaks --atExit -- <executable>` check found zero leaks in the Debug fault executable and detected a deliberately leaked heap allocation in a probe. It required normal local process inspection access.

  ```sh
  for sanitizer in address,undefined thread; do
    cmake -S core -B "$checks/$sanitizer" -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
      -DCMAKE_CXX_FLAGS="-Wall -Wextra -Wpedantic -Werror -fsanitize=$sanitizer -fno-omit-frame-pointer" \
      -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=$sanitizer"
    cmake --build "$checks/$sanitizer" --parallel 3
    ASAN_OPTIONS=detect_stack_use_after_return=1 UBSAN_OPTIONS=halt_on_error=1 \
      TSAN_OPTIONS=halt_on_error=1 ctest --test-dir "$checks/$sanitizer" \
      --output-on-failure --no-tests=error
  done
  ```

- Three regression controls in disposable copies each failed with CTest exit 8. Removing the final cancellation check let a cancelled document escape. Dropping ownership before publication skipped destruction on both exception and cancellation. Replacing the atomic flag with a plain Boolean produced a TSan race in the production-linked parallel test.
- A strict C11 consumer compiled with `xcrun clang -std=c11 -Wall -Wextra -Werror -pedantic-errors -Icore/include -c`, linked with `xcrun clang++` against the Release archive, and ran successfully. A temporary Swift executable depending on the local package ran in standard Swift mode. Both checked successful creation, cancellation status, a cleared output slot, and exact bytes after releasing the token. The Swift fixture included decomposed Unicode, emoji, and an embedded NUL.
- The static SwiftPM archive built with `xcrun swift build --package-path core --scratch-path "$checks/swiftpm" --disable-dependency-cache --disable-sandbox --disable-automatic-resolution --product MarkyCore`. The temporary consumer used the same SwiftPM options with `swift run` and the local package dependency. `CLANG_MODULE_CACHE_PATH` pointed at a writable scratch directory. Symbol inspection with `nm` confirmed both archives contain the new interface and omit the test checkpoints and destruction observer.
- The Xcode Debug build and full `MarkyTests` suite passed. The restricted run stopped at SwiftPM cache writes. A retry with normal local build access and a fresh result bundle passed and compiled the arm64 static package object.

  ```sh
  xcodebuild -project Marky.xcodeproj -scheme Marky -destination 'platform=macOS,arch=arm64' \
    -configuration Debug -derivedDataPath "$checks/xcode-debug" \
    -resultBundlePath "$checks/marky-unit-retry.xcresult" \
    -disableAutomaticPackageResolution -disablePackageRepositoryCache \
    -only-testing:MarkyTests test
  ```

Windows/MSVC and Linux/GCC executions remain open under B03/OWE-T03.

## Acceptance and handoff

The user reported **PASS** ("pass") on 2026-11-07 for the applied core candidate and automated evidence. The [status ledger](STATUS.md) records acceptance and Git authorization. T04.S3 owns the Swift value adapter and native paragraph proof.
