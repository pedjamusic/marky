# T01.S1 — Requirement-to-test coverage map

Read this before T01.S2 fixture extraction, T01.S3 characterization, or T02 baseline selection. [CONTRACT](CONTRACT.md) owns behavior; [STATUS](STATUS.md) owns acceptance and blockers. The IDs below identify requirements and gaps, not executable fixtures. T01.S2 assigns fixture IDs and reviewed expected results.

## Evidence boundary

Inspected source: `7e16955ac750efed706566a5b12b0045b66280df` on 2026-11-06, starting from clean `main`. This slice changes documentation only. Source and test assertions were read; no build, unit/UI run, signed app inspection, performance measurement, or new runtime acceptance is claimed. Historical PASS records in [Markdown verification][styling] and [access verification][access] describe their earlier candidates; T02 must establish a fresh baseline.

Evidence notation: **A** = an existing assertion directly checks the stated example; **P** = assertions cover only part of the requirement; **S** = source implementation without a dedicated assertion located; **M** = documented manual acceptance scope. A does not imply exhaustive coverage or a fresh passing run. Every shared row still needs portable fixtures; every native row remains a Mac check.

Test names use `MR` = [MarkdownRegressionTests.swift][mr], `MT` = [MarkyTests.swift][mt], `FO` = [FilesOutlineTests.swift][fo], `UI` = [MarkyUITests.swift][ui], and `BF` = [BundledFontTests.swift][bf]. Names refer to functions, not test descriptions. Source owners: [blocks][blocks], [viewer/inline renderer][viewer], [tree/scanner][tree], [view model][vm], [favorites store][favorites], and [session/image access][session].

### Production path matters

The reader uses `MarkdownDoc.load` → `MarkdownContentBlocks.prepare` → `MarkdownContentBlocks.render` → `MarkdownRenderer.renderInline`. Many older tests call `MarkdownRenderer.render`, a separate line-based whole-document helper. Its assertions are useful evidence but do not automatically establish the production block path's output. In particular, `codeDelimiterRuns` checks a multiline span through the line-based helper, whereas production paragraph preparation joins soft lines before inline parsing. Keep both entry points identified during extraction; resolve G01 before approving affected portable expectations.

## Shared document requirements

Shared outputs are block structure, visible text, semantic traits/ranges, destinations, and literal protection. Fonts, glyph choice, native URL handling, and geometry belong in the next table. Owners name implementation consumers; T01.S2/S3 own extracting and clarifying this evidence first.

