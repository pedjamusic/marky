# Phase 5 — macOS document integration

These are static ticket definitions. [CONTRACT](../CONTRACT.md) is authoritative; [STATUS](../STATUS.md) owns all live state, evidence, blockers, and obligation closure. Apply [completion and acceptance](../README.md#completion-and-acceptance) to every ticket. A whole-ticket prerequisite means accepted completion. A slice prerequisite requires that slice's recorded technical verification, without implying whole-ticket or user acceptance. Every slice inherits its ticket prerequisites and earlier sibling slice evidence unless explicitly stated otherwise.

The production reader remains on Swift through development and the T12.S1 comparison. T12.S2 switches the candidate after parity checks; user PASS gates accepted cutover. Integration evidence may use test harnesses; the product gains neither a shipping parser selector nor a silent dual-parser fallback.

## T11 — Native document adapter

### Goal

Map portable document semantics into the existing native macOS reader without changing the approved reading experience.

### Prerequisites

Accepted `T04`, `T06`, `T07`, `T08`, `T09`, and `T10`.

### Inputs

Read [block and inline owner](../../../Marky/MarkdownContentBlocks.swift), [regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [reader tests](../../../MarkyTests/MarkyTests.swift), and [Markdown verification](../../MARKDOWN_STYLING_VERIFICATION.md). Read [viewer/load owner](../../../Marky/MarkdownViewer.swift), [typography](../../../Marky/MarkdownTypography.swift), [image access owner](../../../Marky/Services/ProjectSessionService.swift), and [UI tests](../../../MarkyUITests/MarkyUITests.swift). Apply [native document adapter](../CONTRACT.md#native-document-adapter) and [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T11.S1 | Native attributed runs from core text/traits/destinations with explicit Unicode-to-UTF-16 range mapping. | Native tests verify composed/decomposed text, emoji, non-BMP characters, combining marks, code/link/combined style traits, correct ranges, and handle/buffer lifetime. |
| T11.S2 | Native block, table, and image mapping using existing presentation and typography tokens. | Native tests and focused app inspection cover every supported block, table geometry/alignment, inline image alt text, standalone local/remote image behavior, loading failures, and granted access ownership. |
| T11.S3 | Asynchronous core loading with latest-generation publication, cancellation, and settings rerender from prepared semantics. | Existing suspended-load, stale-generation, already-cancelled-call, ordinary failure after cancellation, and settings-during-load regressions pass through the adapter; settings rerender avoids rereading the file. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T11`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T11`: origin `T11`; recipient `T12`. Deliver native mapping/lifetime tests, renderer comparison harness, and known-difference disposition. Close when T12 parity and signed-candidate evidence cover every delivered case.

### Acceptance

All slices pass native and portable checks, incoming `OWE-T09`/`OWE-T10` cases have native evidence, and native ownership of fonts, links, images, grants, and localization is preserved. Record the candidate and applicable manual acceptance under README; production cutover remains T12.

### Handoff

Record T11 evidence and give its comparison harness and obligation inventory to `T12.S1`.

## T12 — Parity and production document cutover

### Goal

Prove complete parity, then switch the macOS production document path to the core.

### Prerequisites

Accepted `T11` and `T02`.

### Inputs

Read [renderer](../../../Marky/MarkdownContentBlocks.swift), [viewer](../../../Marky/MarkdownViewer.swift), [regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [UI tests](../../../MarkyUITests/MarkyUITests.swift), [Markdown verification](../../MARKDOWN_STYLING_VERIFICATION.md), and [sandbox acceptance](../../CODE_QUALITY_VERIFICATION.md). Apply [native document adapter](../CONTRACT.md#native-document-adapter) and [verification and performance](../CONTRACT.md#verification-and-performance).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T12.S1 | Complete parity comparison against T02 baseline and complete semantic/native corpus, with every difference resolved or covered by an explicit user-approved contract amendment. | Compare semantic text/ranges and native rendering/interactions for supported syntax, malformed input, Unicode, representative large documents, failure, cancellation, settings, and image access. Record exhaustive case results and disposition. |
| T12.S2 | Production reader cutover and exact signed, sandbox-enabled candidate. | Relevant macOS unit/UI tests pass; candidate build identity and focused manual steps cover reading/navigation/settings, links/images, failures, cancellation, large documents, and sandbox restoration. User reports PASS for that candidate before acceptance. No shipping parser selector or silent dual fallback remains. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T12`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T12`: origin `T12`; recipients `T17`, `T18`. Deliver accepted cutover evidence, baseline comparison inputs, and explicit replaced-Swift inventory. Close when T17 records fixed-baseline performance evidence and T18 verifies removal against that inventory.

### Acceptance

Both slices pass and the user reports PASS for the exact signed candidate. Complete incoming T09/T10/T11 parity evidence; record any explicit user-approved contract amendment and the cutover outcome in STATUS.

### Handoff

Provide T12 baseline/cutover evidence to `T17` after `T16` is accepted; give the removal inventory to `T18` for use after its prerequisites. Keep Git authorization separate.

## Phase exit

`T11` and `T12` have accepted completion, the core supplies production document semantics, and the exact signed macOS cutover candidate has user PASS. Complete corpus/native parity differences are resolved or explicitly approved. Replaced Swift code removal remains T18; obligations to T17/T18 remain tracked in STATUS.
