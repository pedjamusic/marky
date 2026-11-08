# Marky core

Standalone C++20 static library. The macOS reader still uses its existing Swift parser. The standalone build requires only the C++ toolchain and does not compile Swift, Xcode targets, or Apple frameworks.

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

- [`include/MarkyCore.h`](include/MarkyCore.h) is the C-compatible document interface. Creation borrows caller-validated UTF-8 and an optional cancellation token for the call. The result owns its bytes. Copy a view if it must outlive its document.
- [`src/Document.cpp`](src/Document.cpp) normalizes CRLF and returns ordered paragraphs, ATX and Setext headings, thematic breaks, literal code, lists, and quotes. Fenced code retains its literal lines. Indented code drops its required indentation and trailing blank lines. Paragraph source joins soft lines with spaces, keeps LF for hard breaks, and preserves backslashes for inline interpretation. Heading source is exposed with its level. An ATX opening space with a basic combining accent (U+0300–U+036F) leaves the line in prose. Thematic breaks ignore those accents when they attach to whitespace and carry empty text. The [T04.S2 spec](../docs/core-rewrite/T04-S2-FAILURES-AND-CANCELLATION.md) defines status handling and token lifetime.
- List blocks contain source-ordered items. Depth is the count of leading ASCII spaces and tabs divided by two, rounded down. Each item has a bullet, ordered marker with its original spelling, or explicit task state. Continuations retain LF and attach to the preceding item. Ordered markers and their separators use pinned Unicode 17.0.0 numeric and character boundary data. [Unicode data and license](src/ListCharacterProperties.h)
- Quote blocks contain source-ordered lines with a marker depth and prepared Markdown. A line with only quote markers keeps its depth and has empty source. An unmarked line ends the quote. Fences and indented code retain literal quote markers, and an indented list continuation can retain them as item source. Quote markers use the same pinned Unicode character boundary data as list markers. Inline parsing can use the line boundaries and depth when styles span multiple lines.
- [`src/LiteralSyntax.h`](src/LiteralSyntax.h) provides the private delimiter helpers. The code-span matcher reports the byte offset after a closing backtick run of exactly the opening length. Table and inline callers handle escaping outside the span and decide how to interpret a match.
- [`tests/CoreTests.cpp`](tests/CoreTests.cpp) links the production archive and tests ownership, argument handling, base blocks, list and quote semantics, code-span boundaries, cancellation, and parallel calls. The deliberate harness failure switch is confined to this executable.
- [`tests/DocumentFaultTests.cpp`](tests/DocumentFaultTests.cpp) builds the same implementation with private checkpoints to test exceptions, in-flight cancellation, and cleanup. The tests interrupt through the C API during an open fence, a list continuation, or an open quote, and before document allocation and publication. The production archives omit the checkpoints.

Windows/MSVC and Linux/GCC executions and final dependency inspection remain in their named roadmap slices. See the [phase definition](../docs/core-rewrite/phases/02-core-and-swift-seam.md), [contract](../docs/core-rewrite/CONTRACT.md#build-and-portability) and [live ledger](../docs/core-rewrite/STATUS.md).

## Xcode integration

[Package.swift](Package.swift) supplies the local, static `MarkyCore` product used by the Marky app target. Build the Marky scheme normally in Xcode. The package has no external dependencies and uses C++20. When adding or removing a production source, update both explicit source lists in `Package.swift` and `CMakeLists.txt`. The CTest executable stays separate.

SwiftPM exposes the C header from `include/`. The Swift proof adapter copies the typed blocks from this interface. `MarkyTests` runs the native paragraph proof and compares block kinds, heading levels, literal bytes, prepared source, list items, and quote lines against the shared fixtures.
