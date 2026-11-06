# T03.S1 — Independent C++20 build

Executed 2026-11-06. Acceptance and Git execution are recorded separately in [STATUS](STATUS.md). This slice establishes build plumbing; it does not implement a parser or integrate the core into the app.

## Candidate and source inventory

- Base: clean `main/d3780ba1fff0163eb8c0a47ceb0d594be565c255`.
- Verified candidate: uncommitted `codex/t03-s1-core-build` at E21, created with explicit user approval. Nine added/modified files: the five `core/` files below, root README, phase 02 discovery links, this report and STATUS.
- Production archive: `marky_core`, built from `core/src/BuildInfo.cpp`. Its private header declares one internal language-standard/link probe. No public interface or Markdown behavior is claimed. T04 replaces the probe once actual interface calls can prove linkage.
- Tests: `marky_core_tests`, built from `core/tests/CoreTests.cpp` and linked to the archive. The executable calls the non-inline production function; it does not compile another copy of that source.
- Build/usage: [CMake manifest](../../core/CMakeLists.txt), [private implementation](../../core/src/BuildInfo.cpp), [private declaration](../../core/src/BuildInfo.hpp), [harness](../../core/tests/CoreTests.cpp) and [commands](../../core/README.md).

SHA-256 identities of all executable/build inputs at verification:

| File | SHA-256 |
| --- | --- |
| `core/CMakeLists.txt` | `770be28237e8bf4d0466c9a4e6c057a73a5bf4abf8337edfb246dc8bb1486db5` |
| `core/src/BuildInfo.cpp` | `bd272540c6a3286465742aa92c6c53a70083b03c161d011b38eab413fd1bb56d` |
| `core/src/BuildInfo.hpp` | `ffd20dd3e11a3e9cb00197721e6bdfaed0e572df29073313aea6f8b8bd00d315` |
| `core/tests/CoreTests.cpp` | `a0969c5f0bb0bfc830d7ee3c52aa881c752885ea94d035e1a629e86bd887bb41` |

The supervisor reviewed the full implementation, manifest, commands and evidence. A read-only explorer checked prerequisites and existing Swift/fixture constraints; it made no changes or Git mutations.

## Executed environment

macOS **27.0.1 (26A434)**, native **arm64**; Apple Clang **21.0.0 (clang-2100.4.1.1)**, CMake/CTest **4.4.5**, `Unix Makefiles` generator and Xcode **27.2 (27B52)** toolchain. Final repository builds explicitly select Xcode's **macOS 27.2 SDK**. The compiler selected by CMake is `/usr/bin/c++`; the reported compiler installation is Xcode's toolchain.

CMake declares a minimum of 3.20, which has not been separately executed. Only the local Mac execution is evidenced. No Windows/MSVC, Linux/GCC or additional architecture result is claimed. B03 and OWE-T03 remain outstanding for their named consumers.

## Reproduce

Run from the repository root. The SDK argument below reproduces this Mac execution; it is an invocation choice, not an Apple dependency in the CMake source.

```sh
cmake -S core -B /tmp/MarkyT03S1/Debug -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
cmake --build /tmp/MarkyT03S1/Debug --verbose
ctest --test-dir /tmp/MarkyT03S1/Debug --output-on-failure --no-tests=error

cmake -S core -B /tmp/MarkyT03S1/Release -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
cmake --build /tmp/MarkyT03S1/Release --verbose
ctest --test-dir /tmp/MarkyT03S1/Release --output-on-failure --no-tests=error
```

Then deliberately fail both the executable and CTest. **Each command below is expected to return nonzero**, not pass:

```sh
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 /tmp/MarkyT03S1/Debug/marky_core_tests
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 \
  ctest --test-dir /tmp/MarkyT03S1/Debug --output-on-failure --no-tests=error
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 /tmp/MarkyT03S1/Release/marky_core_tests
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 \
  ctest --test-dir /tmp/MarkyT03S1/Release --output-on-failure --no-tests=error

# Ordinary runs recover without any source or configuration change.
ctest --test-dir /tmp/MarkyT03S1/Debug --output-on-failure --no-tests=error
ctest --test-dir /tmp/MarkyT03S1/Release --output-on-failure --no-tests=error
```

