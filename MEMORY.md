# MEMORY

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
