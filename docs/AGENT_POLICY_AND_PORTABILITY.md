# Agent policy and portability assessment

Assessed 2026-11-06. This records recommendations and sizing, not authorization to migrate the app. The user has selected native host-OS UI with standard controls on each platform, without custom components. Windows/Linux are example desktop targets; the second platform and its native toolkit remain unselected.

## Policy adaptation

The reference is Online Lessons / Kamino Studio's `AGENTS.md`, read from the sibling `music_classroom` repository. Marky's revised policy adopts its small slices, explicit module separation, evidence-based verification, concise comments, plain communication, and supervised delegation.

Marky retains its meaningful existing constraints: local branches, user acceptance before task completion/commit/merge, separate Git authorization, restricted branch pushes, focused changes, native Apple interaction, theme tokens, concurrency safety, typed failures, and private logging. Documentation review is now explicitly the acceptance path for documentation-only changes. The blanket SwiftData preference is replaced by using the existing persistence services unless a concrete need justifies a change.

Lesson-specific media rules, the two-peer test setup, roadmap-based version bumps, `scripts/check.sh`, and automatic pushes were not copied. Those facilities and release conventions do not exist here. Layout, fonts, and localized text also stay with each frontend; sharing every presentation decision would undermine platform conventions.

## Apple HIG: authority and retrieval

