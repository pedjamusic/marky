# Core rewrite status

Updated: 2026-11-06. This is the authoritative live ledger. [README](README.md) defines status/acceptance conventions; [CONTRACT](CONTRACT.md) owns scope and interface decisions. Phase files define work rather than duplicating state.

## Current checkpoint

- Current task: documentation package only; core implementation has not started.
- Active work: publish the accepted T00 documentation as a PR for the user's requested CodeRabbit review. Core implementation remains queued.
- Candidate: repository `docs/core-rewrite/` package plus one discovery line each in README.md and AGENTS.md on `codex/cpp-core-roadmap`.
- Repository baseline: clean `main` at `be3710a` before drafting. Recheck live Git state before applying; this is an evidence snapshot, not a permanent branch assumption.
- Durable files: this directory is the review candidate. Temporary drafting/check scripts are supplementary and are not needed to resume from the repository.
- Automated verification: 8 phase documents, 20 tickets, 51 slices, all required fields, 19 owed-work definitions, 216 relative links/anchors, slice-state coverage, and the manually transcribed dependency graph checked; whitespace and patch applicability passed. No app build/runtime checks were run.
- User acceptance: the user accepted the documentation delivery ("great") and requested a PR for CodeRabbit on 2026-11-06. The external review is a separate pending check; subsequent changes require applicable review again.
- Publication work: commit the 11 new roadmap documents and two discovery additions, push this task branch, and open the requested PR. App source, project settings, version, and changelog are unchanged.
- Next action: publish the PR, request CodeRabbit's review of the plan, and record its URL/outcome. T01.S1 remains queued until core work is subsequently requested. Merge/push of main remains unauthorized.

## Ticket and slice state

All tickets started queued. T00 now has user acceptance for documentation delivery and checks; the requested external review is tracked separately. Within the slice column, a range such as S1–S3 names each of those stable slice IDs.

| Ticket | Phase definition | Ticket state | Slice state | Verification / acceptance |
| --- | --- | --- | --- | --- |
| T00 | [00](phases/00-roadmap.md) | done | T00.S1 done; T00.S2 done; T00.S3 done | Documentation checks passed (E00); user accepted delivery and requested external review. |
| T01 | [01](phases/01-behavior-and-baselines.md) | queued | T01.S1 queued; T01.S2 queued; T01.S3 queued | Not implemented; no verification or acceptance claimed. |
| T02 | [01](phases/01-behavior-and-baselines.md) | queued | T02.S1 queued; T02.S2 queued | Not implemented; no verification or acceptance claimed. |
| T03 | [02](phases/02-core-and-swift-seam.md) | queued | T03.S1 queued; T03.S2 queued; T03.S3 queued | Not implemented; no verification or acceptance claimed. |
| T04 | [02](phases/02-core-and-swift-seam.md) | queued | T04.S1 queued; T04.S2 queued; T04.S3 queued | Not implemented; no verification or acceptance claimed. |
| T05 | [03](phases/03-document-blocks.md) | queued | T05.S1 queued; T05.S2 queued; T05.S3 queued | Not implemented; no verification or acceptance claimed. |
| T06 | [03](phases/03-document-blocks.md) | queued | T06.S1 queued; T06.S2 queued | Not implemented; no verification or acceptance claimed. |
| T07 | [03](phases/03-document-blocks.md) | queued | T07.S1 queued; T07.S2 queued | Not implemented; no verification or acceptance claimed. |
| T08 | [04](phases/04-inline-semantics.md) | queued | T08.S1 queued; T08.S2 queued; T08.S3 queued | Not implemented; no verification or acceptance claimed. |
| T09 | [04](phases/04-inline-semantics.md) | queued | T09.S1 queued; T09.S2 queued | Not implemented; no verification or acceptance claimed. |
| T10 | [04](phases/04-inline-semantics.md) | queued | T10.S1 queued; T10.S2 queued; T10.S3 queued | Not implemented; no verification or acceptance claimed. |
| T11 | [05](phases/05-mac-document-integration.md) | queued | T11.S1 queued; T11.S2 queued; T11.S3 queued | Not implemented; no verification or acceptance claimed. |
| T12 | [05](phases/05-mac-document-integration.md) | queued | T12.S1 queued; T12.S2 queued | Not implemented; no verification or acceptance claimed. |
| T13 | [06](phases/06-project-rules.md) | queued | T13.S1 queued; T13.S2 queued | Not implemented; no verification or acceptance claimed. |
| T14 | [06](phases/06-project-rules.md) | queued | T14.S1 queued; T14.S2 queued | Not implemented; no verification or acceptance claimed. |
| T15 | [06](phases/06-project-rules.md) | queued | T15.S1 queued; T15.S2 queued | Not implemented; no verification or acceptance claimed. |
| T16 | [06](phases/06-project-rules.md) | queued | T16.S1 queued; T16.S2 queued; T16.S3 queued | Not implemented; no verification or acceptance claimed. |
| T17 | [07](phases/07-hardening-and-closure.md) | queued | T17.S1 queued; T17.S2 queued; T17.S3 queued | Not implemented; no verification or acceptance claimed. |
| T18 | [07](phases/07-hardening-and-closure.md) | queued | T18.S1 queued; T18.S2 queued | Not implemented; no verification or acceptance claimed. |
| T19 | [07](phases/07-hardening-and-closure.md) | queued | T19.S1 queued; T19.S2 queued; T19.S3 queued | Not implemented; no verification or acceptance claimed. |

