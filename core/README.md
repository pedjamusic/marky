# Marky core

Standalone C++20 static-library scaffold. The macOS app still uses its existing Swift implementation; this build does not compile or run Swift, Xcode targets, or Apple frameworks.

## Build and test

Requires CMake 3.20 or newer, a C++20 compiler and a build tool supported by the selected CMake generator. Only the toolchain recorded in the [S1 evidence](../docs/core-rewrite/T03-S1-CORE-BUILD.md) has been executed; the minimum CMake version is declared, not separately tested.

From the repository root, using a single-configuration generator:

```sh
cmake -S core -B /tmp/MarkyCore-Debug -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/MarkyCore-Debug
ctest --test-dir /tmp/MarkyCore-Debug --output-on-failure --no-tests=error

cmake -S core -B /tmp/MarkyCore-Release -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/MarkyCore-Release
ctest --test-dir /tmp/MarkyCore-Release --output-on-failure --no-tests=error
```

Keep build directories outside the source tree. For a multi-configuration generator, select the configuration with `cmake --build ... --config Debug` and `ctest ... -C Debug` (likewise for Release); T03.S2 owns platform configurations and execution procedures.

`marky_core` is explicitly `STATIC`. Its production source list is explicit in [CMakeLists.txt](CMakeLists.txt); test sources are a separate executable. C++20 is required and compiler language extensions are disabled. There are no fetched packages, generated data downloads, third-party test frameworks or third-party runtime libraries. `-DBUILD_TESTING=OFF` builds just the archive.

## Harness failure check

The test executable uses ordinary runtime checks and returns `EXIT_FAILURE` for a failed check. It does not depend on C/C++ `assert`, which may be disabled in Release. The test-only environment variable below deliberately fails a check through the same reporting path:

```sh
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 \
  ctest --test-dir /tmp/MarkyCore-Debug --output-on-failure --no-tests=error
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 \
  ctest --test-dir /tmp/MarkyCore-Release --output-on-failure --no-tests=error
```

Both commands **must fail**, print `FAIL: intentional harness failure`, and return nonzero. Run the ordinary CTest commands afterward to confirm the failure injection was temporary. CTest normally maps zero to pass and nonzero to failure; see the official [add_test documentation](https://cmake.org/cmake/help/latest/command/add_test.html). No `WILL_FAIL` inversion hides these failures.

## Source scope

- `src/BuildInfo.cpp` and its private header supply one internal link probe. Calling it from the test executable proves that production code in the archive is actually linked and compiled in C++20 mode. It uses `_MSVC_LANG` where available because MSVC can leave `__cplusplus` at its legacy value.
- `tests/CoreTests.cpp` supplies the smoke check and deliberate failure path. Failure injection exists only in the test executable, never the library.
- There is no public core interface yet. T04 supplies the C-compatible declarations, ownership and document semantics; replace the bootstrap probe when those real calls can prove linkage. Do not treat the private C++ header as the Swift seam.

No Markdown fixture has been ported or run by this scaffold. Parser compatibility, SwiftPM/Xcode integration, Windows/MSVC and Linux/GCC execution, and final dependency inspection remain in their named roadmap slices. See [the phase definition](../docs/core-rewrite/phases/02-core-and-swift-seam.md), [contract](../docs/core-rewrite/CONTRACT.md#build-and-portability) and [live ledger](../docs/core-rewrite/STATUS.md).
