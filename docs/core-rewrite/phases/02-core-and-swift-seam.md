# Phase 2 — Establish the portable core and Swift seam

Read [STATUS](../STATUS.md), [interface/lifetime rules](../CONTRACT.md#boundary-and-lifetime), [build/portability](../CONTRACT.md#build-and-portability), and [completion rules](../README.md#completion-and-acceptance).

## T03 — Independent core build

**Goal:** one owned production source set built independently as a portable static library and consumable by Xcode.

**Prerequisites:** verified T01.S2 fixture output and CONTRACT.md. A characterization blocker affects only implementation that relies on that unresolved behavior.

**Inputs:** [Xcode project](../../../Marky.xcodeproj/project.pbxproj), [current commands](../../../README.md), [document types/preparation](../../../Marky/MarkdownContentBlocks.swift), [build contract](../CONTRACT.md#build-and-portability), and [scope/dependency limits](../CONTRACT.md#scope-and-dependencies).

Build-source discovery: [standalone core commands](../../../core/README.md), [production source manifest](../../../core/CMakeLists.txt), [test harness](../../../core/tests/CoreTests.cpp), and [T03.S1 execution evidence](../T03-S1-CORE-BUILD.md). Live progress and acceptance remain in STATUS.

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T03.S1 | C++20 production source structure, CMake static target, and dependency-free CTest executable. | Configure/build/test Debug and Release; deliberately cause a harness failure and verify nonzero failure reporting in both. Ordinary builds require no downloads or Swift/Apple frameworks. |
| T03.S2 | Mac/Apple Clang, Windows/MSVC, and Linux/GCC build configurations and reproducible execution procedures. | Record actual smoke executions separately from configurations. Where an environment is unavailable, register its exact missing execution in OWE-T03/B03; do not claim portability. |
| T03.S3 | Local Swift-package metadata over the same production sources and static Xcode integration. | Build through Xcode and confirm static linkage, consistent source inclusion, and no fetched dependencies. No full parser or production switch is required yet. |

**Blockers:** consult STATUS for actual toolchain/environment failures. Missing Windows/Linux execution need not stop independent local work; it does block the associated claim and T19.S1 exit.

**Owes:** `OWE-T03` → T19: executed clean core builds/tests on every required OS, including any configuration-only work from S2, plus final dependency inspection. Close only with recorded three-OS results on the final candidate.

**Acceptance:** review build/evidence changes, including intentional harness failure evidence. A configured pipeline is not an executed test. Git publication remains separately authorized.

**Handoff:** record production source locations, manifests, commands, executed environments, and outstanding platform evidence. T04.S1/S2 may start after verified T03.S1; T04.S3 also needs verified T03.S3.

## T04 — Ownership, errors, cancellation, and first integration

**Goal:** prove the actual language interface with safe lifetime/error behavior and a minimal native rendering slice.

**Prerequisites:** verified T03.S1; T04.S3 additionally requires verified T03.S3. All slices follow [boundary/lifetime](../CONTRACT.md#boundary-and-lifetime) and [native adapter](../CONTRACT.md#native-document-adapter) rules.

**Inputs:** [current document loading](../../../Marky/MarkdownViewer.swift), [loading regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), T03's new public header/build/tests, and the linked contract sections. Consult the current source, not this roadmap, for implemented declarations.

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T04.S1 | Minimal C-compatible interface, opaque results, semantic accessors, and explicit release. | Test input borrowing, owned result/view lifetime, UTF-8 lengths, empty input, invalid arguments, and cleanup. Public declarations contain no STL/native types. |
| T04.S2 | Typed failures, C++ exception containment, thread-safe cancellation tokens, and failure-injection seams kept internal to tests. | Test cancellation, allocation/internal failure cleanup, repeated/concurrent calls, and partial construction. Document token lifetime and safe cleanup; no C++ exception reaches Swift. |
| T04.S3 | Plain paragraph through the real C++ interface, Swift value adapter, and native Mac text. | A focused integration test checks text/Unicode and handle cleanup; Xcode builds the static core. The existing production reader remains usable and selected. |

**Blockers:** observed memory/lifetime, concurrency, or language-import failures block the affected interface consumers; record exact reproduction and resolver in STATUS rather than exporting an unsafe workaround.

**Owes:** `OWE-T04` → T05–T10 and T12: complete syntax and accepted production selection. Each T05–T10 receipt closes with its implemented syntax/lifetime evidence; T12 closes its receipt with accepted production selection. The plain-paragraph proof establishes only the interface and minimal path.

**Acceptance:** user review of core/adapter evidence and the minimal candidate as applicable. A test-only paragraph path does not establish native reader parity or signed sandbox restoration.

**Handoff:** record interface ownership decisions, tested failures/cancellation, and exact paragraph candidate. After accepted T04, start T05.S1; independently, T13 may consume verified T03.S1/T04.S2 without waiting for full parsing.

## Phase exit

T03 and T04 are accepted: a standalone testable core is consumed through the intended Swift adapter. Any unavailable platform execution has a concrete owe to T19, and syntax/production limitations remain explicit.