| ID | Requirement / current owning functions | Existing evidence and its limit | Gap / receiving slice |
| --- | --- | --- | --- |
| D01 | Normalize CRLF and preserve Unicode text (`sourceLines`, `parse`, inline range iteration). | P: MR.literalCode and MR.codeOffsets cover an emoji before transformed syntax; MT.markdownContentBlocksPrepareLightweightBlocks checks soft-line joining. S: CRLF replacement. | G02: CRLF/empty input/composed and decomposed text; T05.S1/S2, T08.S2/S3, T11.S1. |
| D02 | Paragraph boundaries, soft lines and explicit hard breaks (`proseBlocks`). | A: MT.markdownContentBlocksPrepareLightweightBlocks and MT.markdownContentBlocksSplitProseRhythmBlocks expect joined soft lines. P: MT.markdownRendererPreservesParagraphBreaksAndKeepsFirstHeadingFlush checks helper paragraph spacing. S: two-space/backslash hard-break branch. | G02: exact newlines, trailing escape/space handling and blank inputs; T05.S2, T08.S2. |
| D03 | ATX levels 1–6, Setext headings and thematic-break precedence (`headingLevel`, `proseBlocks`, `isThematicBreak`). | A: MR.setextHeadings, MR.thematicBreaks, MR.tableExactHeaderDelimiterMatch; MT.markdownContentBlocksPrepareLightweightBlocks covers ATX H1. M: showcase levels 1–6. | G03: all ATX levels, closing hashes, missing space, multiline Setext and malformed rules; T05.S2. |
| D04 | Matching fence character/length, allowed indentation, unclosed fences and literal contents (`sourceLines`, `parse`). | A: MR.fenceDelimiters, MR.indentedFenceClosers, MT.markdownContentBlocksSplitFencedCode; P: MR.codeOffsets checks helper output after preceding transformations. | G03: opener indentation/info strings, empty fences and CRLF combinations; T05.S1/S2. |
| D05 | Indented code, tab/four-space handling and literal definition protection (`proseBlocks`, `extractDocumentReferenceLinks`). | A: MR.indentedCodeBlocks, MR.indentedReferenceDefinitionPreservedAsCode. S: tab support, internal blank-line continuation and trailing-blank removal. | G03: paragraph/list adjacency, tabs and blank-line boundaries; T05.S2, T10.S2. |
| D06 | Matched/unmatched backtick runs, padding, Unicode neighbors and protected punctuation (`renderInline`, `findMatchingCodeSpanEnd`). | A: MR.literalCode, MR.codeDelimiterRuns, MR.codeInLinkLabels, MR.punctuationInsideStyledCode; MR.tableCodeSpanBackticksRecognitionAndSplitting directly checks table lexical helpers. P: helper-versus-production distinction above. | G01/G02: multiline route and partially matched runs; T05.S1 lexical helper, T08.S1 final inline semantics. |
| D07 | Ordered/unordered marker data, depth, continuations and task state (`parseListItem`, `preparedListItems`). | A: MR.listContinuation, MR.taskLists, MR.nestedListInsets; MT.markdownContentBlocksPrepareLightweightBlocks and MT.markdownContentBlocksSplitProseRhythmBlocks check mixed ordered/nested items. P: task tests check rendered marker strings, not a portable state enum. | G04: each accepted marker, `)` ordering, tabs, blank lines and container adjacency; T06.S1. |
| D08 | Quote content and depth (`proseBlocks`, `cleanQuoteText`). | P: MR.nestedBlockquotesRendering checks quote glyph substrings and a prepared quote, not exact per-line depth; MT.markdownContentBlocksSplitProseRhythmBlocks checks quote kind. M: showcase multiline/nested quotes. | G04: depth changes, empty quote lines and adjacent lists/tables; T06.S2. |
| D09 | Pipe-table recognition, exact header/delimiter width, alignment and absent outer pipes (`proseBlocks`, `parseTableDelimiterRow`). | A: MR.tableBasicAndAlignment, MR.tableAbsentOuterPipes, MR.tableExactHeaderDelimiterMatch. | G05: full delimiter/precedence matrix and resulting visible cell text; T07.S1. |
| D10 | Escaped pipes and matched/unmatched backtick spans share table lexical behavior (`containsUnescapedPipe`, `splitTableRow`). | A: MR.tableCodeSpanBackticksRecognitionAndSplitting; P: MR.tablePipesEscapedAndInCode checks prepared cell sources, including one substring assertion. | G05: trailing escaped outer pipes, backslash parity and final rendered cell traits/text; T05.S1, T07.S1, T08.S1, T10.S3. |
| D11 | Short/pipe-free rows padded, excess cells dropped, malformed delimiters readable, block boundaries end tables (`proseBlocks`). | A: MR.tableUnevenCells, MR.tableMalformedFallback, MR.tableShortRowsAndQuotedPipes. P: explicit end-boundary tests cover blank lines and quotes; other boundary branches are source evidence. | G05: headings/rules/lists/images/indented and fenced code/Setext boundaries; T07.S1. |
| D12 | Cell/list/heading/quote text receives inline semantics without being reparsed as blocks (`render`, `renderInline`). | P: MR.inlineTextCellHeadingIsolation calls renderInline directly for `#` and `>`; MR.tableHeaderAttributedBoldTrait checks native header bold. M: formatted showcase cells. | G06: full prepared-to-rendered container combinations; T10.S3, T11.S2. |
| D13 | Emphasis/strong/strikethrough, intraword underscore safety and combined traits (`renderInline`, `applyPresentationIntent`). | A: MR.italicEmphasis, MR.boldDoubleUnderscores, MR.boldItalicCombined, MR.strikethrough. P: MR.nestedEmphasisBothWays checks bold at selected positions but does not assert every italic range; MR.punctuationInsideStyledCode covers outer bold/code. | G06: unmatched/adjacent delimiters, boundaries, strike combinations and exact positive/negative ranges; T09.S1/S2. |
| D14 | Escapes and numeric/named entities decode outside literal code (`renderInline`). | A: MR.backslashEscapes and MR.htmlEntitiesAndEmailAutolinks check exact example text; P: escape test does not check all absence-of-style traits. M: showcase additional escaped pipe/tilde examples. | G07: malformed/unknown entities, full accepted table, escape parity and code protection; T08.S2/S3. |
| D15 | Inline links, autolinks/email, parentheses and formatted/code labels preserve destinations and traits (`renderInline`, `detectLinks`). | A: MR.adjacentLinksAndBalancedDestinations, MR.autolinks, MR.htmlEntitiesAndEmailAutolinks, MR.sameLabelLinksWithDifferentAndSameURLs. P: MR.combinedStyles, MR.outerBoldWithInnerItalicInLink, MR.codeInLinkLabels, MT.markdownRendererTransformsInlineElements sample traits/positions; link titles have showcase/source evidence only. | G06/G08: malformed/escaped/nested brackets and destinations, title policy, exact combined ranges; T10.S1. |
| D16 | Document-wide full/collapsed/shortcut references; first definition wins, normalized labels, undefined explicit references remain literal (`extractDocumentReferenceLinks`, `normalizeReferenceLabel`, `substituteReferenceLinks`). | A: MR.referenceLinksWithContext, MR.referenceLabelNormalization, MR.explicitUndefinedReferenceLinks. P: normalization checks ASCII case/whitespace, not full Unicode folding; explicit test also covers unmatched destination parenthesis serialization. | G07/G08: Unicode label behavior, definition/use order and malformed definitions; T10.S2 using T08.S3 data. |
| D17 | References cannot consume definitions or link occurrences in literal code or escaped syntax; invalid destinations remain readable. | A: MR.invalidReferenceDestinationPreserved; P: MR.referenceLinksAcrossFencesAndCodeIsolation checks occurrences across a fence and escaped brackets, not a definition inside the fence; MR.indentedReferenceDefinitionPreservedAsCode checks indented definition text but not absence from the collected map. | G08: shadow definitions inside fenced/indented code and malformed/duplicate cross-block combinations; T05.S2, T10.S2. |
| D18 | Standalone image destination/alt/title data; paragraph images display alt text (`parseStandaloneImage`, `renderInline`). | A: MR.imagesStandaloneAndInline, MR.standaloneImageAngleBracketSpaces. P: parser rejection of bare spaces does not assert final production paragraph fallback. | G08: malformed image fallback, escaped/nested alt labels and inline/reference image interactions; T07.S2, T10.S3. |
| D19 | Malformed/unsupported text stays readable; HTML remains inert (`proseBlocks`, `renderInline`, native view selection). | P: table/link/code malformed examples above. S: native text/image block views; no HTML execution view on the reader path. No dedicated raw HTML regression located. | G09: characterize visible HTML/comments/script-like text and malformed syntax interactions; T05.S2, T08–T10, T12.S1. HTML execution is outside the contract. |