## Results

| Check | Debug | Release |
| --- | --- | --- |
| Fresh configure and verbose build | exit 0; no compiler warnings | exit 0; no compiler warnings |
| Ordinary CTest | 1/1 passed; exit 0 | 1/1 passed; exit 0 |
| Direct executable with failure injection | `FAIL: intentional harness failure`; exit 1 | same message; exit 1 |
| CTest with failure injection | 0/1 passed; test marked failed; exit 8 | same failure reporting; exit 8 |
| Ordinary CTest after injection | 1/1 passed; exit 0 | 1/1 passed; exit 0 |
| Compiler commands | both sources use `-std=c++20`; no `NDEBUG` | both sources use `-O3 -DNDEBUG -std=c++20` |
| Archive/link inspection | archive contains `BuildInfo.cpp.o`; executable defines the probe symbol | same |

The test's ordinary runtime check requires the linked library to report at least C++20. The failure injection uses that same check/reporting path, only in the test executable. There is no `assert` or `WILL_FAIL` inversion. The Release negative control demonstrates that `NDEBUG` does not suppress failures.

Both `otool -L` inspections list only `/usr/lib/libc++.1.dylib` and `/usr/lib/libSystem.B.dylib`, with no Swift runtime or Apple frameworks. `ar -t` and `nm -C` confirm the archive member and linked production definition. Reproduce with the Debug/Release paths above:

```sh
ar -t /tmp/MarkyT03S1/Release/libmarky_core.a
nm -C /tmp/MarkyT03S1/Release/marky_core_tests
otool -L /tmp/MarkyT03S1/Release/marky_core_tests
```

A third clean configure/build at `/tmp/MarkyT03S1/CoreOnly`, using the same Release/SDK/generator arguments plus `-DBUILD_TESTING=OFF`, succeeded with only the archive and no test executable. Static source/manifest inspection finds no dependency fetches, third-party libraries, Swift language or native framework linkage. These builds used installed local tools; no network isolation test or final three-OS dependency audit is claimed.

Full final Debug/Release command output is retained at `/tmp/MarkyT03S1-Debug.log` and `/tmp/MarkyT03S1-Release.log`; the commands, identities, counts and conclusions above survive removal of those logs. The original temporary candidate passed the same checks before branch approval; all results in the table were then repeated from the repository source on the approved branch.

An auxiliary default `xcrun --show-sdk-version` metadata query failed in the restricted shell (`SDK ... cannot be located`). The initial default-SDK preview builds themselves passed. Final builds select the existing Xcode 27.2 SDK explicitly and passed without warnings; no system toolchain setting was changed. Initial restricted Git branch creation was denied a ref write; the authorized execution-access retry created the approved branch. Neither failure changed source or constitutes an app defect.

## Acceptance and next work

T03.S1 is **accepted/done**: the user reported **PASS** ("pass") on 2026-11-06 for the nine-file E21 candidate and the Debug/Release pass/fail evidence above. E22 records acceptance separately from Git execution. Core source/build/harness/README hashes were verified unchanged before acceptance bookkeeping; the existing checks retain their original scope and limits, with no new runtime execution claimed. User PASS authorizes the focused commit, local main merge, main push and merged task-branch cleanup under repository policy; STATUS records actual execution. No app test is needed for this core-only slice: `Marky/`, `MarkyTests/`, `MarkyUITests/`, Xcode settings, the corpus, app version **0.2.4 (5)** and production parser selection are unchanged. No new app runtime, sandbox, accessibility, performance or Markdown parity evidence is claimed. The changelog is unchanged because this adds development build infrastructure without changing app behavior or version.

T03.S2 is the next sibling slice for reproducible platform configurations/execution discovery. T04.S1/S2 may consume this verified output when selected; T04.S3 still also needs T03.S3. Preserve B03, B06, OWE-T01 and OWE-T02; OWE-T03 requires final executed clean builds/tests and dependency inspection on all three required OSes before T19 closure. No later slice is started by this delivery.