## Blockers

A blocker records a condition, not permission to bypass the contract. Unverified future environment access is kept explicit without claiming that access has been tested or refused.

| ID | State | Affected work | Resolver and resolution condition | Evidence |
| --- | --- | --- | --- | --- |
| B01 | resolved | Writing T00 documentation | Mode changed to Default; file editing is now enabled. | Developer mode instruction for this implementation turn, 2026-11-06. The old Plan-mode restriction is historical. |
| B02 | resolved | Applying T00 package on the required local branch/worktree | User explicitly authorized local branch creation and applying the documentation; the session created codex/cpp-core-roadmap from clean main/be3710a. | User reply: "Yes, create the branch and apply the docs", 2026-11-06. Commit/merge/push authorization was excluded. |
| B03 | unverified | T03.S2 execution evidence and final T19.S1 portability exit | Discover available Windows/MSVC and Linux/GCC execution routes, then run final clean builds/tests on all required OSes. | No Windows/Linux execution route was checked by this documentation task. Configurations alone will not close it. Independent local work can proceed. |

## Owes ledger

Rows below are defined obligations. `planned` means the origin has not delivered work yet; it is not already incurred implementation debt. Record each recipient's closure separately in the evidence cell. A ticket needs only its own required receipt closed before acceptance, not a later recipient's receipt. The group closes when all required recipient receipts close. Add a distinct corrective owe when a new finding cannot be represented accurately by the planned obligation.