Use the live [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) as the design authority for the Apple frontend. The [macOS chapter](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) specifically addresses Mac interaction, command access, windows, and keyboard use. Pair it with [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) and [keyboard guidance](https://developer.apple.com/design/human-interface-guidelines/keyboards) for reader and sidebar work.

For Marky, this means reviewing text legibility, keyboard selection and disclosure behavior, focus, menus, resizing, and accessible image/link/table presentation alongside visual appearance. This is application of the guidance to this reader, not a claim that the current UI has passed a fresh HIG audit.

The repository's `.codex/config.toml` configures `@kimsungwhee/apple-docs-mcp` through `npx`. This is a third-party retrieval tool, not Apple's publishing source. Use a documentation connector when it supports the needed page; check its links, API availability, and actual source. For HIG pages that it cannot retrieve, use Apple's website directly. A successful search or API-documentation lookup does not establish that the relevant design chapter was read.

Apple's HIG governs the Apple experience. Future Windows/Linux frontends need their own platform conventions and accessibility verification. Shared Markdown semantics do not require identical widgets or pixel dimensions.

Use each host OS's native framework and standard controls, preserving system styling and behavior. Build Markdown presentation with native text and layout facilities. Theme tokens serve document typography and app layout rather than reskinning controls; custom widgets, custom-drawn controls, and replacement window chrome are outside the selected direction. This policy update does not migrate existing UI code.

## Skills

Keep permanent policy in `AGENTS.md`; load detailed procedures only when needed. This matches OpenAI's distinction between durable project instructions and reusable skills, and its progressive loading of skill instructions. Sources: [Customization](https://learn.chatgpt.com/docs/customization/overview), [Build skills](https://learn.chatgpt.com/docs/build-skills).

The following skills were available in this session; availability is environment-specific, not a repository dependency:

| Skill | Useful Marky work | Limitation |
| --- | --- | --- |
| `writing-for-agents` | Maintain concise policy and useful document pointers | Keep research detail outside the always-loaded rules |
| `codebase-design` | Choose the document/core interface and platform adapters | Does not justify an architecture rewrite by itself |
| `diagnosing-bugs` | Reproduce parsing, access, cancellation, or performance failures | Requires evidence from the actual app and tests |
| `research` | Verify Apple, Swift/C++, parser, and build-system facts | Primary sources and local code remain the evidence |
| `tdd` | Test-first parser/core slices when requested | Tests must express behavior, not mirror implementation |
| `pr` | Describe a requested PR | Does not authorize publishing or changing Git policy |
| `openai-docs` | Verify Codex skills/configuration behavior | Not a source for Apple or C++ implementation facts |

The available `code-review` skill dispatches reviewer subagents, which conflicts with the session-supervisor review policy. Do not invoke that workflow unchanged; the session performs the review itself. Playwright skills do not test native SwiftUI/AppKit UI. Use the existing XCTest/XCUI suites for the Mac app and the selected native test tools for each additional frontend.

No new skill installation is needed for this update. Consider a repository-local verification skill only after a repeatable multi-platform procedure exists; document proven commands there instead of inventing a workflow ahead of the code. OpenAI supports checked-in skills under `.agents/skills`; that directory does not currently exist in Marky. [Source](https://learn.chatgpt.com/docs/build-skills).

## Current architecture: what would move

Source inspection found 15 app Swift files totaling approximately 5,490 lines, excluding tests, assets, and project configuration. These counts describe size, not translation effort.

| Current source | Observation | Portability implication |
| --- | --- | --- |
| `Marky/MarkdownContentBlocks.swift` (992 lines) | Prepared document blocks and custom block parsing share a file with attributed rendering; the file imports SwiftUI and is guarded for macOS | A promising extraction point, but the current file cannot simply become a portable library |
| `Marky/MarkdownViewer.swift` (1,524 lines) | Inline Markdown uses Apple's `AttributedString` parsing; AppKit font styling, link handling, loading, image access, and SwiftUI presentation coexist | Moving only block parsing leaves inline semantics and substantial behavior platform-dependent |
| `Marky/ViewModels/ContentViewModel.swift` (642 lines) | Search, favorites, selection, loading, cancellation, and file-grant lifetimes coexist with SwiftUI state | Extract shared decisions incrementally while keeping native capabilities in adapters |
| `Marky/FileNode.swift` and `Marky/Services/` | Foundation filesystem scanning, native bookmarks, UserDefaults storage, and image/font integration | Share logical rules and data contracts; preserve platform-specific access and persistence implementations |
| `MarkyTests/` and `MarkyUITests/` | Existing regression coverage exercises parsing, rendering, project access, favorites, fonts, and navigation | Reuse behavior fixtures, but preserve Apple UI tests and add independent core tests |

There is currently no C++ source tree, standalone core target, or CMake/CTest configuration. No build or runtime tests were run for this documentation update.

## C++ core: recommendation and alternatives

**A portable C++20 document core fits the selected direction of separate native frontends. Prove one vertical slice before committing to a full migration.** A vertical slice means Markdown bytes entering shared parsing, a platform-neutral document model leaving it, and that model being displayed by the current Mac reader and exercised on a second OS.

The core would own block and inline semantics, links and image references as data, and selected shared project rules. A document model needs semantic runs for emphasis/code/links as well as block structure; returning only block text would leave each frontend to interpret inline Markdown differently. Native adapters retain file permissions, filesystem calls, font/text layout, menus, accessibility objects, settings integration, and image decoding. Return semantic error codes; each frontend supplies localized presentation.

| Route | Benefit | Cost / recommendation |
| --- | --- | --- |
| C++20 core + native frontends | Shared behavior and broad integration options while preserving native UI | Recommended architecture to investigate for the chosen UI direction; every new frontend still requires substantial implementation |
| Existing portable parser + thin Marky model | Avoid maintaining a second handwritten Markdown engine | Evaluate first; it can sit under a C++ core or use a smaller C interface |
| Platform-independent Swift module | Avoid immediate language translation | Worth comparing if the selected second frontend can practically consume Swift; it still needs separate build/toolchain and UI proof |

A shared custom-rendered UI is excluded by the user's decision. Core language and parser selection remain open; choosing native controls does not itself require C++.

[GitHub's cmark-gfm](https://github.com/github/cmark-gfm) is a concrete parser candidate: its C library produces a document tree and adds GFM support to cmark. Its upstream documentation describes C99 portability and CMake builds. Compare its behavior and enabled extensions against Marky's tables, lists, reference links, literal code, images, and Unicode fixtures before choosing it; library conformance does not guarantee compatibility with Marky's current behavior. [Upstream README](https://github.com/github/cmark-gfm/blob/master/README.md).

Swift officially supports C++ interoperability, but the mixed toolchain must agree on the C++ standard library, and Swift cannot catch a C++ exception. An uncaught exception entering Swift terminates execution. Imported containers can also incur copies. Start with a small ownership-aware interface and compare direct Swift/C++ interop with a C interface; do not expose an arbitrary C++ object graph. Sources: [supported features and constraints](https://www.swift.org/documentation/cxx-interop/status/), [mixing Swift and C++](https://www.swift.org/documentation/cxx-interop/).

Use CMake and CTest to build and test an approved core independently. Run it on the claimed OS/compiler combinations; passing on macOS alone proves neither Windows/Linux portability nor frontend parity. [CMake testing documentation](https://cmake.org/cmake/help/latest/guide/tutorial/Testing%20and%20CTest.html).

## Amount of work and confidence

These are engineering estimates from source inspection, not measured migration results. They assume one experienced engineer using agent assistance, the current reader feature set, parser reuse where suitable, and one additional desktop platform with its own native frontend using standard controls. They count implementation and validation effort; they are not predictions of an LLM's unattended running time. Mobile targets or new editing features change the scope.

| Deliverable | Initial effort range | Evidence needed |
| --- | --- | --- |
| Disposable parser/model/build spike | 2–5 engineering days | Current Mac UI consumes one model; the same core builds and passes representative fixtures on the second OS |
| Production shared document core and Mac integration | 3–6 engineering weeks after the spike | Block/inline parity, ownership/error/cancellation handling, adapter tests, performance measurements, signed Mac acceptance |
| First additional desktop frontend at comparable quality | An additional 6–12 engineering weeks | File/folder access, browsing, favorites, typography, tables/images, keyboard/accessibility, persistence, packaging, target-OS acceptance |

The ranges are provisional and should be replaced with measured estimates after the spike. A handwritten parser rewrite, matching every current quirk, additional platforms, or toolkit changes can exceed them. Translating 5,490 lines is not a useful sizing method because much of that code remains platform UI and integration.

There is **no defensible numeric success rate** from repository inspection. Technical confidence is high that a bounded portable parser/model core can be built: official interop and existing portable parser implementations support that judgment. Confidence in schedule and full app parity is lower until the second frontend and text rendering are demonstrated. Stronger LLMs may help implementation, but do not remove those integration and acceptance requirements.

For a future approved spike, use measurable gates:

1. Build and run identical core fixtures on macOS and the chosen second OS, covering Unicode, code literals, references, tables, lists, and malformed input.
2. Render representative block and inline output through the Mac adapter; retain existing regression behavior or explicitly agree on differences.
3. Check resource ownership and errors at the language interface, and measure large-document time and peak memory against a baseline recorded before migration.
4. Exercise the chosen second frontend's selectable text, links, tables/images, keyboard navigation, and accessibility before estimating full delivery.
5. Obtain the user's acceptance before committing to the next migration slice. No migration checklist is marked complete by this assessment.

## Verification of this update

The session reviewed the source findings and revised policy against both repositories' existing rules. `git diff --check` passed; both edited documents passed newline/whitespace checks, and 15 explicit local references plus the plan glob resolved. Only documentation changed; app source, project settings, versions, changelog, and plan completion states remain untouched. The user confirmed acceptance and authorized commit, merge, push, and branch cleanup on 2026-11-06.
