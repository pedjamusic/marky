# Phase 7 — Hardening and closure

These are static ticket definitions. [CONTRACT](../CONTRACT.md) is authoritative; [STATUS](../STATUS.md) owns all live state, evidence, blockers, and obligation closure. Apply [completion and acceptance](../README.md#completion-and-acceptance) to every ticket. A whole-ticket prerequisite means accepted completion. A slice prerequisite requires that slice's recorded technical verification, without implying whole-ticket or user acceptance. Every slice inherits its ticket prerequisites and earlier sibling slice evidence unless explicitly stated otherwise.

## T17 — Resources, malformed input, and measured performance

### Goal

Harden the integrated core and verify runtime and memory against the fixed baseline.

### Prerequisites

Accepted `T12` and `T16`.

### Inputs

Read [document regressions](../../../MarkyTests/MarkdownRegressionTests.swift), [project regressions](../../../MarkyTests/MarkyTests.swift), [load owner](../../../Marky/MarkdownViewer.swift), [project owner](../../../Marky/ViewModels/ContentViewModel.swift), and [verification guide](../../CODE_QUALITY_VERIFICATION.md). Use T02 recorded fixed inputs and procedure; apply [verification and performance](../CONTRACT.md#verification-and-performance), [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime), and [build and portability](../CONTRACT.md#build-and-portability).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T17.S1 | Sanitizer, fuzz, malformed-input, and stress coverage for document and project APIs. | Record reproducible seeds/inputs and sanitizer results; malformed UTF-8, delimiter stress, deep nesting, large documents/trees, and boundary misuse produce typed outcomes without crashes or undefined behavior. |
| T17.S2 | Cancellation and resource-lifetime verification across core handles, native async work, and grants. | Repeated success/failure/cancel/supersede cycles show no stale publication, leaks, double release, escaped C++ exceptions, or unbalanced native access. Record tool/configuration and observed results. |
| T17.S3 | Repeat fixed T02 measurements for the integrated implementation. | Use the same inputs, hardware/build settings, warmup/repetition procedure, and measurement definitions as T02. Median runtime and peak memory each regress by at most 20%; record raw measurements and comparisons. Resolve failures before acceptance. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T17`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T17`: origin `T17`; recipient `T19`. Deliver corrective findings, reproductions, fixes, sanitizer/resource evidence, and fixed-baseline measurements. Required corrective findings must be resolved before T18 acceptance; close the obligation when T19 final execution verifies those fixes and audits the evidence.

### Acceptance

All slices pass, runtime/peak-memory thresholds are met, and required corrective findings are resolved with regression evidence. Record the applicable review and carry final execution checks to T19.

### Handoff

Deliver verified fixes and replacement inventory context to `T18.S1`; retain reproducible hardening/performance evidence for `T19.S1` and its final audit.

## T18 — Remove replaced paths and update architecture

### Goal

Remove replaced Swift rules and temporary migration plumbing, then document the final architecture and release behavior.

### Prerequisites

Accepted `T17`, `T12`, and `T16`.

### Inputs

Read [Swift parser/renderer owner](../../../Marky/MarkdownContentBlocks.swift), [project owner](../../../Marky/FileNode.swift), [view model](../../../Marky/ViewModels/ContentViewModel.swift), [viewer](../../../Marky/MarkdownViewer.swift), [README](../../../README.md), [portability assessment](../../AGENT_POLICY_AND_PORTABILITY.md), [verification guide](../../CODE_QUALITY_VERIFICATION.md), and [changelog](../../../CHANGELOG.md). Apply [scope and dependencies](../CONTRACT.md#scope-and-dependencies), [build and portability](../CONTRACT.md#build-and-portability), and [native document adapter](../CONTRACT.md#native-document-adapter).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T18.S1 | Remove replaced Swift parser/project-rule implementations and migration plumbing against T12 inventory; preserve native services, presentation, and meaningful tests. | Search/call-graph review accounts for each removed path; builds and relevant regressions pass using only production core semantics/rules. Native filesystem/grants/persistence/localization and attributed rendering remain owned by adapters. |
| T18.S2 | Update architecture, C interface/lifetime contract, independent build/test instructions, verification procedures, and versioned release documentation. | Review each changed document against actual implementation/commands. Record removed paths, native responsibilities, supported platforms versus executed evidence, and release behavior in the existing versioned convention; document review is required. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T18`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T18`: origin `T18`; recipient `T19`. Deliver final source/dependency inventory, reproducible build commands, interface docs, and removal verification. Close when T19 clean builds/runtime dependency inspection and final audit verify the final tree.

### Acceptance

Both slices pass; every required T17 corrective finding is resolved before acceptance. Updated docs describe the final code and evidence accurately; obtain documentation review and applicable behavioral acceptance under README.

### Handoff

Give the final tree, build instructions, removal inventory, and obligation evidence to `T19.S1` once all required OS execution environments are available.

## T19 — Cross-platform execution and final acceptance

### Goal

Execute the final core on every claimed OS, verify the native macOS product, and close required debt.

### Prerequisites

Accepted `T17` and `T18`; working execution environments for macOS, Windows/MSVC, and Linux/GCC are required. Compilation intentions or fixture portability alone do not satisfy execution evidence.

### Inputs

Read [app README](../../../README.md), [unit regressions](../../../MarkyTests/MarkdownRegressionTests.swift), [project regressions](../../../MarkyTests/MarkyTests.swift), [UI tests](../../../MarkyUITests/MarkyUITests.swift), [sandbox verification](../../CODE_QUALITY_VERIFICATION.md), [AGENTS policy](../../../AGENTS.md), and [STATUS](../STATUS.md). Apply [build and portability](../CONTRACT.md#build-and-portability), [verification and performance](../CONTRACT.md#verification-and-performance), and [scope and dependencies](../CONTRACT.md#scope-and-dependencies).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T19.S1 | Clean independent core builds/tests on macOS, Windows/MSVC, and Linux/GCC, with runtime dependency inspection. | Execute the identical checked-in fixtures on all three environments; record toolchain/configuration, commands, results, and inspected runtime dependencies. Verify no third-party parser/runtime dependency. Resolve platform failures and verify incoming T17/T18 evidence against the final tree. |
| T19.S2 | Final macOS unit/UI checks and exact signed, sandbox-enabled app candidate. | Run relevant complete macOS suites and native acceptance flows on the final tree; verify restoration, permissions, failed opens, cancellation, large files/folders, favorites, reader settings/links/images, and native interactions. User reports PASS for the exact candidate. |
| T19.S3 | Ledger audit, final acceptance record, and separately authorized Git handling. | Audit all ticket/slice evidence, prerequisites, blockers, obligations, approved differences, measurement thresholds, OS execution, docs, and exact user PASS. Every required obligation is closed. Record documentation review; perform only Git operations explicitly authorized by the user, tracking pending Git actions separately from technical acceptance. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T19`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

None. T19 is the terminal recipient. Required unclosed incoming obligations prevent phase exit; list any unresolved optional/future work explicitly in STATUS rather than treating it as completed.

### Acceptance

All three slices pass on the final tree, every required blocker/debt is resolved with closure evidence, all three OS executions are recorded, documentation is reviewed, and the user reports PASS for the final signed macOS candidate. Git operations require their own authorization.

### Handoff

Record final accepted evidence and the required-obligation audit in STATUS. Report the exact candidate, executed platform matrix, measurement results, and any separately pending authorized Git action; request only the specific missing Git authorization if one remains.

## Phase exit

`T17`, `T18`, and `T19` have accepted completion. The final core passes identical fixtures on macOS, Windows/MSVC, and Linux/GCC; runtime dependency inspection confirms the approved dependency scope. Fixed T02 median-runtime and peak-memory regressions are each at most 20%. The final signed macOS candidate has user PASS, documentation review is recorded, and every required obligation is closed. Missing OS execution, unclosed required debt, or missing final acceptance prevents exit. Git completion is reported separately and follows explicit authorization.
