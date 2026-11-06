# T01.S2 — Shared Markdown compatibility corpus

The [JSON corpus](../../MarkyTests/Fixtures/markdown-compatibility.json) contains 40 hand-authored fixtures, `MD-001`–`MD-040`. Inputs and expected values were transcribed or adapted from the existing tests, accepted showcase, and owning production source identified in each fixture's `evidence`. These are supporting provenance references, not claims that every adapted input already had an exact assertion. Expected results were written before executing the corpus, independently of parser output. The [Swift checks](../../MarkyTests/MarkdownCompatibilityTests.swift) compare them with the current production reader. There is no replacement parser in this slice.

User approval is recorded separately in [STATUS](STATUS.md). Passing tests alone do not approve this behavior contract or close T01. No app source, version, parser selection, native UI, or dependency changes accompany this corpus.

## Format and reuse

The UTF-8 JSON file has a `version` and a `fixtures` array. Version 1 has the following contract:

- Each fixture has a permanent `id`, coverage-map `requirements`, supporting `evidence`, exact Markdown `input`, and ordered expected `blocks`. JSON escapes preserve CRLF, tabs, backslashes and newlines. IDs are never renumbered or reused.
- Each block has a `kind` and only the fields listed below. Empty input produces an empty block array. Order and all visible text are significant.
- An inline `runs` array contains contiguous `{text, traits, destination?}` values. Traits are ordered `strong`, `emphasis`, `strike`, `code`; the array includes every applicable trait and is empty for plain text. Missing `destination` means no link. Adjacent runs with identical traits and destination are merged. Empty inline content has no runs.
- Text comparison preserves exact Unicode scalar spelling, including decomposed combining marks. Concatenation gives the complete visible text. Cumulative UTF-8 byte lengths give portable run ranges; the Mac check additionally inspects every UTF-16 code unit, including both halves of a surrogate pair. Explicit line breaks remain LF in text; a future semantic model may represent these as break nodes while comparing the same visible text and traits.
- Destinations are data, never fetched or activated by these tests. Native file grants, path resolution, decoding, loading and link opening remain separate checks.

| Block kind | Expected fields besides `kind` |
| --- | --- |
| `heading` | `level` (1–6), `runs` |
| `paragraph` | `runs` |
| `code` | Exact literal `text`; do not interpret inline syntax or references |
| `list` | `items`: ordered `{depth, marker, runs}` values. Depth starts at zero. Marker is `bullet`, `taskUnchecked`, `taskChecked`, or the preserved ordered number/delimiter string such as `2)`. Native bullet/checkbox glyph choice is excluded. |
| `quote` | `lines`: ordered `{depth, runs}` values, with depth starting at one. Native bars/insets are excluded. |
| `table` | `headers` (array of runs arrays), `alignments` (`left`/`center`/`right`), and `rows` (array of cell arrays, each cell a runs array). Missing cells are empty arrays; excess cells are dropped. |
| `thematicBreak` | None |
| `image` | `alt`, `destination`, optional `title`. This denotes a standalone image; inline images currently contribute alt text to paragraph runs. |

The fixture data uses no Swift types, NSRanges, font names, absolute filesystem paths, or new core interface declarations. Standalone core tests can read this same file and project semantic results to this contract. A JSON test-data reader in a future development harness does not introduce a shipped parser/runtime dependency; its implementation belongs to the receiving slice.

## Production checks and limits

The executable path is `MarkdownContentBlocks.prepare(from:)`, followed by `MarkdownRenderer.renderInline` on prepared content with the block's document-wide reference map. It does **not** call the older line-based `MarkdownRenderer.render(from:)` helper. Inline content is rendered in plain body context to exclude implicit heading/table-header font styles from semantic expectations. Native attributes are projected to complete traits and destinations, including absence of unwanted styles/links. Code blocks compare exact text without inline rendering.

List marker glyphs are translated to the portable values above. Quote source markers provide per-line depth; the simple quote cases render each line independently. Cross-line quote emphasis is not covered here and remains G04/G06 characterization. No recursive Markdown interpretation is introduced in this test projection.

The tests also call the actual `MarkdownContentBlocks.render(preparedBlocks:)` path and compare every heading/paragraph/list body/code/quote/table-cell visible string and image alt value. Expected quote nesting indicators are added only for that native text check. This second check covers production container wiring; semantic traits are checked at the inline seam. Native heading/header fonts, colors, geometry, accessibility and image/link operations retain their existing tests and manual acceptance owners (N01–N08).

