# MEMORY

## 2026-03-08 Performance + Memory Audit

- Active branch during implementation: `codex/perf-memory-audit-pass`
- Completed a focused internal optimization pass aimed at launch/startup waste, sidebar recomputation, markdown rerender churn, and Swift 6 strict-concurrency alignment.

## What Landed

- Removed unused SwiftData startup/container setup and the dead `Item` model.
- Sidebar rendering no longer uses recursive `AnyView`; filtering is cached in the ViewModel instead of rebuilding tree clones on each redraw.
- Markdown loading now prepares lightweight parsed blocks once, then rerenders from cached prepared state for typography and appearance changes.
- Reader loading uses structured concurrency, keeps more work off the main actor, and avoids holding duplicate whole-document state longer than needed.
- Project targets now build with Swift 6 strict concurrency enabled.

## Manual Validation Outcome

- Manual review in this session: performance gains were felt as smoother interaction, but Debug Navigator numbers still looked higher than desired for a simple markdown viewer.
- Observed during debug-run validation:
  - brief CPU spikes around `10%` on file switch
  - up to roughly `25%` while scrolling
  - memory rising from around `50 MB` toward a stable `~80 MB`, with interaction spikes above `100 MB`
- Decision: accept this pass as a codebase-quality improvement and continue feature work.

## Next Likely Step

- Re-run a deeper performance/memory audit around `0.5.0`, preferably in Instruments on Release builds rather than relying on Debug Navigator alone.
- Focus that later pass on:
  - scroll-time CPU cost
  - steady-state memory after repeated document switches
  - whether SwiftUI text/layout becomes the dominant hotspot versus markdown preparation

## Guardrails

- Keep treating markdown parse work and file I/O as background-friendly work, with main-actor publication only where UI state requires it.
- Prefer measured profiling before further refactors; the next pass should be hotspot-driven, not speculative.

## 2026-03-07 Typography Wrap-Up

- Active branch during implementation: `codex/typography-spec-remaining`
- Typography system pass is now in a releasable state after manual validation in this session.

## What Landed

- Token-driven markdown typography is split into dedicated files:
  - [MarkdownTypography.swift](/Users/pedja/Projects/Marky/Marky/MarkdownTypography.swift)
  - [MarkdownContentBlocks.swift](/Users/pedja/Projects/Marky/Marky/MarkdownContentBlocks.swift)
- Markdown reader supports three typography modes:
  - all system
  - serif headings + system body
  - system headings + serif body
- Fenced code blocks render as dedicated literal-content blocks with horizontal scrolling and no wrapping.
- Paragraph/list/heading rhythm is applied through typography tokens instead of depending on source-file blank lines alone.
- List markers are aligned to the document rail and use a tightened marker gap chosen during manual review.
- Appearance + typography settings are already exposed through App Settings and `Cmd+,`.

## Settled Values / Decisions

- Keep list marker gap at `bodyFontSize * -0.04` unless a later typography pass proves otherwise.
- Serif modes naturally consume more vertical space because of:
  - slightly larger body size
  - line-spacing derived from font size
  - Literata wrap/metric differences
- Do not try to force serif and sans to occupy identical viewport height.

## Next Likely Step

- Add three subtle reader text-size presets on top of the existing typography system:
  - slightly smaller
  - default
  - slightly bigger
- Implement as a top-level scale over typography tokens, not as per-block overrides.

## Guardrails

- Follow `AGENTS.md` section 5.4: keep UI token-driven and low-churn.
- Avoid reintroducing text jump, ghosting, or resize instability.
- Keep using [TODO_MARKDOWN_TYPOGRAPHY_TRANSIENT.md](/Users/pedja/Projects/Marky/_plans/TODO_MARKDOWN_TYPOGRAPHY_TRANSIENT.md) as the full typography reference.
