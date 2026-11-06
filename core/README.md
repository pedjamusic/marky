# Marky core

Standalone C++20 static-library scaffold. The macOS app still uses its existing Swift implementation; this build does not compile or run Swift, Xcode targets, or Apple frameworks.

## Platform presets

Start each platform command block at the repository root; preset commands run in `core/`. [CMakePresets.json](CMakePresets.json) supplies matching configure, build and test names for each configuration. Presets require **CMake/CTest 3.21 or newer** (schema version 3); the manual build below retains the declared CMake 3.20 minimum. Neither minimum version has been separately executed. [S2 evidence](../docs/core-rewrite/T03-S2-PLATFORM-BUILDS.md) records actual executions and unavailable environments; configured presets do not establish portability.

| Host / compiler | Prerequisites | Debug / Release preset names |
| --- | --- | --- |
| macOS / Apple Clang | Xcode or Command Line Tools, macOS SDK, `make`; compiler `/usr/bin/clang++` | `macos-appleclang-debug`, `macos-appleclang-release` |
| Linux / GCC | C++20-capable GNU `g++`, standard C++ development libraries, `make` | `linux-gcc-debug`, `linux-gcc-release` |
| Windows / MSVC | Visual Studio 2022 or Build Tools with Desktop development with C++, v143 tools and a Windows SDK | `windows-msvc-debug`, `windows-msvc-release` |

macOS/Linux use `Unix Makefiles` and the host's native architecture. Windows uses the `Visual Studio 17 2022` generator, v143 and an **x64 target**; build/test presets explicitly select Debug or Release. All six configurations use separate ignored directories under repository `.build/core/<preset-name>/`, outside the `core/` source tree. Configure, build and test menus are restricted to the matching host. A host condition is not a compiler/toolchain availability check; confirm the configure log identifies **AppleClang**, **GNU**, or **MSVC** as intended. Apple's `g++` wrapper is not Linux/GCC evidence.

Use a fresh checkout/build directory when recording clean execution evidence. Do not reuse another compiler's cache. `cmake --list-presets=all` lists the available commands without executing them. No job is published or run remotely by these files.

### macOS

```sh
cd core
cmake --preset macos-appleclang-debug
cmake --build --preset macos-appleclang-debug --verbose
ctest --preset macos-appleclang-debug

cmake --preset macos-appleclang-release
cmake --build --preset macos-appleclang-release --verbose
ctest --preset macos-appleclang-release
```

If SDK discovery fails, add `-DCMAKE_OSX_SYSROOT=<absolute-installed-SDK-path>` to each configure command. Keep that machine-specific path out of the shared presets; record the selected SDK with the result. The S2 report gives the exact explicit-SDK commands used locally.

### Linux

```sh
cd core
cmake --preset linux-gcc-debug
cmake --build --preset linux-gcc-debug --verbose
ctest --preset linux-gcc-debug

cmake --preset linux-gcc-release
cmake --build --preset linux-gcc-release --verbose
ctest --preset linux-gcc-release
```

### Windows

Run in PowerShell on the prepared Windows host (a Visual Studio Developer PowerShell also provides tools for dependency inspection). Inspect `$LASTEXITCODE` immediately after each native command; it must be `0` for every normal configure/build/test step. Stop and retain the failure if any step fails.

```powershell
Set-Location core
cmake --preset windows-msvc-debug
cmake --build --preset windows-msvc-debug --verbose
ctest --preset windows-msvc-debug

cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release --verbose
ctest --preset windows-msvc-release
```

## Harness failure and recovery

Each test preset enables failure output and treats zero registered tests as an error. The executable uses ordinary runtime checks rather than C/C++ `assert`, which may be disabled in Release. After both normal configurations pass, deliberately fail the same test path in both. For example, on macOS:

```sh
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset macos-appleclang-debug
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset macos-appleclang-release
ctest --preset macos-appleclang-debug
ctest --preset macos-appleclang-release
```