## Native document and presentation checks

These assertions stay native even when their inputs become shared fixtures. Core semantic output cannot prove them.

| ID | Requirement / native owner | Existing evidence and its limit | Gap / receiving slice |
| --- | --- | --- | --- |
| N01 | Apply traits, link attributes, code fonts/backgrounds and Unicode-to-UTF-16 ranges (`renderInline`, `applyPresentationIntent`). | P: MR.literalCode, MR.codeOffsets, MR.combinedStyles, MR.boldItalicCombined, MR.outerBoldWithInnerItalicInLink, MR.sameLabelLinksWithDifferentAndSameURLs sample attributes. | G02/G06: enumerate full runs including negative traits, non-BMP/combining characters, repeated labels and buffer lifetime; T11.S1, T12.S1. |
| N02 | Three typography modes, size presets, heading hierarchy/tracking, first-heading spacing, Light/Dark/System and bundled fonts (`MarkdownTypography`, settings, font service). | A: MT.markdownTypographyModesAreComplete, MT.markdownReaderTextSizePresetsAreComplete, MT.markdownTypographySerifBodyModeIncreasesBodyPointSize, MT.markdownHeadingScaleIsDescending, MT.markdownReaderTextSizePresetsScaleBodyTypography, MT.appearanceModeMapsToColorScheme, MR.headingInlineFontAndTracking; BF.packagedFontsAreDiscoveredAndRegisterTheirActualFamilies, BF.discoverySupportsPackagedResourceLayouts, BF.missingResourcesAreReported, BF.invalidFontReturnsTypedRegistrationFailure. P: MT.markdownRendererPreservesParagraphBreaksAndKeepsFirstHeadingFlush and MT.lightBackgroundTokenMatchesRequestedSurface check selected values. | M: styling/access checklists; visual font/theme/resize coverage remains manual; T11.S1/S2, T12.S2, T19.S2. |
| N03 | Native list/task glyphs, rail/nesting, quote bars/style, readable code surfaces and thematic breaks (`MarkdownViewer`, list/quote/code views). | A: UI.testNestedListChildIsVisiblyIndented. P: MR.nestedListInsets, MR.nestedBlockquotesRendering, MT.markdownRendererConvertsTaskAndBulletMarkers, MT.markdownRendererHandlesFencedCodeBlocks; M: showcase. | G04: exact task/quote appearance, code scrolling/selectability, adjacent-block rhythm; T11.S2, T12.S1/S2. |
| N04 | Bounded table widths, multiline wrapping, full height, column alignment, scrolling, header/row fills/borders and selection (`MarkdownTableView`). | A: UI.testTableGeometryAndRowWrapping, UI.testTableHorizontalScrolling; P: MR.tableGeometryTokens checks bounds, MR.tableHeaderAttributedBoldTrait samples bold. M: [styling scope][styling]. | G05: all alignment appearances, fills/borders, selection, typography/resize combinations; T11.S2, T12.S1/S2. |
| N05 | Local image URL resolution, percent escapes, parent traversal, remote scheme dispatch (`MarkdownImageView`). | A: MR.localImagePathResolutionAndAccessibility checks URL results only, despite its name; MR.remoteURLSchemeNormalization checks allowed/rejected schemes. | G10: accessibility labels/title/fallback and actual remote loading/failure stay native; T11.S2, T12.S2. |
| N06 | Async image decode, cancellation, balanced original folder grants and native grant picker (`LocalImageLoader`, `MarkdownImageView`). | A: MR.localImageLoaderAccess checks injected access counts for success/failure/pre-cancellation. S: project settings enable app sandbox, read-only user-selected files and outgoing network in Debug/Release. M: styling accepted image/grant checklist. | G10: denied start, cancellation during read/decode, stale picker response and real grants; T11.S2, T12.S2. |
| N07 | Latest document request wins; cancellation silent; settings during suspended load applied without reread (`MarkdownDoc`). | A: MR.settingsDuringLoad, MR.alreadyCancelledLateCall, MR.cancelledOrdinaryFailure, MR.documentLifetime use injected suspended preparation. P: tests do not execute real file read/encoding/security-scope work. | G11: UTF-8/UTF-16 decode, unsupported encoding, real I/O failure, off-main work, rerender without reparse; T11.S3, T12.S1/S2. |
| N08 | Native link activation, selectable reading, titlebar, edge fades, menus/settings, keyboard/focus, accessibility and window behavior (viewer, ContentView, WindowChrome). | P: UI.testSidebarSearchAndSelectionDisplaysDocument and UI.testFolderKeyboardNavigationKeepsDisplayedDocument cover only reader selection/retention. M/S: README highlights, styling/access procedures and native views. No dedicated activation/VoiceOver/selection/titlebar/fade regression located. | G10/G12: focused manual native checks; T11.S2, T12.S2, T19.S2. Preserve existing branding; it is presentation, not portable parser policy. |

