# Agent rules

Marky is a local-file Markdown reader. The current app is Swift/SwiftUI with AppKit integration on macOS; the product direction is cross-platform with a native host-OS UI on each platform. Preserve reading quality, responsive navigation, and user-granted file access.

This file defines repository policy and takes precedence over other repository documentation. Read it before changing files.

## Read when relevant

- `README.md`: current features, toolchain, and build/test commands. Confirm versions in the project settings before reporting them.
- `docs/core-rewrite/README.md`: entry point before C++ core planning, implementation, portability work, or handoff; follow its contract, active phase, and status ledger.
- `_plans/*TODO*.md`: execution checklists. Check their scope and status before treating an old plan as active.
- `docs/CODE_QUALITY_VERIFICATION.md`: project access, favorites, sidebar, and signed sandbox acceptance procedures.
- `docs/MARKDOWN_STYLING_VERIFICATION.md` and `docs/MARKDOWN_SHOWCASE.md`: Markdown behavior and reading examples before parser or renderer work.
- `docs/AGENT_POLICY_AND_PORTABILITY.md`: rationale for these rules, skills assessment, and C++ migration options before portability work. This is an assessment, not migration authorization.
- `CHANGELOG.md`: released behavior. `MEMORY.md` is historical context, not policy; update it only when asked.

## Workflow

- Read the owning code and tests first. Work on one small, reviewable slice; reuse existing patterns and keep unrelated refactors separate.
- State the intended behavior and how it will be verified. For a large feature, architecture change, or new dependency, propose a short design and get approval before implementation. An explicit implementation request authorizes work within its agreed scope.
- Measure performance and inspect library behavior instead of assuming. Report what passed, what remains untested, and any material uncertainty.
- Add only the abstractions, options, and files the current slice needs. Comments explain why; longer external-library or OS explanations belong in `docs/` with a short code pointer.
- Keep secrets out of source and logs. If a secret is discovered, stop and report without reproducing it. Destructive operations require explicit approval.

## Architecture and portability

- Today there is no C++ core or CMake build. Keep the current app working; this policy does not authorize a rewrite.
- Separate reusable document and project rules from platform integration as touched code permits. Before adding logic, ask whether another platform would need the same rule. Keep that rule independent of SwiftUI/AppKit; keep file grants, bookmarks, native filesystem operations, window/menu behavior, fonts, drawing, and localized presentation in platform adapters.
- SwiftUI-first and MVVM apply to the Apple frontend. Views describe UI; ViewModels coordinate observable state and platform services. They are not requirements for another platform's frontend.
- Each frontend uses its host OS's native UI framework and standard controls. Share document behavior through the core; implement presentation separately for each platform.
- If a C++ core is approved, use C++20, an independent CMake/CTest build, and a narrow Swift adapter as the only crossing point. The core owns document semantics and shared policy; its public types must not depend on Apple or other platform UI frameworks. Specify ownership, string encoding, cancellation, and errors; C++ exceptions must not escape into Swift.
- Keep existing persistence services for preferences, favorites, and bookmarks. Choose shared data formats deliberately; introduce SwiftData only for a demonstrated Apple-specific need, not as the portable model.
- Follow the existing feature/file structure. Extract duplication when copies must change together or when a shared module has a concrete caller; avoid speculative folders and layers.

## Design and implementation

- For Apple UI, consult the official [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/), especially [macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), and [keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards). Use Apple API documentation for implementation details. A documentation tool is a retrieval aid, not a replacement for checking the source and API availability.
- Build screens from standard host-OS controls with system styling and behavior. Do not introduce custom widgets, custom-drawn controls, or replacement window chrome. Use native text and layout facilities for Markdown presentation.
- Preserve native keyboard navigation, focus, menus, resizing, accessibility, and Light/Dark/System appearance. Future frontends follow their target platform's conventions while sharing document behavior.
- Use system styling and metrics for controls. Consume existing theme and typography tokens for document content and app layout without overriding native control appearance. Give meaningful repeated constants names; keep layout and font decisions in the frontend.
- Use Swift 6 strict concurrency, async/await, explicit actor isolation for shared mutable state, and Sendable values across concurrency domains. Keep blocking work off the main actor and preserve cancellation and latest-request behavior.
- Prefer composition, typed failures, and user-safe localized messages. Handle failures explicitly; document intentional fallback and cancellation paths. Avoid force unwraps. Log minimally without document contents, private paths, or other personal data.
- Preserve the active project on failed opens, balance security-scoped access, and retain favorites when availability is unknown. Treat sandbox permissions as platform capabilities, not portable path identities.

## Verification and acceptance

- Behavior changes need relevant regression tests where practical, plus documentation or verification notes explaining coverage and limits. Tests assert observable behavior; demonstrate that they catch the defect when feasible.
- Build and run the relevant unit tests using the commands in `README.md`. Run UI tests for changed interactions; broaden checks for cross-cutting changes. A future core must also pass its independent tests on the claimed target platforms.
- Before handing off UI or behavioral changes, exercise affected flows, failures, cancellation, and representative large files/folders as applicable. Sandbox restoration requires a signed, sandbox-enabled app; an unsigned or UI-test-only run is insufficient evidence.
- Give the user the exact candidate and focused manual steps. User-reported **PASS** gates task completion, commits, and merges. Documentation-only changes need user review of the diff rather than an app test; do not claim runtime validation for them.
- Mark `_plans/*TODO*.md` items complete only after the applicable user confirmation. Keep unfinished work explicit. Update docs/changelog for changed behavior or versions; use the existing versioned changelog convention and do not bump an app version for policy-only edits.

## Git

- Read-only Git inspection is allowed. Ask before Git mutations unless that operation is already authorized in the conversation; approval for a branch is not approval to commit, merge, or push.
- Work on a local `codex/` branch from `main`, after checking for existing user changes. Use separate worktrees for concurrent sessions; preserve unrelated work.
- After verification and user acceptance, obtain Git authorization, commit the focused changes, merge into local `main`, and delete the merged branch if no longer needed and authorized.
- Push only battle-tested `main`. Push a task branch or open a pull request only when explicitly requested. Never rewrite or force-push `main`.

## Skills and delegation

- Use available skills when their actual scope fits; read their `SKILL.md` and announce first use. Skills supply procedures; user instructions and this repository's rules govern scope and Git permissions. If a skill is unavailable, report the gap and use a suitable direct workflow where possible.
- For policy edits use `writing-for-agents`; for module seams use `codebase-design`; for difficult failures use `diagnosing-bugs`; for sourced investigations use `research`. Use `tdd` when test-first work is requested and `pr` when writing a requested PR description. Browser skills apply to browser surfaces, not the native app.
- Delegate bounded exploration or implementation when useful. For Codex, explorers use `gpt-6-luna` at suitable effort; implementers use `gpt-6.1-sol` at low or medium effort, below the session's effort. Keep the session model as supervisor; it reviews every result and runs the required final checks itself. Never spawn a reviewer or substitute an older model. If the configured model/effort is unavailable, keep the work in the session and report the limitation. Update model names when the user changes the model policy.
- Explain decisions plainly for a frontend developer who is not a C++/Swift specialist. Define unfamiliar terms and ask one focused question at a time with a recommendation.
