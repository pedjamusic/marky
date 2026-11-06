# T03.S2 — Platform builds and execution procedures

Executed 2026-11-06. User acceptance and Git execution are separate in [STATUS](STATUS.md). This slice supplies platform configurations and repeatable smoke procedures over the accepted S1 scaffold. It does not implement parsing, Swift integration or additional native frontends.

## Candidate and scope

- Base: clean `main/e92588fd5db5ed6ea60395738da1613c923f6a97`.
- Verified E24 candidate: initially uncommitted `codex/t03-s2-platform-builds` at the base above, created after the user explicitly replied **“Yes, create the local branch”**. Six added/modified files: [presets](../../core/CMakePresets.json), [core procedures](../../core/README.md), root README discovery, phase 02 discovery, this report and STATUS. The user subsequently requested publication through `gh` for CodeRabbit review and automatic finding fixes; the six-file candidate was committed/pushed as `4e63f04` and published as [PR #4](https://github.com/pedjamusic/marky/pull/4). CodeRabbit completed review of that revision with no actionable findings. This report/STATUS-only closeout records the result beyond the reviewed head; executable/build inputs remain unchanged. STATUS records execution and review separately from user acceptance.
- `core/CMakeLists.txt`, production C++ sources and test executable source remain byte-identical to accepted S1. No app source, Xcode setting, compatibility fixture, version or production parser selection changes. App version remains **0.2.4 (5)** as verified in the project settings. No app changelog entry accompanies development-only configuration/procedure changes.

The presets select Apple Clang via `/usr/bin/clang++`, GNU GCC via `g++` on Linux, and Visual Studio 2022/v143 with x64 target on Windows. macOS/Linux use `Unix Makefiles`; all configure/build/test names have host conditions. Each of the six configurations has its own `.build/core/<preset-name>` output tree. Windows also supplies explicit build/test `configuration` values because Visual Studio is multi-configuration. No source list, compiler standard, runtime dependency or production interface is changed.

Schema version 3 and its conditions require the **3.21+ preset workflow**. The existing manual `cmake -S/-B` path retains its declared **3.20+** minimum; neither minimum has been separately executed. These choices were checked against the official [CMake 3.21 presets manual](https://cmake.org/cmake/help/v3.21/manual/cmake-presets.7.html) and [VS 2022 generator documentation](https://cmake.org/cmake/help/v3.21/generator/Visual%20Studio%2017%202022.html). The latter specifies x64 platform selection and v143. No new development or shipped dependency is installed.

## Executed environment and results

macOS **27.0.1 (26A434)**, native **arm64**, Xcode **27.2 (27B52)**, Apple Clang **21.0.0 (clang-2100.4.1.1)** through `/usr/bin/clang++`, CMake/CTest **4.4.5**, `Unix Makefiles`, explicit Xcode **macOS 27.2 SDK**. Only this host/compiler/architecture was executed.

| Check | Debug | Release |
| --- | --- | --- |
| Configure, verbose build, ordinary CTest | exit 0; 1/1 passed | exit 0; 1/1 passed |
| Direct executable failure injection | exit 1; intentional harness failure | exit 1; intentional harness failure |
| CTest failure injection through preset | exit 8; 0/1 passed; failure output visible | exit 8; 0/1 passed; failure output visible |
| Ordinary CTest recovery | exit 0; 1/1 passed | exit 0; 1/1 passed |
| Compiler flags | `-g -std=c++20` | `-O3 -DNDEBUG -std=c++20` |
| Archive / runtime dependencies | `BuildInfo.cpp.o`; standard libraries only | same |

Both repository build directories were fresh, and both final builds completed without compiler warnings. Additional checks: CMake parsed the full preset file; `--list-presets=all` listed only the two Mac names for each command type. All four Linux/Windows configure attempts on this Mac returned exit **1**, reporting a disabled preset before compiler/build execution. A separate clean configure with `BUILD_TESTING=OFF` followed by the same test preset using `--test-dir` returned exit **8**, `No tests were found`; zero tests do not silently pass. These are configuration/guard checks, not foreign-platform execution.

`ar -t` finds the production archive member. `otool -L` on both test executables lists only `/usr/lib/libc++.1.dylib` and `/usr/lib/libSystem.B.dylib`. No Swift runtime or Apple framework is linked. The intentional failure path remains effective with Release `NDEBUG`. No app/UI test is applicable to this configuration-only slice; no new app runtime, sandbox, accessibility, Markdown parity or performance claim is made.

## Reproduce the Mac smoke

From repository `core/`, with fresh build directories (the commands below do not delete an existing directory):

```sh
cmake --list-presets=all
cmake --preset macos-appleclang-debug \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
cmake --build --preset macos-appleclang-debug --verbose
ctest --preset macos-appleclang-debug

cmake --preset macos-appleclang-release \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
cmake --build --preset macos-appleclang-release --verbose
ctest --preset macos-appleclang-release

# Expected exits: 1, 8, 1, 8 respectively, with intentional failure messages.
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ../.build/core/macos-appleclang-debug/marky_core_tests
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset macos-appleclang-debug
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ../.build/core/macos-appleclang-release/marky_core_tests
cmake -E env MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --preset macos-appleclang-release

# Both ordinary runs must recover.
ctest --preset macos-appleclang-debug
ctest --preset macos-appleclang-release
```

The explicit SDK is an invocation choice, not a path embedded in the shared presets. [Core procedures](../../core/README.md) provide Windows PowerShell and Linux commands, prerequisites, exit-code handling, failure/recovery controls, candidate/environment fields and platform-native dependency inspection commands. Preserve ordinary failures as failures; do not use expected failure controls to hide missing tools or missing test binaries.

The no-test negative control uses the Debug configure preset with `-B /tmp/MarkyT03S2-logs/NoTests -DBUILD_TESTING=OFF` and the same SDK argument, then `ctest --preset macos-appleclang-debug --test-dir /tmp/MarkyT03S2-logs/NoTests`. The separate directory prevents this control from changing the real preset build. The non-Mac guard checks invoke each Linux/Windows configure name on macOS and expect `disabled` with exit 1; no compiler or guest OS is executed.

## Missing execution and ownership

Read-only local route discovery found:

- `/usr/bin/g++` identifies itself as Apple Clang targeting macOS arm64; it cannot supply the required Linux/GCC run.
- Docker CLI **29.8.2** and Docker Desktop are installed, but the selected `desktop-linux` daemon socket is absent. `docker info` and cached image inventory cannot connect. No Linux image/digest or installed GCC/CMake inside an image was verified; no container was started or image downloaded.
- UTM is installed, but no ready Linux or Windows guest/toolchain was established by this bounded inspection. No guest was launched. No remote executor or CI job was run or published.

| Required family | Configuration supplied | Actual smoke execution | Exact remaining evidence |
| --- | --- | --- | --- |
| macOS / Apple Clang | Debug and Release | Executed locally as above | Final clean-candidate rerun/dependency inspection at T19 still required. |
| Linux / GCC | Debug and Release | **Not executed** | On a prepared Linux/GCC host (or explicitly identified Linux container), clean configure/build, 1/1 smoke, intentional nonzero failure and ordinary recovery in both configurations; exact revision, OS/image, compiler, architecture, commands and imports. |
| Windows / MSVC | Debug and Release, x64/v143 | **Not executed** | On a prepared Windows/MSVC host, clean configure/build, 1/1 smoke, intentional nonzero failure and ordinary recovery in both configurations; exact revision, OS, compiler/toolset/SDK, host/target architecture, commands and imports. |

**B03** records the unavailable Linux/GCC and Windows/MSVC executions; **OWE-T03 → T19.S1** receives these exact missing smoke runs and final three-OS clean-build/dependency evidence. Supplying commands and host guards does not close either obligation. A future environment owner must prepare a runnable host/guest/container or authorized CI route, execute the procedures, and add actual results. There is no claim of Windows/Linux portability or an additional supported architecture/frontend.

## Candidate identity and acceptance

Executable/build-input SHA-256 identities are recorded here independently of temporary logs:

| File | SHA-256 |
| --- | --- |
| `core/CMakePresets.json` | `79796bf1f744050aa2b0b1bbbf3395f40f6f176b42fa9e0efd4b69db5cc52fa5` |
| `core/CMakeLists.txt` | `770be28237e8bf4d0466c9a4e6c057a73a5bf4abf8337edfb246dc8bb1486db5` |
| `core/src/BuildInfo.cpp` | `bd272540c6a3286465742aa92c6c53a70083b03c161d011b38eab413fd1bb56d` |
| `core/src/BuildInfo.hpp` | `ffd20dd3e11a3e9cb00197721e6bdfaed0e572df29073313aea6f8b8bd00d315` |
| `core/tests/CoreTests.cpp` | `a0969c5f0bb0bfc830d7ee3c52aa881c752885ea94d035e1a629e86bd887bb41` |

The session reviewed every preset, source/test ownership, platform commands and research/environment findings itself. Explorers only investigated toolchain routes and official documentation; they made no repository edits or Git mutations. All six files passed focused scope, newline/trailing-whitespace and **75 local link/anchor** checks; `git diff --check` passed. Git confirms `.build/` outputs are ignored. The four unchanged S1 build/source/harness files match their accepted hashes above.

Final repository command logs and an input-hash/exit-code summary are retained at `/tmp/MarkyT03S2-logs/`; the report preserves commands, counts, environment and limitations after logs are removed. Preview checks ran first from `/tmp/MarkyT03S2-candidate`, followed by the full fresh repository checks after branch approval. The restricted shell initially could not write the approved branch ref; the authorized execution-access retry succeeded. No source or system toolchain setting changed because of that failed attempt.

User review/PASS remains pending for the focused six-file diff and automated core evidence. The requested CodeRabbit review/fix cycle is tracked in STATUS and does not substitute for user acceptance. No new app test is requested. T03.S2 must remain awaiting acceptance after delivery, and T03.S3 is the next sibling only after this review. B03, B06 and OWE-T01/OWE-T02/OWE-T03 remain explicit; no later slice is implemented here.
