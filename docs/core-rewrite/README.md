# C++ core rewrite roadmap

This is the durable entry point for work across sessions: **8 phases, 20 tickets, and 51 slices**. Slices are resumable work units, not estimates of sessions or dates. The current delivery is the documentation package; core implementation requires a subsequent implementation instruction.

## Read the right document

1. Read [repository policy](../../AGENTS.md).
2. Read [STATUS.md](STATUS.md) for the current candidate, active slice, blockers, owes, acceptance, and next action.
3. Read [CONTRACT.md](CONTRACT.md) before starting implementation or changing shared behavior. It is the authoritative record of the agreed scope and technical decisions.
4. Read the active phase below, then its linked owning source and tests. Read another phase only when its dependency or owed obligation is relevant.

| Phase | Definition | Tickets | Slices | Dependency outline |
| --- | --- | --- | --- | --- |
| 0 | [Durable roadmap](phases/00-roadmap.md) | T00 | 3 | Editing and local branch/worktree authorization |
| 1 | [Behavior and baselines](phases/01-behavior-and-baselines.md) | T01–T02 | 5 | T00; T02 can start after T01.S1 evidence |
| 2 | [Portable build and Swift seam](phases/02-core-and-swift-seam.md) | T03–T04 | 6 | T01.S2; ambiguity affecting a fixture blocks that implementation |
| 3 | [Document blocks](phases/03-document-blocks.md) | T05–T07 | 7 | T04 and relevant T01 fixtures |
| 4 | [Inline semantics](phases/04-inline-semantics.md) | T08–T10 | 8 | T05; T10.S3 also requires the complete block coverage |
| 5 | [Mac document integration](phases/05-mac-document-integration.md) | T11–T12 | 5 | T04, T06–T10, and T02 |
| 6 | [Project rules](phases/06-project-rules.md) | T13–T16 | 9 | T03.S1 and T04.S2; independent of full parser completion |
| 7 | [Hardening and closure](phases/07-hardening-and-closure.md) | T17–T19 | 8 | Accepted T12 and T16; final execution on all three OSes |

The table is a navigation summary. Exact prerequisites live in each ticket. Phase numbers organize the documents; they do not prohibit ready work in an independent phase. Phase 7 joins the document and project work.

## Ticket and slice conventions

Every ticket defines Goal, Prerequisites, Inputs, Slices, Blockers, Owes, Acceptance, and Handoff. Each slice names an output, verification, and a checkable exit. IDs such as `T05.S2` are permanent. Add corrective slices with new suffixes and update the totals explicitly; preserve completed IDs and evidence.

A whole-ticket prerequisite such as `T04` means its accepted `done` result. A slice prerequisite such as `T03.S1` means its delivered, verified output; it may be used while the parent ticket awaits acceptance if the current work is authorized. Within a ticket, a slice also requires the preceding sibling's verified output unless its row explicitly says it is independent. Each slice inherits its ticket's prerequisites and owed obligations. Link the evidence used rather than assuming that a check once passed.

### Status

Live state belongs only in [STATUS.md](STATUS.md); phase documents define work, not duplicate progress counters.

| State | Meaning |
| --- | --- |
| `queued` | Work has not started; prerequisites or authorization remain outstanding. |
| `ready` | Prerequisites and required authorization are satisfied. |
| `in_progress` | Work is underway; the handoff states its precise stopping point. |
| `awaiting_acceptance` | Required outputs/checks are supplied, but user acceptance remains pending. |
| `blocked` | A named unresolved condition prevents a particular next action. |
| `done` | Outputs, verification, and applicable user acceptance are recorded. |

Store automated verification, user acceptance, and Git authorization/integration separately. A state label never supplies missing evidence. A session ending does not complete a slice.

### Blockers and owes

A blocker has an ID, resolver, affected slices, concrete resolution condition, and evidence when resolved. An ordinary unfinished dependency remains a prerequisite; use `blocked` when an actual unresolved condition prevents progress. Keep resolved blockers as short records so a later session does not revive them accidentally.

An owe is unfinished work or evidence deliberately assigned to a receiving ticket. It has an ID, originating ticket, recipient ticket(s), closing condition, and closure evidence. Ticket definitions use stable `OWE-Txx` IDs; the live ledger records their activation and closure. Add distinct IDs for newly discovered obligations. An owe cannot defer a failed current exit or waive a prerequisite. Track closure separately for each recipient of a multi-recipient owe. A receiving ticket closes its own receipt with its required evidence before that ticket is accepted; it need not wait for a later recipient to finish. The grouped owe closes when all receipts close. This prevents an owe from creating a reverse dependency on later acceptance.

## Completion and acceptance

- Verify each slice against its stated exit. Record exact commands, candidate identity, results, and limitations; do not use a temporary log path as the sole durable evidence.
- For documentation-only changes, present the diff and obtain user review. No app runtime validation is claimed.
- For core-only changes without changed app flows, present automated evidence for user acceptance. Keep the applicable work awaiting acceptance until that review/PASS is recorded.
- For changed app behavior or UI, provide the exact signed, sandbox-enabled Mac candidate and focused manual steps. User-reported **PASS** gates completion, commits, and merges under repository policy.
- A phase exits when its tickets meet their exits and acceptance requirements, and its outgoing owes have named recipients. A future obligation may remain open only if the current exit permits it. The final phase permits no open required obligation.
- Record authorization and execution for each Git operation. Under [repository policy](../../AGENTS.md#git), user PASS for a verified candidate authorizes commit, merge to main, main push, and merged-branch cleanup unless the user specifically requests a PR. Branch creation and PR publication retain their explicit authorization requirements.

## Resume a session

1. Read the documents in the entry sequence above. Check the live branch, base commit, pending changes, and relevant source/tests before trusting the checkpoint.
2. Select one eligible slice and state the intended behavior and verification. Resolve missing authorization only for the operation that needs it; continue independent authorized work.
3. Recheck old evidence when intervening code, toolchain, OS, or contract changes could invalidate it. Record the reason for rerunning or retaining it.
4. Implement and verify the slice. Keep unrelated changes separate and the current app usable.
5. Update STATUS.md with the handoff below before ending the session, including when work is incomplete or blocked.

## Handoff a session

Record: active ticket/slice; exact implementation state; branch/base commit and uncommitted work; candidate location; commands and outcomes; user acceptance received or pending; actual blockers and new owes; and the exact next action with its prerequisites.

Keep durable summaries and repository-relative evidence links where possible. Large logs may remain outside the repository, but their conclusions, identity, and reproducible commands must survive their deletion. Do not record private document contents or sensitive paths. Update one current checkpoint; retain acceptance and important evidence history in the appropriate ledger rows rather than an unbounded narrative log.

## Documentation-package acceptance

T00 must demonstrate all 20 tickets and 51 slices, acyclic dependencies, a recipient for every owe, checkable exits, working discovery links, and scope/interface decisions owned by CONTRACT.md. A fresh session must be able to resume from these files alone. No app version bump accompanies this package.