## Shared project rules and their native boundary

All current project tests run in the Mac target, often with temporary filesystem entries or injected native services. Extract decisions as portable fixtures; retain the native tests for metadata, grants, locale behavior and persistence.

| ID | Requirement / current owner | Existing evidence and its limit | Gap / receiving slice |
| --- | --- | --- | --- |
| P01 | Eligible extensions `md`, `markdown`, `mdown`, `mkd`, case-insensitively; omit hidden/package/nonregular entries (`FileNode.childNodes`). | A: MT.buildProjectTreeFiltersNonMarkdownFiles covers md/markdown vs text; MT.scannerSkipsPackagesAndSpecialFiles covers packages/FIFO/linked FIFO. P: MT.excludedFavoritesAreRetained shows hidden entries are not indexed. S: mdown/mkd/mixed case and other metadata combinations. | G13: full supplied-metadata matrix; T13.S1, native T16.S1. |
| P02 | Skip linked directories; linked regular documents retain distinct project-local identities; directory aliases canonicalized natively (`canonicalDocumentURL`, scanner). | A: MT.buildProjectTreeSkipsDirectorySymlinks, MT.linkedDocumentsKeepDistinctIdentity, MT.projectAliasesShareIdentity. | G13: dangling/inaccessible link target, linked package and repeated identities; T13.S1, T14.S1, native T16.S1. |
| P03 | Build trees, prune document-less folders, distinguish complete/partial/failure input (`buildProjectTree`, `beginOpening`, `singleFileRoot`). | A: MT.buildProjectTreeFiltersNonMarkdownFiles, MT.pickedFileFallsBackAfterParentScanFailure, MT.partialProjectPreservesFavorites, MT.scannerReportsUnreadableChild. P: unreadable-child test returns without assertions for root and is macOS-conditional. | G13/G15: deterministic completeness/unknown fixtures without filesystem assumptions; T13.S2, T16.S1/S2. |
| P04 | Index by project-local identity/relative segments, rebuild without native probing (`fileNodesByRelativePath`, `relativePath`). | P: MT.linkedDocumentsKeepDistinctIdentity, MT.defaultUIFixtureHasProjectLocalIdentity, MT.favoritesPersistAndRestoreForProject exercise index consumers. No direct full index/parent-rebuild fixture located. | G14: index rebuild/lookup/identity assertions; T14.S1, T16.S2. |
| P05 | Empty search returns all, descendant matches retain ancestors, folder-name match retains the folder with filtered children (`filterNodes`). | A: MT.displayedNodesTracksRootAndSearchQuery checks descendant match/ancestor retention and selection-independent cache. P: UI.testSidebarSearchAndSelectionDisplaysDocument checks a filename query. S: folder-only matches/whitespace query branches. | G14: exact folder-only and empty/trimmed query results; T14.S2, T16.S2. |
| P06 | Favorite search also matches relative path; native collation orders directories first and favorite ties by path (`favoriteMatchesQuery`, scanner/favorites sorting). | P: MT.favoritesSectionRemainsVisibleAndFiltersBySearch checks filename filtering/empty section, not path-only queries or locale ordering. S: localized lowercase/compare and tie-break code. | G14: path-only queries, same filename ties and supplied order; T14.S2 portable decisions, T16.S2 native locale tests. |
| P07 | Favorite membership persists per project; only complete authorized absence probes prune; partial/unknown/excluded entries survive (`beginOpening`, `confirmedMissingFavorites`, store). | A: MT.favoritesPersistAndRestoreForProject, MT.missingFavoritesArePrunedWhenProjectOpens, MT.partialProjectPreservesFavorites, MT.pickedFileFallsBackAfterParentScanFailure, MT.excludedFavoritesAreRetained. P: inaccessible unknown probes lack a dedicated direct assertion. | G15: independent complete/partial/unknown decisions; T15.S1, native T16.S2. |
| P08 | Apply reconciliation to latest saved state, retain edits while probes suspend (`beginOpening`). | A: MT.favoriteEditsDuringReopenArePreserved checks add/remove edits and an independent store update during an injected probe. P: uses an in-memory store, not separate running windows. | G15: portable latest-state fixtures and real persistence integration; T15.S2, native T16.S2. |
| P09 | Alias migration only for opened grant, merges dictionary data, retains unknown legacy keys (store, `beginOpening`). | A: MT.favoritesStoreMigratesAliasKeys, MT.favoritesAliasMigrationDefersUnknownLocations, MT.projectAliasesShareIdentity. P: actual canonicalization/grant provenance remain native. | G15: portable authorized/unauthorized decision inputs; T15.S2, native T16.S2. |
| P10 | Untrusted persisted relative paths validated before native probing (`confirmedMissingFavorites`, `relativePath`). | S: rejects absolute/out-of-root standardized paths. No dedicated traversal/absolute/malformed-path test located. | G15: invalid segment/path matrix and proof no outside probe occurs; T15.S1/S2, T16.S2. |

