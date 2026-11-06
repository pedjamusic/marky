# Core rewrite contract

This records the decisions approved in the roadmap conversation on 2026-11-06. It governs the planned implementation; the planning-package delivery itself is documentation only. Live progress and any later user-approved contract amendments belong in [STATUS.md](STATUS.md). Repository policy remains authoritative for workflow and permissions.

## Scope and dependencies

Build a **Marky-owned C++20 parser and shared project-rule library**, integrate it into the existing Mac app, and execute core tests on macOS, Windows, and Linux. Native Windows/Linux app interfaces, packaging, and acceptance are later projects. Mobile support, editing, synchronization, plugins, and new Markdown features are outside this migration.

Ship no third-party parser code and introduce no mandatory third-party runtime libraries or services. Standard OS/compiler libraries are allowed. Checked-in Unicode and entity data tables are allowed with their versions, provenance, and required notices. Tools used to generate such data are development tools; ordinary builds and application execution must require neither downloads nor external data services.

Existing native preferences, favorites, and bookmark persistence remain in place. This migration does not select a cross-platform persistence format or replace them with a new framework.

## Document semantics

The document module accepts validated UTF-8 text and returns an immutable semantic document. It owns block and inline interpretation, reference resolution, and syntax precedence. Its public data types have no Apple or other platform UI dependency.