| ID | Origin | Recipients | State | Required closure evidence / recipient receipts |
| --- | --- | --- | --- | --- |
| OWE-T00 | T00 | T01 | open | T01.S1/S2/S3 reviewed coverage, executable corpus, and characterized cases. No characterization is claimed by drafting this package. |
| OWE-T01 | T01 | T05, T06, T07, T08, T09, T10, T12 | planned | Each T05–T09 recipient records applicable passing fixtures; T10 records complete semantic corpus results; T12 records complete native parity. |
| OWE-T02 | T02 | T17 | planned | T17.S3 comparable measurements against fixed baseline identity/procedure, assessed against the regression gate. |
| OWE-T03 | T03 | T19 | planned | T19.S1 executed clean three-OS builds/tests and final runtime-dependency inspection, including any initially unavailable OS. |
| OWE-T04 | T04 | T05, T06, T07, T08, T09, T10, T12 | planned | Each T05–T10 recipient records implemented syntax/lifetime evidence; T12 records accepted production selection. |
| OWE-T05 | T05 | T08, T09, T10 | planned | T08/T09 record their literal/inline interactions; T10.S3 records the complete corpus. |
| OWE-T06 | T06 | T11 | planned | T11.S2 native list markers/indentation/quote presentation and relevant UI evidence. |
| OWE-T07 | T07 | T10, T11 | planned | T10.S3 formatted-cell semantic coverage; T11.S2 native table/image presentation/access evidence. |
| OWE-T08 | T08 | T09, T10 | planned | Each recipient records combined literal/escape/normalization cases using final checked-in data; no recipient waits for the other's acceptance. |
| OWE-T09 | T09 | T11, T12 | planned | T11 attributed-run traits/ranges; T12 native parity on the combined-style corpus. |
| OWE-T10 | T10 | T11, T12 | planned | T11 native destination/link/alt mapping; T12 complete parity results. |
| OWE-T11 | T11 | T12 | planned | T12 comparison and signed candidate evidence covering delivered mappings, lifetimes, and known differences. |
| OWE-T12 | T12 | T17, T18 | planned | T17 fixed-baseline performance evidence; T18 removal inventory verification. |
| OWE-T13 | T13 | T16 | planned | Native enumeration and complete/partial/failure cases satisfy metadata/tree fixtures. |
| OWE-T14 | T14 | T16 | planned | Native search/favorites/outline checks satisfy matching/order/filter/index fixtures. |
| OWE-T15 | T15 | T16 | planned | Native persistence integration preserves availability, latest-store edits, and authorized alias cases. |
| OWE-T16 | T16 | T17, T19 | planned | T17 resource/performance results on fixed large projects; T19 final signed native acceptance. |
| OWE-T17 | T17 | T19 | planned | Required corrective findings resolved before T18 acceptance; final T19 execution/audit verifies fixes, sanitizer/resource/performance evidence. |
| OWE-T18 | T18 | T19 | planned | Final clean builds/dependency inspection and audit verify final source inventory, removal, interface docs, and commands. |

T19 has no outgoing owe. Required incoming receipts must be closed before final acceptance. Optional future app work is reported separately and cannot be counted as delivered core scope.

## Verification and acceptance evidence

Record candidate revision plus dirty-state/diff identity for uncommitted candidates. For future builds, include OS/compiler/architecture/configuration, commands, outcomes, skips/failures, and limits. Summaries must survive deletion of temporary logs. Evidence validity must be reconsidered after relevant changes.

| ID | Applies to | Candidate / checks | Result and limitations | User acceptance |
| --- | --- | --- | --- | --- |
| E00 | T00.S1–T00.S3 | Documentation package against be3710a; static inventory, dependency/owe, link, and whitespace checks. | PASS: 8 phase files, 20 tickets/51 slices, required ticket fields, 19 owed-work definitions, complete slice-state inventory, 216 local links/anchors, manually matched acyclic technical prerequisites, and whitespace. git apply --check --whitespace=error-all accepted the patch against the clean baseline; final worktree content/links and git diff --check were verified after application. Supervisor reviewed all phase drafts and corrected multi-recipient owed-work closure to avoid reverse dependencies. No application build/test/runtime validation. | User accepted delivery ("great") and requested a CodeRabbit PR on 2026-11-06. |
| E01 | External documentation review | User-requested CodeRabbit review of the roadmap PR. | Publication in progress; no CodeRabbit findings or approval claimed. | Final review outcome pending. |

## Git authorization and integration

This is independent of technical completion and user acceptance. Record the actual user instruction and operation scope when permission arrives; do not reinterpret a planning approval as commit/push permission.

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Read-only inspection | Allowed by policy | Clean main/be3710a inspected before drafting. |
| Documentation file edits | User requested this package and explicitly authorized applying it | Applied to the authorized local branch; user accepted delivery. |
| Create local codex branch/worktree | User explicitly approved codex/cpp-core-roadmap and applying docs, 2026-11-06 | Created from clean main/be3710a; B02 resolved. |
| Commit | Authorized as necessary to publish the user-requested PR, 2026-11-06 | Publication in progress. |
| Merge to main | Not authorized | Not performed. |
| Push | Task-branch push authorized by the explicit PR request, 2026-11-06 | Publication in progress; main push is not authorized. |
| Delete branch/worktree | Not authorized | Not performed. |
| Open PR | User explicitly requested a PR for CodeRabbit review, 2026-11-06 | Publication in progress. |

## Contract amendments

None. The agreed contract is recorded in CONTRACT.md. A later amendment must cite the explicit user decision, affected requirement/fixture/ticket IDs, and necessary revalidation. Differences from current behavior remain blocked unless the user approves that scope change.