## Native project/access checks

| ID | Requirement / native owner | Existing evidence and its limit | Gap / receiving slice |
| --- | --- | --- | --- |
| A01 | Failed or obsolete opens preserve active project; explicit open wins over restoration (`beginOpening`, `restoreBookmarkIfNeeded`). | A: MT.failedScanRetainsCurrentProject, MT.supersedingAndClosingScans, MT.restorationRespectsPendingExplicitOpen. | G11/G15: exercise through integrated adapter and actual failed/unavailable locations; T16.S1/S3, T19.S2. |
| A02 | Activate original grant before inspection, balance it on failure/supersede/close/deallocation, retain parent grant on partial fallback (view model/resource access). | A: MT.restorationAccessOrderAndUnavailableBookmark, MT.projectAliasesShareIdentity, MT.failedScanRetainsCurrentProject, MT.supersedingAndClosingScans, MT.partialFallbackRetainsParentScope, MT.pendingRequestDeallocationBalancesAccess. P: recording doubles prove call order/counts, not OS permission restoration. | G15: exact signed sandbox candidate and picker/relaunch checks; T16.S1/S3, T19.S2. |
| A03 | Persist/restore bookmarks and favorites; failures have safe localized messages; import routing clears mode (`ProjectSessionService`, view model). | A: MT.restoreBookmarkIfNeededMapsBookmarkResolutionFailure, MT.openPickedFolderMapsBookmarkEncodingFailure, MT.handleFileImporterResultRoutesAndClearsMode, MT.handleFileImporterResultMapsFailureAndClearsMode. P: injected services. M: [access checklist][access] covers relaunch/disconnected locations without per-step PASS records. | G15: real grants, unavailable bookmarks, single-file restoration and persistence after relaunch; T16.S3, T19.S2. |
| A04 | Native folder row/disclosure/keyboard navigation, collapse-all, search expansion, selection/favorite updates and hover affordance (outline/row views). | A: FO.rowTapAndCollapseAllRemoveChildrenFromVisibleOutlineRows, FO.searchExpansionPreservesManualFolderState, FO.newlyAttachedRowShowsFavoriteUnderStationaryPointer, FO.selectionAndFavoriteChangesRetainExpandedFolderAndVisibleChild; UI.testCollapseFoldersHidesPreviouslyExpandedChildren, UI.testFolderRowTapTogglesChildren, UI.testFolderKeyboardNavigationKeepsDisplayedDocument. P: MT.selectNodeTogglesFolderExpansion, MT.sidebarSectionsToggleIndependently cover state; no assertion specifically for ⭐ appearance located. | G12: large trees, repeated rebuilds, focus/accessibility/active-favorite appearance; T16.S3, T19.S2. |

