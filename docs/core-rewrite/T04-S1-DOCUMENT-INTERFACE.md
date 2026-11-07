# T04.S1 — C document interface and result lifetime

## Candidate

Prepared on 2026-11-07 in an isolated snapshot of clean `main/6a569764fd35e3ace7e7ff373d2197b8ab158174`. The verified source snapshot is at `/tmp/MarkyT04S1.w7SZTB/source`. After explicit branch approval, the verified patch was applied to `codex/t04-s1-document-interface` at that base. The build inputs on the branch match the verified snapshot. A fresh Debug build on the branch using the [manual CMake commands](../../core/README.md#manual-build-without-presets) with the explicit macOS SDK passed 1/1 CTest. Verification ran on macOS 27.2 (26B123), arm64, with Apple Clang 21.0.0 (clang-2100.4.1.1), CMake/CTest 4.4.5, Xcode 27.2 (27B52), macOS SDK 27.2 and Apple Swift 6.4.2.

| Build input | SHA-256 |
| --- | --- |
| `core/CMakeLists.txt` | `2377a5d47e2cd645d2e26f43ca8a4038490ae8bd066fdd59247222779e20363a` |
| `core/Package.swift` | `ae89fee1aabd744875aee90fab0dd307caa0a466602cce32f25b45f37449a0a0` |
| `core/include/MarkyCore.h` | `c3c090da23d91fd99e0258cae0a5884d42db2083e1c6c591479aa9d39cb72207` |
| `core/src/Document.cpp` | `a9e09aa891b2ac87226d53f1937c01aa6cfc125dadf987d3ec1bf65a8c1ebbda` |
| `core/tests/CoreTests.cpp` | `60322e41f0bca9888ebdb6800f220c122da3d2915ef65caa2ef988980c2ff1e1` |

## Interface

The [public C header](../../core/include/MarkyCore.h) specifies synchronous borrowing and explicit ownership. Creation accepts caller-validated UTF-8 by byte count. It returns an owned result containing one literal paragraph for nonempty input or zero blocks for empty input. Accessors expose the block count and a borrowed text view by index. Views expire when their document is released. Embedded NUL and decomposed Unicode are preserved byte for byte.

A failed call clears the supplied output slot. Creation translates allocation and other C++ exceptions into fixed-width status values. The [implementation](../../core/src/Document.cpp) keeps its immutable storage private and uses standard C++ cleanup. The real interface replaces the private T03 link probe in both manifests and the test executable.

## Verification

From `core/`, the [Mac presets](../../core/README.md#macos) passed 1/1 in fresh Debug and Release builds. Configure used the flags below for each preset. The deliberate failure path reported the expected message and CTest exit 8 in both configurations. Ordinary reruns passed 1/1.

```bash
for preset in macos-appleclang-debug macos-appleclang-release; do
  cmake --preset "$preset" -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  cmake --build --preset "$preset" --verbose
  ctest --preset "$preset"
  cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset "$preset"
  ctest --preset "$preset"
done
```

The [CTest executable](../../core/tests/CoreTests.cpp) checks that text survives mutation and expiry of the input, that a view survives a second result's creation and release, and that invalid arguments clear output. It covers both forms of zero-byte input, out-of-range access, and release. In a disposable copy, substituting `std::string_view` for the owned string caused the tests to fail with the input-aliasing and byte-preservation diagnostics (CTest exit 8).

An independent Debug build passed 1/1 with AddressSanitizer and UndefinedBehaviorSanitizer enabled. From the candidate root, `checks` refers to a writable output directory outside the source tree.

```bash
cmake -S core -B "$checks/asan" -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
  -DCMAKE_CXX_FLAGS='-fsanitize=address,undefined -fno-omit-frame-pointer -Wall -Wextra -Wpedantic -Werror' \
  -DCMAKE_EXE_LINKER_FLAGS='-fsanitize=address,undefined'
cmake --build "$checks/asan"
ASAN_OPTIONS=detect_stack_use_after_return=1 UBSAN_OPTIONS=halt_on_error=1 \
  ctest --test-dir "$checks/asan" --output-on-failure --no-tests=error
```

- A temporary C11 consumer compiled the header with `xcrun clang -std=c11 -Wall -Wextra -Werror -pedantic-errors -Icore/include -c`. Linking its object with `xcrun clang++` and the CMake Release archive passed. The executable verified the copied bytes of a buffer containing an embedded NUL, then released the result.
- `xcrun swift build --package-path core --scratch-path "$checks/swiftpm" --disable-dependency-cache --disable-sandbox --disable-automatic-resolution --product MarkyCore` produced a static archive. A temporary Swift executable target depending on that local product imported `MarkyCore` in standard Swift mode, without C++ interop enabled. It created an opaque result, read the exact Unicode and embedded-NUL bytes after editing the source, and released the result. It ran with the same SwiftPM flags via `xcrun swift run --package-path "$checks/swift-consumer" --scratch-path "$checks/swift-consumer-build" --disable-dependency-cache --disable-sandbox --disable-automatic-resolution Consumer`. For these standalone runs, `CLANG_MODULE_CACHE_PATH` pointed to a writable scratch directory. SwiftPM emitted user-cache access warnings in the restricted shell.
- The Xcode Debug build and all 106 Marky unit tests (109 runs including parameters) passed with zero failures and skips. Xcode resolved the local package, compiled `Document.cpp` as C++20 and listed the static arm64 object `MarkyCore.o` once in the app's linker inputs. The restricted shell blocked SwiftPM cache writes. Retrying with normal local build access and a fresh result bundle passed.

```bash
xcodebuild -project Marky.xcodeproj -scheme Marky -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath "$checks/xcode-debug" \
  -resultBundlePath "$checks/marky-unit-retry.xcresult" \
  -disableAutomaticPackageResolution -disablePackageRepositoryCache \
  -only-testing:MarkyTests test
```

## Acceptance and handoff

The user reported **PASS** ("pass") on 2026-11-07 for the applied C interface and automated ownership evidence. T04.S2 owns cancellation and injected failure/concurrency coverage. T04.S3 owns the Swift value adapter and native paragraph proof. T05 owns UTF-8 validation and line handling. The production reader continues to use its Swift implementation. Windows/MSVC and Linux/GCC execution remain open under B03/OWE-T03. The [live ledger](STATUS.md) records acceptance and Git authorization.
