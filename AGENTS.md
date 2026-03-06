# AGENTS

Repository-wide standing instructions for coding agents. This file provides guidance to coding agents when working with code in this repository.
For repository conventions and local workflow, this is the source of truth.
If anything here conflicts with other repository docs, **AGENTS.md wins**.

## 1. Agent Operating Rules (Do These Always)

### 1.1 Work style

1. **Read before writing**: inspect relevant files and patterns already used in the repo.
2. **Small PRs**: keep changes minimal and focused.
3. **Prefer existing abstractions**: reuse patterns, naming, state mgmt, and DI already present.
4. **Don’t “refactor for fun.”** Only refactor when it removes real risk or unlocks required changes.

### 1.2 Safety (repo + user data)

- **Never commit secrets** (API keys, signing configs, service accounts).
- If you find secrets in git history or files: **stop** and document the finding + remediation steps.
- Avoid adding new telemetry. If needed, **document what/why** and ensure opt-in/out.

### 1.3 No destructive commands by default

EVER!

### 1.4 Always leave the repo better

Any change that affects behavior must include at least one of:

- a test, or
- updated docs, or
- clear repro steps + verification notes in the work summary

## 2. Git Workflow (Solo Dev)

Mandatory default workflow for coding agents in this repository:

1. For every new task, create a new local branch from `main`.
2. Do all implementation and verification on that branch.
3. Describe work done, after it is done.
4. Wait for manual testing confirmation, before proceeding with the git process.
5. Ask to proceed with the git process, as a last precautionary step. Manual testing is a must for UI changes and difficulty/modifier behavior.
6. Check of task in `TODO.md` only after all prior steps are confirmed and completed.
7. Go though documentation files (If atomic increment versioning is used, update CHANGELOG.md, if parent versioning is used, update CHANGELOG.md, ROADMAP.md, README.md) and update them as needed, paying attention to versioning.
8. Commit only after the task is battle-tested and received confirmation, as seen in step 5.
9. Merge the task branch into local `main`.
10. Safely delete the merged local branch.
11. Push only `main` to remote (after it is battle-tested and proven glitch-free).
12. Update/check off `ROADMAP.md` only as the final step, after successful automated tests, meaningful manual testing, and completion of the git process above.

Additional rule:

- Do not push task branches to remote unless explicitly requested.

### 2.1 Changelog Flow (Prevent Churn)

- Do not use an `## [Unreleased]` section for this solo workflow.
- Add changelog bullets directly under the correct versioned section (`## [x.y.z] - YYYY-MM-DD`) once the version/date is known.
- If a feature is implemented before the release version is finalized, keep notes locally and add the changelog entry when cutting the version.
- Avoid standalone "changelog-only sync" commits unless correcting an actual mistake.
- `ROADMAP.md` tracks planned/in-progress milestones; `CHANGELOG.md` tracks already implemented changes on `main` under dated version entries.

### 2.2 Marketing Track Flow (User-Facing Wins)

- When a change is clearly user-visible and potentially launch/promotional-worthy, add a short entry to `MARKETING_TRACK.md` in the same work session (after implementation is validated).
- Prefer user benefit/outcome language first; keep technical details optional and concise.
- `CHANGELOG.md` remains the technical source of truth. `MARKETING_TRACK.md` is the curated source for website/social/app-store messaging.

## 3. Quality Gate

- Battle-test and analyze before submitting for manual testing.
- Submit to manual test when meaningful (for example UI changes, or difficulty/modifier behavior).
- Keep roadmap status unchecked while implementation is in-flight; check it off only after the full quality gate and git workflow are complete.

### 3.1 Manual-Pass Hard Gate (No Exceptions)

- Agents must **not** mark any task/sub-task as complete in `TODO.md` (`[X]`) until the user explicitly reports manual validation as **`pass`** in the current session.
- Agents must **not** commit, merge, or finalize a task branch before manual `pass` for UI changes and behavior changes.
- If automated checks pass but manual validation is missing, keep task status as in-progress and explicitly wait for manual result.
- If a task was marked complete prematurely, agents must immediately revert that checklist state and note that manual pass is pending.

## 4. Rule Of Thumb

- If it is a stable rule agents should always follow: `AGENTS.md`.
- If it is milestone-level product tracking: `ROADMAP.md`.
- If it is execution-level implementation checklisting: `TODO.md` using `[ ]` / `[X]`.
- If it is personal or transient notes: `MEMORY.md`.
- At session start, consult `MEMORY.md` for feature context and prior-session summaries; treat it as supplemental context, not policy.

## 5. Coding Standards (Concrete)

### 5.1 General

- DRY principles
- Zero-cost abstractions
- Code simplicity
- Deep module encapsulation ("A Philosophy of Software Design" by John Ousterhout)

### 5.2 Architecture & Style

- **Prefer Composition:** Use Protocols and Extensions over deep inheritance.
- **SwiftUI First:** Unless specified otherwise, build UI using SwiftUI with a focus on @StateObject or the newer @Observable macro (iOS 17+).
- **Concurrency:** Use async/await and Task blocks. Avoid legacy completion handlers ((Result<T, Error>) -> Void).
- **Error Handling:** Use custom Error enums and do-catch blocks rather than returning nil for failures.
- **Swift Concurrency (Swift 6):** Strict concurrency checking is mandatory to eliminate data races. Ensure all shared data structures conform to Sendable and use actor for protecting mutable state.
- **Modern Data Management:** Use SwiftData for persistent storage, allowing for more declarative and concise data modeling compared to CoreData.
- **Safety First:** Avoid force unwrapping (!). Use if let, guard let, and nil-coalescing (??) to handle optionals safely.
- **Architecture and Structure:** Implement the MVVM (Model-ViewModel) pattern. Use struct for data models (value types) and @Observable classes for ViewModels.
- **SwiftUI Best Practices:** Keep views lightweight and declarative. Move business logic to ViewModels and use proper state management (@State, @Binding, @Environment).
- **Build Efficiency & API:** Use private for internal methods to improve compile times. Leverage modern Swift's automatic type inference, which has reduced header sizes.
- **AI and Tooling:** Leverage AI assistants (like ChatGPT/Claude) in Xcode 26 to help generate code, but verify with Instruments (Time Profiler, Leaks) to ensure app performance.
- **Testing & Debugging:** Use Instruments to detect memory leaks, CPU spikes, and battery drain, which are harder to spot in complex SwiftUI apps.
- **Networking:** Use URLSession with async/await for robust asynchronous networking.

