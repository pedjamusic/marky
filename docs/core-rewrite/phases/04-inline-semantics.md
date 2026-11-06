# Phase 4 — Inline semantics

These are static ticket definitions. [CONTRACT](../CONTRACT.md) is authoritative; [STATUS](../STATUS.md) owns all live state, evidence, blockers, and obligation closure. Apply [completion and acceptance](../README.md#completion-and-acceptance) to every ticket. A whole-ticket prerequisite means accepted completion. A slice prerequisite requires that slice's recorded technical verification, without implying whole-ticket or user acceptance. Every slice inherits its ticket prerequisites and earlier sibling slice evidence unless explicitly stated otherwise.

## T08 — Literal spans, escapes, and normalization

### Goal

Implement portable inline lexical rules and checked-in normalization data for the owned C++20 parser.

### Prerequisites

Accepted `T05`.

### Inputs

Read [block and inline owner](../../../Marky/MarkdownContentBlocks.swift), [regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [reader tests](../../../MarkyTests/MarkyTests.swift), and [Markdown verification](../../MARKDOWN_STYLING_VERIFICATION.md). Apply [document semantics](../CONTRACT.md#document-semantics), [scope and dependencies](../CONTRACT.md#scope-and-dependencies), and [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T08.S1 | Literal code-span matching, including complete delimiter runs, unmatched runs, spaces, Unicode neighbors, and protected punctuation. Reuse the lexical matcher established by `T05.S1`; retain its table use in `T07.S1`. | Portable fixtures cover literal contents and delimiter boundaries, including pipes inside code; malformed runs stay literal and source ranges remain valid. |
| T08.S2 | Backslash escapes, soft/hard breaks, and entity handling with normalization boundaries. Tests may use explicitly provisional data pending `T08.S3`. | Fixtures distinguish escaped syntax, hard/soft breaks, numeric and named entities, malformed sequences, and code protection. Mark provisional-data evidence so it cannot satisfy final data acceptance. |
| T08.S3 | Checked-in Unicode/entity data with version, source, license/provenance, reproducible update procedure, and offline normalization tests. | Clean offline execution resolves every required normalization/entity fixture using only checked-in data; provisional `T08.S2` cases rerun against final data. This slice does not require the full reference resolver in `T10`. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T08`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T08`: origin `T08`; recipients `T09`, `T10`. Supply literal-protection, escape, and normalization interaction fixtures and data provenance. Each recipient closes its own receipt by recording passing combined fixtures against the final data in STATUS; the grouped owe closes after both receipts close.

### Acceptance

All three slices pass with final offline data and owned parser code; Unicode/entity policy and literal protection match the contract. Record evidence and obtain the applicable review in README.

### Handoff

Attach `T08.S1`–`T08.S3` evidence to STATUS and deliver `OWE-T08` fixtures to `T09.S1` and `T10.S1` after their other prerequisites are accepted.

## T09 — Emphasis and combined traits

### Goal

Represent emphasis, strong emphasis, and strikethrough as portable semantic traits.

### Prerequisites

Accepted `T08`.

### Inputs

Read [block and inline owner](../../../Marky/MarkdownContentBlocks.swift), [regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [reader tests](../../../MarkyTests/MarkyTests.swift), and [Markdown verification](../../MARKDOWN_STYLING_VERIFICATION.md). Apply [document semantics](../CONTRACT.md#document-semantics) and [native document adapter](../CONTRACT.md#native-document-adapter).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T09.S1 | Delimiter rules for emphasis, strong emphasis, and strikethrough, preserving unmatched syntax literally. | Fixtures cover punctuation/word boundaries, adjacent runs, unmatched delimiters, escapes, and literal code isolation. |
| T09.S2 | Nested and combined styles, including combined traits around protected code spans. | Portable fixtures verify exact text and trait ranges for nested/combined styles with Unicode and code punctuation; all S1 fixtures still pass. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T09`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T09`: origin `T09`; recipients `T11`, `T12`. Deliver semantic trait/range fixtures for native fonts and combined styling. Close when native attributed-run checks in `T11` and parity evidence in `T12` cover those fixtures.

### Acceptance

Both slices pass and `OWE-T08` interaction evidence applicable to T09 is delivered. Trait output remains independent of fonts, drawing, and UI frameworks; record the applicable review.

### Handoff

Record T09 evidence, then provide combined-trait fixtures to `T10.S1` and the native adapter work in `T11.S1`.

## T10 — Links, references, and complete semantic corpus

### Goal

Finish portable inline semantics and a complete supported-document corpus before native integration.

### Prerequisites

Accepted `T08`, `T09`, `T05`, and `T06`. `T10.S3` additionally requires accepted `T07`.

### Inputs

Read [block and inline owner](../../../Marky/MarkdownContentBlocks.swift), [regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [reader tests](../../../MarkyTests/MarkyTests.swift), and [Markdown verification](../../MARKDOWN_STYLING_VERIFICATION.md). Consult [showcase](../../MARKDOWN_SHOWCASE.md) and apply [document semantics](../CONTRACT.md#document-semantics), [scope and dependencies](../CONTRACT.md#scope-and-dependencies), and [native document adapter](../CONTRACT.md#native-document-adapter).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T10.S1 | Inline links, autolinks, formatted labels, and portable destination semantics. | Fixtures cover code in labels, combined traits, parentheses/escaping, malformed destinations, and protected literal source; core performs no native link opening. |
| T10.S2 | Document-wide reference collection and resolution with first-definition-wins policy, invalid-destination preservation, normalized labels, and code protection. | Cross-block fixtures include definitions before/after use, duplicates, unresolved references, malformed definitions, and fenced/indented/inline code isolation using final T08 data. |
| T10.S3 | Inline image alt semantics plus the complete semantic corpus across every supported block. Additional prerequisite: accepted `T07`. | Identical portable fixtures cover links, images, references, tables, lists, quotes, headings, literal blocks, malformed input, Unicode, and interactions. Standalone image semantics and inline alt behavior match the approved existing product contract. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T10`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T10`: origin `T10`; recipients `T11`, `T12`. Supply destination/reference/inline-alt corpus and expected semantic ranges. Close when T11 native link/alt mapping and T12 complete parity comparison record passing evidence.

### Acceptance

All slices and complete corpus pass; preserve first-definition wins and literal code protection. The core owns semantics while native adapters retain URL resolution, image loading/grants, and presentation. Record applicable review.

### Handoff

Record T10 evidence and deliver the complete corpus plus `OWE-T10` cases to `T11.S1` and `T11.S2`.

## Phase exit

`T08`, `T09`, and `T10` have accepted completion with final offline normalization data and the complete portable corpus. Their obligations are delivered and tracked to their named recipients; closure remains in STATUS. `T07.S1` uses the lexical matcher from `T05.S1` (or the earlier internal helper), so this phase introduces no `T07` → `T08` → `T10` dependency cycle.
