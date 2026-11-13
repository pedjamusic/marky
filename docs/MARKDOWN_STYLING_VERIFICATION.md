# Markdown Styling Verification & Scope Documentation

## Supported Scope
- **GFM Pipe Tables**: Header/body row separation, column alignment (`:---`, `:---:`, `---:`), dynamic per-column bounded widths (`tableCellMinWidth = 80`, `tableCellMaxWidth = 380`), vertically ideal multi-line text wrapping without clipping, full vertical table height via `onGeometryChange` without viewport truncation, horizontal scrolling for narrow viewports, selectable text, and uniform row height fills/borders across wrapped rows. Table bodies accept pipe-free short rows padded to the column count, terminate strictly on block boundaries (blank lines, blockquotes, headings, rules, lists, images, code), ensure quotes with pipes become quotes rather than rows, and share backtick code-span matching between row splitting and pipe detection.
- **Inline Styling**: Asterisk & underscore emphasis, combined bold & italic (verified with both traits / obliqueness across font families), strikethrough, backslash escapes, URL/email autolinks, and HTML entity decoding via Apple `AttributedString` inline parser.
- **Link Label Formatting**: Preserves nested code spans, bold, and italic inside link labels (`[**linked**](url)`, `[Use `tick` here](url)`) while maintaining link destinations and typography font families across sequential same-label links.
- **Link Hover**: The link under the pointer uses the macOS accent color. SwiftUI supplies the bounds of the visible link runs, including each line of a wrapped label. Moving away restores the resting color. Links keep their underline and native text selection and activation.
- **Reference Links**: Document-wide reference link definition extraction across fenced blocks (`[label][ref]`, `[ref][]`, `[ref]`), first-definition-wins, with strict protection for code blocks, inline code spans, and escaped brackets. Reference labels are normalized with internal whitespace collapsing and consistent case-folding. Invalid reference destinations (`http://[bad`) remain source text. Explicit full reference links (`[foo][bar]`) never fall back to shortcut references when undefined. Link destinations containing parentheses are serialized safely with angle brackets.
- **Block Structures**: ATX headings (`#`), Setext headings (`===` / `---`), 4-space indented code blocks, fenced code blocks (```` ```` / `~~~`), thematic breaks (`---`, `***`, `___`), task lists (`☐` / `☑`), multi-line list continuations, and nested blockquotes (`▎ `).
- **Images**: Local relative images resolve via standard URL semantics across project folders (e.g., `../Marky/Assets.xcassets/...`), decoding percent escapes (`%20`) and loading asynchronously off the main thread with cancellation. Standalone images accept angle-bracket destinations with spaces (`![alt](<my photo.png>)`) while rejecting unbracketed spaces. Remote image URLs (`http`/`https`, case-insensitive) load asynchronously with tokenized loading placeholders and accessible alt text, with network failure fallback cards. When local images are denied sandbox access, a user-initiated "Grant Folder Access…" button presents a native `NSOpenPanel` to grant the containing folder under security scope.

## Concrete Sandbox & Security Limits
- **Sandboxed Reader**: `ENABLE_APP_SANDBOX=YES` is enforced. No arbitrary HTML, `<script>`, or `<iframe>` execution.
- **Approved Outgoing Network**: `ENABLE_OUTGOING_NETWORK_CONNECTIONS=YES` is configured for remote image loading. Unreachable or invalid URLs safely fall back to the branded fallback card without hanging or crashing.
- **Local Access Boundary**: Local images are authorized via macOS user-selected file/folder sandbox grants, resolving relative and absolute paths without arbitrary external disclosure. If an image is located outside the initial grant, the user can explicitly grant the containing folder via native `NSOpenPanel`.

## Test Evidence
- **Automated Unit Tests** (`MarkyTests`): Covers GFM tables, pipe escapes, matched backtick spans in table splitting and pipe detection, short row padding and blockquote termination, nested emphasis, Setext disambiguation, table header bold traits, indented code blocks, document-wide reference links, reference label normalization, invalid reference destination preservation, undefined reference protection, safe angle-bracket destination serialization, remote URL scheme normalization, and local image loader security-scoped access/cancellation.
- **UI Geometry & Scrolling Tests** (`MarkyUITests`):
  - `testHoverHighlightsOnlyTheLinkUnderThePointer`: compares rendered link screenshots before and after pointer movement across two links with the same destination and nearby plain text.
  - `testTableGeometryAndRowWrapping`: verifies column alignment across rows, multi-line wrapped cell heights (> 40pt vs single-line cells), multi-row intrinsic height (> 150pt), and sequential row vertical positioning within the unclipped table scroll view bounds with an `XCTAttachment` screenshot.
  - `testTableHorizontalScrolling`: verifies that a wide 8-column table fixture initially places distant target cells outside the viewport and smoothly scrolls them into view via native horizontal scroll interactions.
- **CodeRabbit Review Fixes (2026-11-06)**: Addressed all 11 inline findings, two test nits, and the destination/scheme concerns in the review summary. Supervisor-reviewed regression coverage includes unmatched destination parentheses, distinct fenced/inline/escaped reference occurrences, and balanced image security-scope access on success, failure, and cancellation.
- **Final automated results**: 104 unit tests passed (107 runs including parameters), recorded in `/tmp/MarkyMarkdownReview/Logs/Test/Test-Marky-2026.11.06_02-25-03-+0100.xcresult`. All seven UI tests passed in the preceding combined run (`Test-Marky-2026.11.06_02-23-06-+0100.xcresult`); that run's two unit-fixture failures were corrected and covered by the final unit run. The horizontal-scroll test verifies the complete target cell enters the viewport. The user reported manual validation **pass** on 2026-11-06.
- **Scope limits**: This native presentation does not claim full CommonMark/GFM conformance. Standalone images render as images; images embedded within paragraph text currently display their alt text. Arbitrary HTML is not executed.

## Manual Acceptance

The user reported **pass** on 2026-11-06 for the reviewed Markdown reader changes. The following checklist records the acceptance scope:
- [x] Open `docs/MARKDOWN_SHOWCASE.md` in the Marky reader.
- [x] Verify GFM pipe tables display with borders, header fill, and zebra striping without raw pipes.
- [x] Verify short table rows without pipes are padded and displayed as valid rows.
- [x] Verify quotes with pipes immediately following tables are rendered as blockquotes.
- [x] Verify the 3-column roadmap table cells wrap onto multiple lines without bottom row truncation.
- [x] Verify narrow windows enable horizontal scrolling for wide tables.
- [x] Verify italic and bold markers are parsed and invisible.
- [x] Verify task list checkboxes render with distinct unchecked (`☐`) and checked (`☑`) states.
- [x] Verify local mascot image loads from `../Marky/Assets.xcassets/` and remote images load or show fallback cards.
- [x] Verify local images without folder permission show the "Choose Folder…" / "Grant Folder Access…" button and load once granted.
- [x] Verify switching typography modes (All System / Serif Headings + System Body / System Headings + Serif Body) and text size presets rerenders cleanly.