#### Consult & Study:

[Performance under Xcode Build System](https://developer.apple.com/documentation/xcode/build-system)

- [Configuring your project to use mergeable libraries](https://developer.apple.com/documentation/xcode/configuring-your-project-to-use-mergeable-libraries)
- [Improving the speed of incremental builds](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds)
- [Improving build efficiency with good coding practices](https://developer.apple.com/documentation/xcode/improving-build-efficiency-with-good-coding-practices)
- [Building your project with explicit module dependencies](https://developer.apple.com/documentation/xcode/building-your-project-with-explicit-module-dependencies)

[Security and privacy under Xcode Build System](https://developer.apple.com/documentation/xcode/build-system)

- [Verifying the origin of your XCFrameworks](https://developer.apple.com/documentation/xcode/verifying-the-origin-of-your-xcframeworks)
- [Enabling enhanced security for your app](https://developer.apple.com/documentation/xcode/enabling-enhanced-security-for-your-app)
- [Creating enhanced security helper extensions](https://developer.apple.com/documentation/xcode/creating-enhanced-security-helper-extensions)
- [Adopting type-aware memory allocation](https://developer.apple.com/documentation/xcode/adopting-type-aware-memory-allocation)
- [Conforming to Mach IPC security restrictions](https://developer.apple.com/documentation/xcode/conforming-to-mach-ipc-security-restrictions)

### 5.3 File Organization

New Views: Place in Views/ folder.

ViewModels: Place in ViewModels/ and ensure they are decoupled from UIKit dependencies.

Resources: Assets and Strings should be accessed via SwiftGen or standard Text(LocalizedStringKey("")).

### 5.4 UI Reusability + Tokenization (Durable Policy)

- Prioritize stable, predictable UI behavior via reusable primitives (drag-and-drop-level consistency target).
- Split action primitives by intent and layout contract:
  - intrinsic/action buttons
  - fill/expanding buttons
- Keep width policy explicit in component APIs; avoid screen-local `SizedBox`/`IntrinsicWidth` patches as the default approach.
- Route repeated action-row patterns through shared primitives; avoid one-off parent-wrapper drift.
- Preserve accepted baseline behavior/styles where explicitly validated (for example Practice Library action controls) unless the task requires a documented change.
- Keep visual system DRY and token-driven:
  - foundation tokens: color, typography, spacing, radius, elevation, motion
  - semantic aliases mapped from foundation tokens (for example `error`, `warning`, `success`, mastery tiers)
- Components should consume tokens/semantic aliases, not local hardcoded visual constants.

### 5.5 Error handling

- Never swallow exceptions silently in the play loop.
- Prefer:
  - typed failures for domain logic
  - user-safe messages in UI
  - structured logs for debugging

### 5.6 Logging

- No PII in logs.
- Add logs sparingly in performance-sensitive loops.

## 6. Testing Strategy (Minimum Bar)

Agents must add/maintain tests proportionate to the change.

### 6.1 Required tests for scoring changes

- Unit tests for each timing window boundary.
- Golden test vectors:
  - given input events → expected score breakdown

### 6.2 UI changes

- Widget tests for key flows (lesson start, pause, results screen)
- If visuals matter, add golden tests (only if the repo uses them).

## 7. Commands (Agents: use these first)

### 7.1 Linting & Formatting

Don't let the agent clutter your codebase with inconsistent indentation. Use these if you have the tools installed via Homebrew.

- SwiftFormat (Auto-fix):
  `swiftformat .`

- SwiftLint (Check violations):
  `swiftlint lint --strict`

- Format specific file:
  `swiftformat {{file_path}}`

### 7.2 Dependency Management (SPM)

If you’re using Swift Package Manager, these commands help the agent manage libraries without opening the Xcode sidebar.

- Resolve Dependencies:
  `swift package resolve`

- Update Packages:
  `swift package update`

- Reset Package Cache:
  `rm -rf .build/ && rm -rf ~/Library/Caches/org.swift.swiftpm/`

- Filter Build Errors Only:
  `xcodebuild -scheme [YourScheme] build | grep -A 5 "error:"`

---

## 8. Dependency Policy

Agents must be conservative with dependencies:

- Prefer stdlib or existing packages already in the repo.
- If adding a package:
  - explain why alternatives won’t work
  - ensure license is compatible
  - keep the dependency surface small

Avoid major upgrades unless asked.

---

## 9. Security & Privacy Checklist (Especially for Kid-Facing Apps)

Before introducing:

- user accounts
- analytics/telemetry
- recordings (audio)
- social sharing
- cloud sync

…you must:

- document data collected and retention
- provide opt-out where feasible
- avoid collecting sensitive data
- ensure COPPA/GDPR-K compliance considerations are documented (even if not fully implemented yet)

---

## 10. If You’re Unsure

Agents should:

- Search the codebase for the dominant pattern and follow it.
- Prefer adding a small adapter layer rather than rewriting existing systems.
- Update **AGENTS.md** if you discover mismatches with reality.

---
