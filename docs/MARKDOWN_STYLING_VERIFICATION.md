# Markdown Styling Verification & Scope Documentation

## Supported Scope
- **GFM Pipe Tables**: Header/body row separation, column alignment (`:---`, `:---:`, `---:`), dynamic per-column bounded widths (`tableCellMinWidth = 80`, `tableCellMaxWidth = 380`), vertically ideal multi-line text wrapping without clipping, full vertical table height via `onGeometryChange` without viewport truncation, horizontal scrolling for narrow viewports, selectable text, and uniform row height fills/borders across wrapped rows.
- **Inline Styling**: Asterisk & underscore emphasis, combined bold & italic, strikethrough, backslash escapes, URL/email autolinks, and HTML entity decoding via Apple `AttributedString` inline parser.
- **Link Label Formatting**: Preserves nested code spans, bold, and italic inside link labels (`[**linked**](url)`, `[Use `tick` here](url)`) while maintaining link destinations and typography font families across sequential same-label links.
- **Reference Links**: Document-wide reference link definition extraction across fenced blocks (`[label][ref]`, `[ref][]`, `[ref]`), first-definition-wins, with strict protection for code blocks, inline code spans, and escaped brackets.
- **Block Structures**: ATX headings (`#`), Setext headings (`===` / `---`), 4-space indented code blocks, fenced code blocks (```` ```` / `~~~`), thematic breaks (`---`, `***`, `___`), task lists (`☐` / `☑`), multi-line list continuations, and nested blockquotes (`▎ `).
- **Images**: Local relative images resolve via standard URL semantics across project folders (e.g., `../Marky/Assets.xcassets/...`), decoding percent escapes (`%20`) and loading asynchronously off the main thread with cancellation. Remote image URLs (`http`/`https`) load asynchronously with tokenized loading placeholders and accessible alt text, with network failure fallback cards.

## Concrete Sandbox & Security Limits
- **Sandboxed Reader**: `ENABLE_APP_SANDBOX=YES` is enforced. No arbitrary HTML, `<script>`, or `<iframe>` execution.
- **Approved Outgoing Network**: `ENABLE_OUTGOING_NETWORK_CONNECTIONS=YES` is configured for remote image loading. Unreachable or invalid URLs safely fall back to the branded fallback card without hanging or crashing.
- **Local Access Boundary**: Local images are authorized via macOS user-selected file/folder sandbox grants, resolving relative and absolute paths without arbitrary external disclosure.

## Test Evidence
- **Automated Test Checkpoint**: Supervisor run verified **102 tests PASS** (96 unit tests + 6 UI tests, 105 runs across parameterized inputs).
- **Automated Unit Tests** (`MarkyTests`): Covers GFM tables, pipe escapes, code protection, nested emphasis, Setext disambiguation, table header bold traits, indented code blocks, document-wide reference links, same-label links, and local image percent-encoded path resolution.
- **UI Geometry Test** (`MarkyUITests`): `testTableGeometryAndRowWrapping` verifies column alignment across rows, multi-line wrapped cell heights (> 40pt vs single-line cells), multi-row intrinsic height (> 150pt), and sequential row vertical positioning within the unclipped table scroll view bounds with an `XCTAttachment` screenshot.
- **Final supervising verification (2026-11-06)**: All 96 unit tests passed after the production fixes. The final focused table UI rerun passed after correcting XCTest's long-text queries, including wrapping, full viewport containment, and height stability; the other five UI regressions passed in the combined run above. No skipped tests.
- **Release verification**: The locally signed Release build and `codesign --verify --deep --strict` passed. Entitlements retain the app sandbox and user-selected read-only access, with the explicitly approved network-client permission. The supervisor visually checked the original Footman ROADMAP through its final row and horizontal scrolling, plus local and remote HTTPS images in Release. Manual user acceptance remains pending.
- **Scope limits**: This native presentation does not claim full CommonMark/GFM conformance. Standalone images render as images; images embedded within paragraph text currently display their alt text. Arbitrary HTML is not executed.

## Manual Acceptance Checklist (Pending User Confirmation)
- [ ] Open `docs/MARKDOWN_SHOWCASE.md` in the Marky reader.
- [ ] Verify GFM pipe tables display with borders, header fill, and zebra striping without raw pipes.
- [ ] Verify the 3-column roadmap table cells wrap onto multiple lines without bottom row truncation.
- [ ] Verify narrow windows enable horizontal scrolling for wide tables.
- [ ] Verify italic and bold markers are parsed and invisible.
- [ ] Verify task list checkboxes render with distinct unchecked (`☐`) and checked (`☑`) states.
- [ ] Verify local mascot image loads from `../Marky/Assets.xcassets/` and remote images load or show fallback cards.
- [ ] Verify switching typography modes (All System / Serif Headings + System Body / System Headings + Serif Body) and text size presets rerenders cleanly.