## Gap handoff

These are missing evidence, not permission to add Markdown features or change accepted behavior. T01.S2 extracts available examples with independent expected results. T01.S3 characterizes ambiguous/unasserted cases and updates fixtures; register actual consumer blockers in STATUS. Portable project fixtures are delivered by T13–T15; their evidence gaps below do not invent a new prerequisite on T01 for phase 6.

| Gap | Required evidence / resolution | Owner and consumers |
| --- | --- | --- |
| G01 | Compare production preparation/renderInline with whole-document helper for multiline/partially matched code spans. `codeDelimiterRuns` expects `Before ``unclosed tick after` from an unmatched outer double run plus paired inner singles; do not replace that evidence with a blanket “all malformed runs literal” assumption. Approve route-specific expected text/traits against the current app and clarify T08.S1 wording if needed. | T01.S3; B04 in STATUS guards affected T08.S1 expectations. T01.S2 can extract unaffected cases. |
| G02 | Add exact CRLF/empty input, soft/hard breaks, escaped newline, composed/decomposed labels, emoji/non-BMP/combining-mark text and range expectations. UTF-16 file decoding stays native. | T01.S2/S3 → T05, T08, T11.S1/S3. |
| G03 | Complete headings/rules/fences/indented-code boundary matrix from current production behavior, including malformed openers/closers. | T01.S2/S3 → T05.S1/S2. |
| G04 | Record list marker/task/depth/continuation and quote depth per line, plus adjacency; keep current glyph/inset appearance in native assertions. | T01.S2/S3 → T06.S1/S2, T11.S2. |
| G05 | Complete table boundary/escape/code-run cases and rendered cell expectations; retain existing geometry UI tests and add focused visual cases where assertions are absent. | T01.S2/S3 → T07.S1, T08.S1, T10.S3, T11.S2. |
| G06 | Review exact visible text and all trait/destination ranges, including absence of unwanted traits, for nested emphasis/link/code and each block container. | T01.S2/S3 → T09, T10.S1/S3, T11.S1. |
| G07 | Characterize actual normalization/entity behavior; `lowercased()` is the current label implementation, not evidence of full Unicode case folding. Version/provenance/offline data checks belong to T08.S3. | T01.S2/S3 → T08.S2/S3, T10.S2. |
| G08 | Add protected shadow definitions, duplicate/undefined/malformed references, destination/title/bracket cases and malformed/inline image fallback. | T01.S2/S3 → T07.S2, T10.S1/S2/S3. |
| G09 | Capture readable inert HTML and malformed-input output across production blocks and inline parsing; current absence of HTML execution infrastructure does not prove exact visible text. | T01.S3 → T05/T08–T10, complete T12.S1 parity. |
| G10 | Exercise actual local/remote image success/failure, mid-load cancellation, stale grants, caption/alt accessibility, native link opening and selectable content. | T02 baseline procedures; T11.S2, T12.S2, T19.S2 signed/native checks. |
| G11 | Real decoding/I/O/cancellation/latest-request evidence and large document/folder responsiveness, beyond injected loader/scan tests. Fixed runtime/memory measurements must follow T02. | T02.S1/S2; T11.S3, T12.S1, T16.S1/S3, T17.S3. |
| G12 | Native appearance, menus, resizing, keyboard/focus and accessibility, including ⭐ favorites and unchanged branding/titlebar. Unit state/token tests and UI geometry tests cover only their assertions. | T12.S2 document acceptance; T16.S3 project acceptance; T19.S2 final native acceptance. |
| G13 | Metadata/tree completeness fixture matrix with extensions/case/hidden/packages/special/link entries, empty branches and failure/unknown inputs. | T13.S1/S2; native enumeration T16.S1. |
| G14 | Direct index/rebuild, folder-only/path-only/empty query, same-name tie and supplied-order fixtures; native locale matching stays native. | T14.S1/S2; native T16.S2. |
| G15 | Full complete/partial/unknown availability, validated relative paths/no outside probes, latest-store reconciliation and authorized-alias decisions; signed real grants/relaunch remain separate. | T15.S1/S2; T16.S1/S2/S3 and T19.S2. |

