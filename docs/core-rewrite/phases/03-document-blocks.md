# Phase 3 — Implement document blocks

Read [STATUS](../STATUS.md), [document semantics](../CONTRACT.md#document-semantics), [interface/lifetime](../CONTRACT.md#boundary-and-lifetime), and [completion rules](../README.md#completion-and-acceptance).

## T05 — Base blocks and literal protection

**Goal:** owned block recognition that preserves literal content and accepted syntax precedence.

**Prerequisites:** accepted T04 and relevant reviewed T01 fixtures; unresolved characterization blocks its consumer cases.

**Inputs:** [block recognition/preparation](../../../Marky/MarkdownContentBlocks.swift), [Markdown regression tests](../../../MarkyTests/MarkdownRegressionTests.swift), [styling scope](../../MARKDOWN_STYLING_VERIFICATION.md), T01 fixtures, and [document semantics](../CONTRACT.md#document-semantics).

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T05.S1 | UTF-8/line handling, fenced code, protected-region tracking, and a reusable literal/code-span scanning helper for table consumers. | Matching delimiter/length, invalid closer indentation, unclosed fences, CRLF, Unicode, and literal-content fixtures pass. The helper supports T07 without requiring the completed inline pipeline from T08. |
| T05.S2 | Paragraphs, ATX/Setext headings, thematic breaks, and indented code. | Shared fixtures verify precedence, blank lines, line joining/breaks, and preserved whitespace against the contract. |
| T05.S3 | Malformed-input and interruption regressions for these paths. | Readable input is retained; cancellation and failure release partially constructed results. Verify through the public interface rather than duplicating private implementation assertions. |

**Blockers:** observed literal loss, precedence ambiguity, or cancellation/lifetime defects block affected consumers; register exact fixtures and next diagnosis in STATUS.

**Owes:** `OWE-T05` → T08–T10: complete inline interpretation and interactions on these blocks. Each T08/T09 receipt closes with its applicable inline interaction fixtures; T10 closes its receipt with the complete core corpus in T10.S3. Literal protection must already satisfy this ticket's own exits.

**Acceptance:** review passing core fixtures and failure/cancellation evidence. Production behavior stays with the current reader until T12.

**Handoff:** identify supported block fixtures and the shared lexical helper. Next eligible work is T06.S1, T07.S1, or T08.S1 once their exact prerequisites hold; record which slice is active rather than starting multiple unsupervised changes.

## T06 — Lists and blockquotes

**Goal:** semantic list/quote structure independent of native glyphs and layout.

**Prerequisites:** accepted T05 and relevant T01 fixtures.

**Inputs:** [list/quote preparation](../../../Marky/MarkdownContentBlocks.swift), [list/quote presentation](../../../Marky/MarkdownViewer.swift), [Markdown tests](../../../MarkyTests/MarkdownRegressionTests.swift), [UI tests](../../../MarkyUITests/MarkyUITests.swift), and [document semantics](../CONTRACT.md#document-semantics).

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T06.S1 | List marker data, nesting, continuations, and checked/unchecked task states. | Core fixtures verify item text, depth, order, and task state; native checkbox glyphs and indentation metrics remain outside the core. |
| T06.S2 | Blockquote structure, text, and nesting depth. | Core fixtures retain accepted quote content/depth and interactions with adjacent blocks; formatting of that content remains an inline-parser obligation. |

**Blockers:** register actual container/precedence ambiguity and the affected fixtures in STATUS; unimplemented inline styling is an outgoing owe, not an excuse for incorrect block structure.

**Owes:** `OWE-T06` → T11: native list markers/indentation and quote presentation. Close with adapter/UI evidence retaining current appearance, nesting, and interaction requirements.

**Acceptance:** review semantic fixture results and public-model structure. Native presentation is not claimed by these core tests.

**Handoff:** name container coverage, remaining inline consumers, and exact next block/inline slice. T07.S1 container-interaction fixtures may now consume accepted T06.

## T07 — Tables and image blocks

**Goal:** owned tables and standalone image references with no I/O or presentation dependency.

**Prerequisites:** accepted T05; T07.S1 additionally requires accepted T06 for container-boundary cases. Use T05.S1's lexical helper; do not depend on T08 and create a cycle.

**Inputs:** [table/image recognition](../../../Marky/MarkdownContentBlocks.swift), [table/image presentation](../../../Marky/MarkdownViewer.swift), [Markdown tests](../../../MarkyTests/MarkdownRegressionTests.swift), [showcase](../../MARKDOWN_SHOWCASE.md), and [document semantics](../CONTRACT.md#document-semantics).

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T07.S1 | Table recognition/splitting, alignment, cell normalization, and block termination sharing literal-span recognition. | Escaped pipes, matched/unmatched code spans, absent outer pipes, short pipe-free rows, uneven cells, malformed delimiters, quote/list boundaries, and Setext disambiguation fixtures pass. Inline cell styling is not required yet. |
| T07.S2 | Standalone image metadata: destination, alt text, and optional title. | Angle-bracket/spaced destinations and malformed-image fixtures match current behavior; no filesystem/network access or image decoding occurs in the core. |

**Blockers:** record actual row-boundary/lexical incompatibilities with fixture IDs. These must be resolved before claiming block parity; later inline work cannot mask them.

**Owes:** `OWE-T07` → T10 and T11: inline-formatted cells and native image/table presentation. Close semantic obligations with T10.S3 and native obligations with T11.S2 evidence.

**Acceptance:** review table/image core fixtures and the native-role separation. Geometry and image authorization remain native checks.

**Handoff:** identify table/cell and image fixture coverage; the next consumers are T10.S3's complete corpus and T11.S2's native integration. Keep T08 literal-helper changes covered by these same table cases.

## Phase exit

T05–T07 are accepted and all supported block fixtures pass. Outgoing inline/native obligations have named owners; block structure, literal protection, and cancellation exits are not deferred.
