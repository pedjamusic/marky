# Phase 1 — Freeze behavior and establish baselines

Read [STATUS](../STATUS.md), [document semantics](../CONTRACT.md#document-semantics), [project rules](../CONTRACT.md#project-rules), and [completion rules](../README.md#completion-and-acceptance).

## T01 — Compatibility fixtures

**Goal:** a reviewed behavior contract that detects migration regressions without depending on the new parser's implementation.

**Prerequisites:** accepted T00 and authorization to begin core work.

**Inputs:** [block parsing/preparation](../../../Marky/MarkdownContentBlocks.swift), [inline rendering/loading](../../../Marky/MarkdownViewer.swift), [Markdown tests](../../../MarkyTests/MarkdownRegressionTests.swift), [project tests](../../../MarkyTests/MarkyTests.swift), [outline tests](../../../MarkyTests/FilesOutlineTests.swift), [UI tests](../../../MarkyUITests/MarkyUITests.swift), [showcase](../../MARKDOWN_SHOWCASE.md), and [accepted styling scope](../../MARKDOWN_STYLING_VERIFICATION.md).

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T01.S1 | [Requirement-to-test coverage map](../T01-S1-COVERAGE.md) separating shared semantics from native checks and identifying gaps. | Account for existing documented supported behavior and critical project/access invariants; identify gaps and their owning tickets rather than assuming coverage. |
| T01.S2 | Shared Markdown input fixtures and independently reviewed expected structure, visible text, formatting, destinations, and literal protection. | Check expected results against current code/tests and accepted examples; assign stable fixture identities usable by standalone core tests and Mac adapter checks. Expectations are not generated from the replacement parser. |
| T01.S3 | Characterization of ambiguous/uncovered cases against the current app, with linked fixture updates. | Each discovered ambiguity is resolved with evidence or has a named blocker on its consumer; no standards change is introduced silently. Resolve incoming OWE-T00 with the reviewed map/corpus. |

**Blockers:** register an observed ambiguity or unavailable baseline candidate in STATUS with the exact fixtures and consumer slices affected. Other characterized behavior can proceed independently.

**Owes:** `OWE-T01` → T05–T10 and T12: preserve and satisfy the corpus through owned parsing and native presentation. Each T05–T09 receipt closes with its applicable passing fixtures; T10 closes its receipt with the complete semantic corpus; T12 closes its receipt with native parity evidence. Native-only assertions remain in adapter/UI suites.

**Acceptance:** review the coverage map, expected results, and characterized exceptions. Existing native tests remain relevant. A fixture is not approved merely because the new implementation agrees with it.

**Handoff:** identify reviewed fixtures, unresolved cases, current source revision, and exact next characterization. T02.S1 may consume T01.S1 evidence before this whole ticket closes; T03.S1 may consume T01.S2 evidence, with affected ambiguities still blocking their consumers.

## T02 — Runtime and performance baseline

**Goal:** reproducible evidence for the pre-rewrite app and meaningful before/after measurements.

**Prerequisites:** verified T01.S1 output; this ticket is independent of completion of T01.S2/S3.

**Inputs:** [current build/test commands](../../../README.md), [access acceptance procedures](../../CODE_QUALITY_VERIFICATION.md), [Markdown acceptance](../../MARKDOWN_STYLING_VERIFICATION.md), [loading/rendering](../../../Marky/MarkdownViewer.swift), [scanning](../../../Marky/FileNode.swift), and [verification/performance contract](../CONTRACT.md#verification-and-performance).

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T02.S1 | Current Mac build, unit/UI results, and exact baseline candidate identity. | Record commands, revision/dirty state, toolchain/OS/architecture, signing, results, and limits. Resolve unexpected failures or name pre-existing blockers and affected later checks. Historical logs alone do not establish the new baseline. |
| T02.S2 | Fixed representative large-document and large-folder inputs plus repeatable measurement procedures/results. | Record reproducible fixture generation/identity, comparable build/hardware conditions, run count/warm-up method, processing-time medians, peak memory, and cancellation observations. Include semantic preparation and end-to-end app costs so work cannot be hidden in an adapter. |

**Blockers:** baseline build/UI access or measurement failures must name their resolver and effects in STATUS. A known baseline defect is not permission to conceal a replacement regression.

**Owes:** `OWE-T02` → T17: repeat the fixed measurements on the integrated replacement and assess the contract's regression gate. Close with comparable results; retain baseline identity and conclusions durably.

**Acceptance:** user review of baseline evidence; use a signed sandbox candidate for any claimed access-restoration behavior. Preserve failed/skipped/unrun results explicitly.

**Handoff:** name the baseline revision, candidate, fixture identities, valid checks, and any blockers. The next dependent consumers are T12.S1 parity and T17.S3 measurement comparison; do not rerun the baseline without a reason or change its fixtures silently.

## Phase exit

T01 and T02 have accepted outputs. Preserved behavior, unresolved-case ownership, and baseline evidence can detect regressions, with outgoing OWE-T01/OWE-T02 assigned to their receiving tickets.