## Review and next use

T01.S1's review artifact is this map and its linked source/test evidence. Check that every documented syntax family and critical project/access invariant appears above, that shared decisions and native assertions have separate owners, and that unasserted cases retain their gap IDs. Consult STATUS for user acceptance; this document alone closes neither T01 nor OWE-T00.

Next slice T01.S2: assign stable fixture identities, copy representative inputs, and independently record structure/text/traits/destinations/literal expectations with the exact current entry point. Use T01.S3 for the unresolved cases above. T02.S1 may consume this verified inventory before all T01 fixtures are accepted, following its own authorization and baseline requirements. Keep the production Swift reader selected.

## Static verification

Run from the repository root. This checks discovery links, unique requirement/gap IDs, and that all 104 existing unit-test functions and seven focused UI-test functions are referenced by their actual names. It checks inventory integrity; assessing assertion strength requires reading the linked tests as done for this map. It does not run those tests.

```bash
git diff --check
python3 - <<'PY'
from pathlib import Path
import re
p = Path('docs/core-rewrite/T01-S1-COVERAGE.md')
s = p.read_text().split('## Static verification')[0]
files = dict(MR='MarkyTests/MarkdownRegressionTests.swift',
             MT='MarkyTests/MarkyTests.swift', FO='MarkyTests/FilesOutlineTests.swift',
             UI='MarkyUITests/MarkyUITests.swift', BF='MarkyTests/BundledFontTests.swift')
for prefix, filename in files.items():
    names, pending = set(), False
    for line in Path(filename).read_text().splitlines():
        pending |= '@Test' in line or bool(re.match(r'\s*func test', line))
        match = re.search(r'\bfunc (\w+)\(', line)
        if match and pending:
            names.add(match[1])
            pending = False
    refs = set(re.findall(r'\b' + prefix + r'\.(\w+)', s))
    assert names == refs, (prefix, names - refs, refs - names)
    print(prefix, len(names), 'mapped functions')
full = p.read_text()
links = re.findall(r'\[[^\]]+\]\(([^)]+)\)', s)
links += re.findall(r'^\[[^\]]+\]:\s+(\S+)', full, re.M)
assert all((p.parent / link.split('#')[0]).exists() for link in links)
for pattern, count in [(r'^\| ([DNPA]\d{2}) \|', 41), (r'^\| (G\d{2}) \|', 15)]:
    ids = re.findall(pattern, s, re.M)
    assert len(ids) == len(set(ids)) == count
assert set(re.findall(r'\bG\d{2}\b', s)) == set(re.findall(r'^\| (G\d{2}) \|', s, re.M))
print('PASS: links, 41 requirements, 15 gaps, 111 mapped test functions')
PY
```

[mr]: ../../MarkyTests/MarkdownRegressionTests.swift
[mt]: ../../MarkyTests/MarkyTests.swift
[fo]: ../../MarkyTests/FilesOutlineTests.swift
[ui]: ../../MarkyUITests/MarkyUITests.swift
[bf]: ../../MarkyTests/BundledFontTests.swift
[blocks]: ../../Marky/MarkdownContentBlocks.swift
[viewer]: ../../Marky/MarkdownViewer.swift
[tree]: ../../Marky/FileNode.swift
[vm]: ../../Marky/ViewModels/ContentViewModel.swift
[favorites]: ../../Marky/Services/ProjectFavoritesStore.swift
[session]: ../../Marky/Services/ProjectSessionService.swift
[styling]: ../MARKDOWN_STYLING_VERIFICATION.md
[access]: ../CODE_QUALITY_VERIFICATION.md
