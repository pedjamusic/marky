# AGENTS

Repository-wide rules for coding agents (Codex, Claude, etc.).

If anything conflicts with other documentation, **AGENTS.md wins**.

Agents must read this file before making changes.

# 1. Agent Operating Rules

Work style:

- Read existing code before writing.
- Prefer existing abstractions and patterns.
- Keep changes small and focused.
- Do not refactor unless necessary.

Safety:

- Never commit secrets.
- If secrets are discovered, stop and report.

Repo hygiene:

Behavior-changing work must include at least one of:

- tests
- documentation updates
- verification notes

Destructive commands require explicit user approval.

# 2. Git Workflow (Solo Dev)

Mandatory workflow:

1. Create a branch from `main`.
2. Implement and verify on that branch.
3. Describe work completed.
4. Wait for **manual testing confirmation**.
5. Ask before starting git operations.
6. Mark `_plans/*TODO*.md` tasks complete **only after confirmation**.
7. Update docs/changelog if behavior or versions change.
8. Commit only after confirmation, validation and docs updates.
9. Merge branch into local `main`.
10. Delete merged branch, if no longer needed.
11. Push **only `main`** to remote once battle-tested.

Additional rule:

Do **not push task branches** unless explicitly requested.

# 3. Quality Gate

Agents must battle-test changes before requesting manual testing.

Manual testing required especially for:

- UI changes
- difficulty/gameplay modifiers
- behavioral logic changes

Agents must **not** mark tasks complete, commit, or merge until the user reports manual validation as **pass**.

# 4. Rule of Thumb

Use the correct file:

`AGENTS.md` → permanent agent rules  
`_plans/_TODO_.md` → execution checklists  
`MEMORY.md` → session notes/context
`AGENTS.md` defines policy.

# 5. Coding Standards

"Simplify, then add lightness." — Colin Chapman

## 5.0 Design

Follow Apple Human Interface Guidelines.

## 5.1 General

- DRY principles
- code simplicity
- zero-cost abstractions
- deep module encapsulation

## 5.2 Architecture & Style

Architecture:

- MVVM
- SwiftUI-first

Guidelines:

- Prefer composition over inheritance
- Use async/await
- Avoid legacy completion handlers
- Use typed errors
- Avoid force unwrap `!`

Concurrency:

- strict concurrency checking
- shared mutable state protected with actors
- shared types conform to Sendable

Persistence:

- prefer SwiftData

SwiftUI:

- lightweight declarative views
- business logic in ViewModels
- correct state management (@State, @Binding, @Environment)

## 5.3 File Organization

Follow the dominant structure already used in the repository.

If creating new modules:

Views -> `Views/`
ViewModels -> `ViewModels/` (and ensure they are decoupled from UIKit dependencies )
Resources -> assets / localized strings (should be accessed via SwiftGen or standard `Text(LocalizedStringKey(""))`)

When working inside an existing feature/module, keep files within that module’s structure rather than creating new top-level folders.

## 5.4 UI Reusability

Use token-driven design system.

Foundation tokens:

color  
typography  
spacing  
radius  
elevation  
motion

Components must consume tokens rather than hardcoded values.

## 5.5 Error Handling

Never silently swallow exceptions.

Prefer:

- typed domain failures
- user-safe messages
- structured logs

## 5.6 Logging

- No PII
- Minimal logging inside performance-sensitive loops
