# Core rewrite status

Updated: 2026-11-06. This is the authoritative live ledger. [README](README.md) defines status/acceptance conventions; [CONTRACT](CONTRACT.md) owns scope and interface decisions. Phase files define work rather than duplicating state.

## Current checkpoint

- Active ticket/slice: T01.S1 accepted and `done`; T01.S2 is next and remains queued. No C++ core, build integration, new fixtures, or app behavior implementation has started.
- Scope authorized: user selected T01.S1 on 2026-11-06. Its output is a requirement-to-test inventory, not the executable corpus in T01.S2 or characterization in T01.S3.
- Branch/base: `codex/t01-s1-coverage-map` from clean `main` at `7e16955ac750efed706566a5b12b0045b66280df`. Branch creation was explicitly authorized. User clarified on 2026-11-06 that PASS also authorizes commit, merge, main push and merged-branch cleanup unless a PR is specifically requested. Integration is authorized; no PR was requested.
- Integration candidate: new [T01-S1-COVERAGE.md](T01-S1-COVERAGE.md), discovery link in [phase 01](phases/01-behavior-and-baselines.md), this ledger, and the user-requested PASS authorization clarification in AGENTS and roadmap workflow documentation. E04 identifies the accepted candidate; E05 records acceptance bookkeeping and the current map hash. The ledger has no self-referential hash.
- Output: 41 requirements (19 shared document, eight native document, ten shared project, four native project/access), existing assertion strength/limits, and 15 gaps assigned to fixture/characterization or implementation/native acceptance owners. All 104 current unit-test functions and seven focused UI-test functions are referenced; these are inventory counts, not fresh passing test results.
- Verification: source/assertion inspection, supervisor review (including bounded explorer findings for project/access), map test-name/link/ID audit, and whitespace/diff scope checks. Exact reproducible map audit is embedded in the map; E04 records results. No application build, runtime checks, portability execution or performance measurements were run for this documentation slice.
- Acceptance: user **PASS** ("pass") on 2026-11-06 for the T01.S1 map/diff identified in E04. E05 records this acceptance; T01.S2/S3 and the whole T01 ticket remain unfinished. App source/settings/version/changelog remain unchanged.
- Blockers/owes: B04 limits approval of affected code-span expectations until T01.S3 characterization; it does not block this inventory or unaffected fixtures. B03 portability route remains unverified. OWE-T00 remains open until all T01 map/corpus/characterization evidence is reviewed; OWE-T01 remains planned. No new owe is incurred by this slice.
- Exact next action: finish the authorized commit/merge/main-push/branch-cleanup workflow, then begin T01.S2 only when requested/authorized: assign stable fixture IDs and independent expected results from the current production path, preserving G01/B04 cases for T01.S3 resolution. T02.S1 can consume the verified inventory under its own authorization without waiting for all T01. Acceptance and Git execution remain separately recorded; PASS supplies the integration authorization.

## Ticket and slice state

All tickets started queued. T00 now has user acceptance for documentation delivery and checks; the requested external review is tracked separately. Within the slice column, a range such as S1–S3 names each of those stable slice IDs.