- Blocks cover headings, paragraphs, lists with nesting/marker/task data, quotes with nesting, literal code, tables with column alignment, thematic breaks, and image references.
- Inline content carries text, combined emphasis/strong/strikethrough/code traits, link destinations, and explicit breaks. Frontends apply presentation rather than reparsing Markdown.
- Link/image destinations, alt text, and titles are data. Filesystem resolution, access grants, network requests, image decoding, and activation are native operations.
- The current accepted behavior takes precedence over CommonMark/GFM differences. Full standards conformance is a separate goal. Use the published [CommonMark](https://spec.commonmark.org/) and [GFM](https://github.github.com/gfm/) specifications as references for owned code, not as authorization to change behavior.
- Preserve malformed/unsupported Markdown as readable content according to the characterized fixtures. Literal code and escaped syntax must remain protected. HTML must remain inert; there is no HTML execution or web-based renderer in this scope.

T01 establishes the executable compatibility corpus from the current code, tests, and accepted reading examples. It must include CRLF/Unicode, matching and unclosed fences, code-span edge cases, headings and rules, lists/continuations/tasks, quote depth, table delimiters/escaped pipes/code spans/uneven and pipe-free short rows, and reference/link precedence and malformed destinations. Document-wide references must not consume definitions inside protected code.

Preserve standalone images as native images and paragraph-embedded images as alt text. The shared model can identify inline image semantics; doing so does not authorize richer native presentation during this rewrite.

Implement block/reference discovery followed by inline interpretation. Use delimiter/bracket tracking and reusable literal recognition instead of repeated whole-string substitutions. The lexical helper needed for table splitting must exist before that consumer is implemented; its final inline behavior is completed in T08 without creating a dependency cycle.

## Project rules

The project module owns Markdown-file eligibility, empty-folder pruning, logical indexing, ancestor-preserving filtering, favorite membership, and conservative reconciliation. It receives native metadata and returns decisions/results; it makes no filesystem calls.

Native adapters supply opaque entry identities, project-relative path segments, entry metadata, complete/partial scan information, matching results, and language-sensitive ordering. C++ must not assume POSIX/Windows absolute path spelling, resolve symlinks, or equate a portable identity with a sandbox grant. Keep directory aliases canonicalized by the native scanner while linked documents retain their project-local identities.

Preserve these existing rules through tests:

- Eligible document extensions remain those currently supported by FileNode. Hidden/package/nonregular entries and linked directories keep their current inclusion/traversal rules. Empty document-less folders are omitted.
- The native adapter retains its language-sensitive filename search and ordering. The core retains ancestor folders on descendant matches and supports the distinct favorite relative-path search behavior.
- A successful full scan is complete. An unreadable subtree fails that candidate; a separately characterized single-file fallback is explicitly partial.
- Failed or obsolete opens preserve the active project. Request publication and cancellation generation checks remain native.
- Only complete, authorized probes confirming absence may prune favorites. Partial views and unknown/inaccessible availability preserve saved favorites.
- Reconciliation applies to the latest saved state so concurrent window/user edits survive. Alias migration occurs only for an explicitly opened grant; native identity/persistence adapters perform the actual migration I/O.

Validate untrusted relative-path data before any native probe. Do not reinterpret path segments as permission to access a location.

## Native document adapter

The Mac frontend remains Swift/SwiftUI with AppKit text and system integration. It owns fonts, theme/typography metrics, layout, standard controls, window/menu behavior, keyboard/focus behavior, accessibility objects, localized messages, and native image/link operations. Future frontends implement those roles with their host OS facilities.

The Swift adapter translates semantic runs into native attributed strings, accounting for Unicode and native text range conventions. Styling changes rerender the cached semantic document without rereading or reparsing it. Preserve link traits, literal code styling, table geometry/scrolling, quote/list presentation, and current image authorization/fallback flows.

Keep blocking reads and core work off the main actor. Preserve current latest-request behavior, settings changes during suspended loads, and silent cancellation of obsolete work. Security scopes start/stop on the original native granted URL; logical identities do not replace lifetime URLs.

The existing production reader remains selected during parser development. Switch it only after T12 parity gates. The migration adds no user-facing parser selector and no silent production fallback between parsers. Retire superseded code under T18 after accepted integration.

## Boundary and lifetime

The public seam is a small **C-compatible interface implemented in C++**. Expose opaque result handles, explicit release, length-delimited UTF-8, fixed-width status values, and semantic accessors. Keep STL containers, C++ exceptions, native UI types, and raw parser internals out of this interface. Concrete declarations are implemented in T04 against these requirements; this document does not invent an unused full header in advance.

- Inputs are borrowed only for the duration of a synchronous call. A completed result owns the storage behind its accessors; returned views expire when that result is released.
- The Swift adapter copies completed results into immutable `Sendable` values and releases core handles before publishing them. Keep mutable result ownership confined to its worker; lifetime/cancellation safety must be tested before asserting cross-thread safety.
- Typed failures distinguish invalid input, cancellation, allocation failure, and internal errors. Malformed Markdown is ordinarily readable content, not an exceptional failure. Native frontends supply user-safe localized messages without leaking document contents or private paths.
- Catch C++ exceptions inside the interface. Destruction/cleanup must not throw. Use RAII internally and test partial-construction and injected-failure cleanup.
- A thread-safe cancellation token can be requested from another thread while work checks it throughout parsing/project loops. Its lifetime must outlast the operation. Cancellation yields no partially published document/project.
- Calls use independent per-operation state. Tests must cover repeated/concurrent operations and initialization. Shared mutable caches/registries are unnecessary for this slice.

## Build and portability

Build a static core with C++20, an independent CMake/CTest build, and a dependency-free test executable. Debug and Release tests must both detect failures; disabled C/C++ `assert` statements alone are insufficient for the test harness.

Add a local Swift package over the same production sources for static Xcode integration. CMake is the standalone cross-platform build; SwiftPM supplies the Mac build integration, not a Swift requirement for Windows/Linux core consumers. Keep the production source sets consistent and build them without fetched dependencies. [SwiftPM package/target documentation](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html).

Required execution families are macOS/Apple Clang, Windows/MSVC, and Linux/GCC. Record exact OS, compiler, architecture, configuration, candidate revision, and commands when each is run. A configured job or a successful Mac run is not Windows/Linux execution evidence. Do not claim support for untested additional architectures or native frontends.

## Verification and performance

Use identical core fixtures and expected semantics on all three OSes. Native search collation and presentation are explicitly platform-specific and verified through adapter tests rather than identical cross-OS UI output.

Keep current Mac unit/UI coverage, adding relevant regressions for owned behavior. Exercise cancellation, malformed input, Unicode, repeated/concurrent calls, argument validation, handle lifetime, and allocation failures. Use compiler sanitizer/fuzz tooling during hardening; it adds no shipped runtime dependency.

T02 records fixed representative large-document/folder inputs, repeatable procedures, processing-time medians, peak memory, and cancellation observations. T17 repeats them on comparable hardware/build configurations. The approved gate is **no more than 20% regression in median processing time or peak memory** on those fixed fixtures. Missing or incomparable evidence leaves that gate open. Explain measurement variability and investigate failures before cutover/final closure; changing the gate requires an explicit contract amendment.

Final Mac acceptance uses an exact signed, sandbox-enabled candidate, with failed/unavailable access, relaunch restoration, rapid switching/cancellation, settings, large folders/documents, and affected reading/navigation behavior. User-reported **PASS** and executed three-OS core tests are both required for final completion. Repository Git authorization remains separate.