## Review index

Each JSON fixture includes the source/test names used to write its expectation. `MarkdownRegressionTests` and `MarkyTests` refer to their files in `MarkyTests/`; `MARKDOWN_SHOWCASE` refers to the accepted [showcase](../MARKDOWN_SHOWCASE.md). Owning functions live in [block preparation](../../Marky/MarkdownContentBlocks.swift) and [inline rendering](../../Marky/MarkdownViewer.swift).

| Fixtures | Review focus | Map requirements |
| --- | --- | --- |
| MD-001–003 | Empty/blank input, CRLF normalization, soft lines and paragraph separation | D01–D02 |
| MD-004 | Emoji and decomposed `e` + combining acute before bold/link/code; exact runs | D01, D06, D13, D15 |
| MD-005–007 | ATX levels 1–6, Setext headings and thematic-break forms | D03, D12 |
| MD-008–011 | Backtick/tilde fence length, invalid closer suffix/indentation, unclosed fence, literal syntax | D04, D17 |
| MD-012 | Indented literal code between paragraphs | D05 |
| MD-013–014 | Matched delimiter runs, embedded backticks and code inside link labels | D06, D13, D15 |
| MD-015–018 | List nesting, continuations, all checkbox states, ordered delimiters and bullet forms | D07, D12 |
| MD-019 | Quote depth per line and exact native nesting text | D08 |
| MD-020–021 | Table alignments and omitted outer pipes | D09 |
| MD-022 | Escaped pipe and matched code-span pipe, complete cell traits | D10, D12 |
| MD-023–025 | Pipe-free short row padding, excess-cell dropping, quote boundary, malformed width fallback | D08–D11 |
| MD-026 | Block-like cell text stays inline; header/cell emphasis and strike | D12–D13 |
| MD-027 | Combined/nested emphasis, full positive/negative traits, intraword underscore safety | D13 |
| MD-028–029 | Escaped syntax, entities, and literal code protection | D06, D14 |
| MD-030–032 | Adjacent/repeated labels, balanced destinations, URL/mail autolinks, formatted link labels | D13, D15 |
| MD-033 | Full/collapsed/shortcut references, case normalization and first definition wins | D16 |
| MD-034 | Document-wide references before/after a fence; fenced, inline-code and escaped occurrences protected | D16–D17 |
| MD-035–036 | Undefined explicit reference and invalid destination remain readable | D16–D17 |
| MD-037–039 | Standalone alt/destination/title, bracketed spaces, inline-image alt text | D18 |
| MD-040 | Indented definition remains literal and cannot populate the reference map | D05, D17 |

## T01.S3 handoff

These fixtures are a reviewable starting corpus, not closure of the S1 gap matrix. Preserve G01/B04: multiline and partially matched code-span expectations have **not** been approved or silently inferred from the older helper. Assign new stable IDs during characterization and compare the production and helper routes explicitly.

Still outstanding under the existing gap owners: exact two-space/backslash hard-break handling and escaped newlines; composed/decomposed reference-label normalization and broader entity behavior; heading/fence/indentation boundary matrices; cross-line/empty quotes and list adjacency; complete table delimiter/escape/block-boundary cases; unmatched and combined style edge cases; protected shadow definitions in fences; malformed/nested link and image/title behavior; and inert HTML visible output (D19/G09). See [G01–G09](T01-S1-COVERAGE.md#gap-handoff). G10–G12 remain native/baseline obligations; portable project fixtures remain T13–T15 (G13–G15).

T01.S2 may be accepted for the unaffected corpus while B04 remains open. T01.S3 must record evidence or explicit consumer blockers for the remaining ambiguous cases before T01/OWE-T00 closes. User review/PASS and Git integration are separate ledger entries.

## Reproduce

Run from the repository root with the toolchain recorded in STATUS:

```bash
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' \
  -derivedDataPath /tmp/MarkyT01S2 test -only-testing:MarkyTests
git diff --check
```

`MarkdownCompatibilityTests.productionCorpus` runs all stable fixtures; `corpusIntegrity` checks identities, provenance presence and block field shapes. Existing unit tests remain in the same run. This test-only slice changes no interaction, so it does not establish a new signed sandbox/native acceptance baseline or require an app UI change review. T02 retains its own full baseline work.