| Ticket | Phase definition | Ticket state | Slice state | Verification / acceptance |
| --- | --- | --- | --- | --- |
| T00 | [00](phases/00-roadmap.md) | done | T00.S1 done; T00.S2 done; T00.S3 done | Documentation accepted, review fixes passed (E02), and PR #3 merged (E03). |
| T01 | [01](phases/01-behavior-and-baselines.md) | in_progress | T01.S1 done; T01.S2 queued; T01.S3 queued | Coverage map/static verification (E04) accepted by user PASS on 2026-11-06 (E05). No executable fixtures or core implementation. |
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
| B04 | open | T01.S2 approval of D06/G01 multiline/partially matched code-span expectations; their T08.S1 consumer cases | T01.S3 implementer characterizes the current production prepare/renderInline route alongside the older whole-document helper, records exact fixture IDs/text/traits and resolves any wording conflict before those cases are approved. Any behavior change requires user agreement. | MR.codeDelimiterRuns asserts multiline/unmatched examples through the line-based helper; production proseBlocks joins soft paragraph lines before renderInline. [Map G01](T01-S1-COVERAGE.md#gap-handoff) identifies the cases; no route comparison was executed in T01.S1. Unaffected cases can proceed. |

## Owes ledger

Rows below are defined obligations. `planned` means the origin has not delivered work yet; it is not already incurred implementation debt. Record each recipient's closure separately in the evidence cell. A ticket needs only its own required receipt closed before acceptance, not a later recipient's receipt. The group closes when all required recipient receipts close. Add a distinct corrective owe when a new finding cannot be represented accurately by the planned obligation.

| ID | Origin | Recipients | State | Required closure evidence / recipient receipts |
| --- | --- | --- | --- | --- |
| OWE-T00 | T00 | T01 | open | T01.S1 reviewed coverage accepted in E04/E05. T01.S2 executable corpus and T01.S3 characterized cases remain outstanding; this obligation stays open. |
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
| E01 | External documentation review | [PR #3](https://github.com/pedjamusic/marky/pull/3), initial review at fc7f1b4; fixes at d0bdc99. | Initial review produced two actionable findings. CodeRabbit independently verified both fixes in the resolved threads. The [incremental re-review request was rate-limited](https://github.com/pedjamusic/marky/pull/3#issuecomment-6684048757); no complete re-review or overall bot approval is claimed. | Both attached findings verified; user PASS recorded in E02. |
| E02 | Documentation review repair | d0bdc99: T12.S1/S2 and T16 prerequisites, plus the repair checkpoint. | PASS: 8 phases, 20 tickets/51 slices, required fields/statuses, 19 owes, 216 local links/anchors, and an acyclic dependency graph including T03.S3 → T16.S1. Both omissions reproduced in the prior head and corrected; T17 is byte-identical. Whitespace and focused three-file diff checks passed. No runtime measurement or app test is claimed by this documentation edit. | User **PASS** ("pass.") on 2026-11-06 for d0bdc99. |
| E03 | Merge and handoff | PR #3, accepted head 2b320a3, merge 220e0dc. | GitHub merge confirmed; local main fast-forwarded to the merge. Both review threads resolved. Merged local/remote task branch deleted; final documentation checkpoint follows through the authorized main push. Static document checks passed before merge; no app build/runtime validation. | User explicitly authorized merge, pull/push, deletion, and wrap-up on 2026-11-06. |
| E04 | T01.S1 coverage map | Uncommitted docs on `codex/t01-s1-coverage-map`, base `7e16955ac750efed706566a5b12b0045b66280df`; map SHA-256 `22e9d2f5f43bac221e884af229685e321258357e7ac97dbffe3d53d3754e1a6a`; phase 01 discovery-file SHA-256 `37e73b5bd48f70970c1720d28c1fb67e722044a15202729188ba8076ef32e84c`. STATUS is the third changed file. | PASS: Python 3 audit embedded in [map static verification](T01-S1-COVERAGE.md#static-verification) checks exact test-name equality against MR 53 / MT 43 / FO 4 / UI 7 / BF 4 functions, 41 unique requirement IDs, 15 unique/referenced gap IDs and 15 map local links. `git diff --check` plus Python newline/trailing-whitespace checks including the new file passed; final inspection verified 60 local links/anchors across all three documents and the exact change scope/branch/base. `shasum -a 256` identifies the map and phase file. Source/assertions reviewed; no Xcode build/test execution, app runtime evidence or performance/portability claim. | User **PASS** ("pass") on 2026-11-06 for this candidate. T01.S1 accepted; user clarified that this PASS supplies Git integration authorization (E06). |
| E05 | T01.S1 acceptance checkpoint | User reply "pass", 2026-11-06, accepts E04's map and focused diff. Same branch/base; uncommitted acceptance bookkeeping in STATUS and one map sentence pointing to this ledger. Current map SHA-256 `b4ac4da5349120806f5dac6a905a48e43bfb48872e7d042a0cbe07d3e2ceda91`; phase discovery hash unchanged from E04. | Acceptance-only update: 41 requirements, 15 gaps and all mapped evidence unchanged. Candidate hashes verified before recording PASS; `git diff --check` and map inventory/link/ID audit passed after bookkeeping. No new runtime checks; B04 and remaining T01/OWE-T00 work stay open. | T01.S1 **done**. PASS authorizes commit, merge, main push and merged-branch cleanup per the user clarification in E06; PR publication was not requested. |
| E06 | PASS authorization clarification | User explicitly defined PASS as authorization to commit, merge, push main and clean up the merged branch unless a PR is specifically requested, 2026-11-06. | Updated AGENTS and roadmap workflow wording to preserve this instruction. T01.S1 map/fixture expectations and app behavior are unchanged. Static map audit, local-link/anchor and whitespace checks apply to the expanded documentation-only diff. | Existing T01.S1 PASS stands; Git integration authorized. |

## Git authorization and integration

This is independent of technical completion and user acceptance. Record the actual user instruction and operation scope; user PASS supplies integration authorization under the clarified repository policy. The first table records historical T00 operations only.

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Read-only inspection | Allowed by policy | Clean main/be3710a inspected before drafting. |
| Documentation file edits | User requested this package and explicitly authorized applying it | Applied to the authorized local branch; user accepted delivery. |
| Create local codex branch/worktree | User explicitly approved codex/cpp-core-roadmap and applying docs, 2026-11-06 | Created from clean main/be3710a; B02 resolved. |
| Commit | Authorized for PR publication, repairs, and final wrap-up, 2026-11-06 | Accepted PR commits listed above; this final checkpoint records integration and next work. |
| Merge to main | User explicitly authorized merge and wrap-up, 2026-11-06 | PR #3 merged as 220e0dc with expected-head verification. |
| Pull/push | User explicitly authorized synchronization and wrap-up, 2026-11-06 | Merged main pulled with --ff-only; final documentation checkpoint uses the authorized main push. |
| Delete branch/worktree | User explicitly authorized merged-branch cleanup, 2026-11-06 | codex/cpp-core-roadmap deleted locally and on origin after merge. Temporary local handoff branch is disposable after its checkpoint reaches main. No extra worktree was created. |
| Open PR | User explicitly requested a PR for CodeRabbit review, 2026-11-06 | [PR #3](https://github.com/pedjamusic/marky/pull/3) merged; review limits recorded in E01. |

### T01.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Coverage-map and handoff edits | User selected next implementation slice T01.S1, 2026-11-06 | Documentation-only map, phase discovery link and STATUS update; user PASS recorded in E05. |
| Create local branch | User reply: "Yes, create the branch" to `codex/t01-s1-coverage-map` from clean main, branch creation only | `git switch -c codex/t01-s1-coverage-map` succeeded at base `7e16955`; no worktree was needed for read-only exploration. |
| Commit / merge / main push / delete merged branch | User clarification, 2026-11-06: "pass means authorization, unless i specifically ask for PR. so commit merge etc. that is what PASS means" | Authorized workflow in progress; execution checkpoint follows. |
| Open PR | Requires a specific user request | Not requested or executed for T01.S1. |

## Contract amendments

None. The agreed contract is recorded in CONTRACT.md. A later amendment must cite the explicit user decision, affected requirement/fixture/ticket IDs, and necessary revalidation. Differences from current behavior remain blocked unless the user approves that scope change.