Substitute `linux-gcc` or `windows-msvc` on those hosts; the same `cmake -E env` syntax works in PowerShell without leaving an environment override behind. The **first two commands must fail**, show `FAIL: intentional harness failure` and report the test failed (CTest exit `8` in the recorded Mac execution). Inspect `$?` in a POSIX shell or `$LASTEXITCODE` in PowerShell immediately after each command. A configure/missing-executable error is not a successful negative control. The final two ordinary commands must pass. CTest's normal zero/nonzero test mapping remains in effect; no `WILL_FAIL` inversion hides failures. See [official add_test documentation](https://cmake.org/cmake/help/v3.21/command/add_test.html).

## Execution record

For each real host run, retain the exact commands, exit codes and normal/failure/recovery summaries, plus:

- Candidate revision (`git rev-parse HEAD`), dirty state (`git status --short`) and hashes/diff of any uncommitted build inputs, including the preset file.
- OS version/build, host and target architecture, compiler path/ID/version, CMake/CTest versions, generator, SDK/toolset and Debug/Release configuration. On macOS use `sw_vers`, `uname -m`, `clang++ --version`; on Linux use `cat /etc/os-release`, `uname -m`, `g++ --version`; on Windows use `Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber` and record host architecture alongside the preset's x64 target. Keep the configure log and generated `CMakeFiles/<cmake-version>/CMakeCXXCompiler.cmake` for the exact compiler identity.
- Fresh configure and verbose build output, including C++20 flags, test counts and Release failure detection. Summarize results durably in the roadmap evidence; temporary logs alone are insufficient.
- For dependency inspection, retain archive members and executable runtime imports: `ar -t` / `otool -L` on macOS, `ar -t` / `readelf -d` on Linux, or `lib /list` / `dumpbin /dependents` from a VS developer shell on Windows. Standard compiler/OS libraries are allowed; record any unexpected dependency. Final T19 inspection must use the final candidate.

Configuration validation, cross-compilation, containers and native host runs must be labeled accurately. A Linux container run must identify its image/digest, Linux architecture and compiler; Docker installation on macOS alone is not execution. Missing Debug/Release smoke and failure/recovery runs stay named in B03/OWE-T03 until executed. No native Windows/Linux frontend is part of these tests.

## Manual build without presets

Requires CMake 3.20 or newer, a C++20 compiler and a supported build tool. From the repository root, with a single-configuration generator:

```sh
cmake -S core -B /tmp/MarkyCore-Debug -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/MarkyCore-Debug
ctest --test-dir /tmp/MarkyCore-Debug --output-on-failure --no-tests=error

cmake -S core -B /tmp/MarkyCore-Release -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/MarkyCore-Release
ctest --test-dir /tmp/MarkyCore-Release --output-on-failure --no-tests=error
```

Keep build directories outside `core/`. For a multi-configuration generator, use `cmake --build ... --config Debug` and `ctest ... -C Debug` (likewise Release). The manual route does not read the presets. [S1 evidence](../docs/core-rewrite/T03-S1-CORE-BUILD.md) records its original execution.

## Source scope

`marky_core` is explicitly `STATIC`. Its production source list is explicit in [CMakeLists.txt](CMakeLists.txt); test sources are a separate executable. C++20 is required and compiler language extensions are disabled. There are no fetched packages, generated data downloads, third-party test frameworks or third-party runtime libraries. `-DBUILD_TESTING=OFF` builds just the archive without presets.

- `src/BuildInfo.cpp` and its private header supply one internal link probe. Calling it from the test executable proves that production code in the archive is actually linked and compiled in C++20 mode. It uses `_MSVC_LANG` where available because MSVC can leave `__cplusplus` at its legacy value.
- `tests/CoreTests.cpp` supplies the smoke check and deliberate failure path. Failure injection exists only in the test executable, never the library.
- There is no public core interface yet. T04 supplies the C-compatible declarations, ownership and document semantics; replace the bootstrap probe when those real calls can prove linkage. Do not treat the private C++ header as the Swift seam.

No Markdown fixture has been ported or run by this scaffold. Parser compatibility, SwiftPM/Xcode integration, unexecuted Windows/MSVC and Linux/GCC tests, and final dependency inspection remain in their named roadmap slices. See [the phase definition](../docs/core-rewrite/phases/02-core-and-swift-seam.md), [contract](../docs/core-rewrite/CONTRACT.md#build-and-portability) and [live ledger](../docs/core-rewrite/STATUS.md).
