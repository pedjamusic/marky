# Core rewrite status

Updated: 2026-11-13. This is the authoritative live ledger. [README](README.md) defines status and acceptance conventions. [CONTRACT](CONTRACT.md) owns scope and interface decisions. Phase files define work rather than duplicating state.

## Current checkpoint

- **T06 accepted and delivered.** User **PASS** ("pass"), 2026-11-08, accepts E54 (E55). T06.S2 landed on `main` as `bd91ede` (E56). The portable parser and Swift proof adapter preserve source-ordered quote lines, marker depth, empty lines, and boundaries with adjacent blocks. T06.S1 was accepted and integrated in E52–E53.
- **T07 is accepted and delivered.** User **PASS** ("pass"), 2026-11-13, accepts the T07.S2 candidate E60 (E61). Standalone image metadata landed on `main` as `2e71ef4` (E62). Portable table parsing landed as `df7cb77` (E59).
- **T08.S2 is accepted and delivered.** User **PASS** ("pass"), 2026-11-13, accepts the portable lexer candidate E66 (E67). The slice landed on `main` as `3dae9f8` (E68). [Phase definition](phases/04-inline-semantics.md#t08--literal-spans-escapes-and-normalization)
- **T08.S3 and T08 are accepted and delivered.** User **PASS** ("pass"), 2026-11-13, accepts the offline data candidate E69 (E70). The slice landed on `main` as `adfac85` (E71).
- **T09.S1 is accepted and delivered.** User **PASS** ("pass"), 2026-11-13, accepts the portable delimiter candidate E72 (E73). The slice landed on `main` as `a7523b5` (E74). T09.S2 follows with the combined-style candidate below. [Phase definition](phases/04-inline-semantics.md#t09--emphasis-and-combined-traits)
- **T09.S2 and T09 are accepted.** User **PASS** ("pass"), 2026-11-13, accepts the combined-style candidate E75 (E76). [Verification](#t09s2-mac-run)
- Windows/MSVC and Linux/GCC execution remains open under B03/OWE-T03. T07 closes its OWE-T01 and OWE-T04 receipts. T10 and T11 retain their OWE-T07 work.

## Ticket and slice state

All tickets started queued. T00 now has user acceptance for documentation delivery and checks; the requested external review is tracked separately. Within the slice column, a range such as S1–S3 names each of those stable slice IDs.

| Ticket | Phase definition | Ticket state | Slice state | Verification / acceptance |
| --- | --- | --- | --- | --- |
| T00 | [00](phases/00-roadmap.md) | done | T00.S1 done; T00.S2 done; T00.S3 done | Documentation accepted, review fixes passed (E02), and PR #3 merged (E03). |
| T01 | [01](phases/01-behavior-and-baselines.md) | done | T01.S1 done; T01.S2 done; T01.S3 done | S1/S2 accepted and integrated (E04–E10). S3: 92 total fixtures, route comparison, full unit suite and four negative controls passed (E11); user PASS in E12 and integration in E13. No core implementation. |
| T02 | [01](phases/01-behavior-and-baselines.md) | done | T02.S1 done; T02.S2 done | S1 accepted/integrated (E14–E16). E17 original probe/folder evidence and retained failures; E18 supplies six successful dense full-project native visual samples. [S2 report](T02-S2-PERFORMANCE.md); B05 measurement resolved, B06 accessibility remains open. User PASS in E19; integration in E20. |
| T03 | [02](phases/02-core-and-swift-seam.md) | done | T03.S1 done; T03.S2 done; T03.S3 done | S1 accepted/integrated (E21–E23). S2 accepted and integrated via PR #4 (E24–E27). S3 verified, accepted and integrated (E28–E30); [report](T03-S3-XCODE-INTEGRATION.md). Windows/Linux execution remains with B03/OWE-T03. |
| T04 | [02](phases/02-core-and-swift-seam.md) | done | T04.S1 done; T04.S2 done; T04.S3 done | T04.S1 and S2 accepted and integrated (E31–E36). T04.S3 verified, accepted and integrated (E37–E39); [spec and evidence](T04-S3-SWIFT-PARAGRAPH.md). |
| T05 | [03](phases/03-document-blocks.md) | done | T05.S1 done; T05.S2 done; T05.S3 done | E42 and E46 record S1/S2 integration. E47 and E48 record S3 verification and application. User PASS recorded in E49 and integration in E50. |
| T06 | [03](phases/03-document-blocks.md) | done | T06.S1 done; T06.S2 done | E51–E53 record the list slice. E54 verifies quote structure, source, depth, boundaries, and lifetime. E55 records user PASS and E56 records integration. |
| T07 | [03](phases/03-document-blocks.md) | done | T07.S1 done; T07.S2 done | E57–E59 record the table slice. E60–E62 record image verification, user PASS, and integration. |
| T08 | [04](phases/04-inline-semantics.md) | done | T08.S1 done; T08.S2 done; T08.S3 done | E63–E68 cover the accepted literal span and lexer slices. E69 verifies the final offline entity tables and Unicode label keys. E70 records user PASS and E71 records integration. |
| T09 | [04](phases/04-inline-semantics.md) | done | T09.S1 done; T09.S2 done. | E72–E74 record T09.S1 verification, PASS, and integration. E75 verifies T09.S2 and E76 records user PASS. |
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
| B03 | open | T03.S2 missing Windows/MSVC and Linux/GCC executions; final T19.S1 portability exit | Environment owner prepares a runnable Windows/MSVC x64/v143 host and Linux/GCC host (or identified Linux container), then executes both Debug/Release smoke, intentional failure and recovery procedures. T19 also requires final clean three-OS builds/tests and dependency inspection. | E24 / [S2 report](T03-S2-PLATFORM-BUILDS.md#missing-execution-and-ownership): Mac g++ is Apple Clang; Docker daemon socket is absent; no ready Windows guest/executor was established. Neither non-Mac family was run. Presets/procedures do not close this; independent local work can proceed. |
| B04 | resolved | Approval of D06/G01 multiline/partially matched code-span expectations; their T08.S1 consumer cases | User PASS in E12 accepts MD-041–044 and the T08.S1 clarification; no app behavior change was made. | E11: production/helper/direct-inline comparison passes; [characterization](T01-S3-CHARACTERIZATION.md#entry-points-and-route-differences) records exact results. Soft paragraph lines join into code in MD-041; unmatched outer runs leave matched inner code in MD-042; blank lines split paragraphs in MD-044. Affected expectations are now approved. |
| B05 | resolved | T02.S2 dense full-app measurement | E18 supplies an external native CGEvent/window-capture endpoint on the unchanged full fixture, app, geometry and settings, with one warm-up/five measured fresh apps and matching kernel peaks. | Final median 14,801.92 ms; peak 2.071 GiB. Original failures remain in E17 and the report. This resolves the missing visual baseline; B06 retains accessibility/native acceptance and OWE-T02 retains the future regression gate. |
| B06 | open | T12.S1/S2 large-document accessibility/native acceptance | Mac frontend owner: isolate the retained SwiftUI accessibility focus traversal and establish working dense-document accessibility/navigation validation on the same fixture. Review any required native fix explicitly and revalidate affected baseline/replacement measurements consistently. | E17 and E18: XCTest AX timeouts and focus traversal; follow-up without XCTest injection also timed out in native CUA AX inspection. External CGEvent/capture succeeds, but that is visual measurement, not accessibility acceptance. No VoiceOver, full navigation or production fix claimed. |
| B07 | resolved | T05.S3 and T05 acceptance | User PASS in E49 accepts the applied E48 candidate for both delimiter cases. | The C regressions failed on the base. With the fix, `# \u{0301}body` retains its original paragraph bytes and `- \u{0301}- -` produces a thematic break. Swift character checks confirmed the expected outcomes. The portable handling covers attached accents in U+0300–U+036F at these delimiters. |

## Owes ledger

Rows below are defined obligations. `planned` means the origin has not delivered work yet; it is not already incurred implementation debt. Record each recipient's closure separately in the evidence cell. A ticket needs only its own required receipt closed before acceptance, not a later recipient's receipt. The group closes when all required recipient receipts close. Add a distinct corrective owe when a new finding cannot be represented accurately by the planned obligation.

| ID | Origin | Recipients | State | Required closure evidence / recipient receipts |
| --- | --- | --- | --- | --- |
| OWE-T00 | T00 | T01 | closed | T01.S1 reviewed coverage accepted in E04/E05. T01.S2 executable corpus verified in E08 and accepted in E09; T01.S3 characterization and 92-fixture corpus verified in E11 and accepted in E12; T01 receipt closed. |
| OWE-T01 | T01 | T05, T06, T07, T08, T09, T10, T12 | open | E11/E12 deliver 92 accepted fixtures and the [gap/consumer index](T01-S3-CHARACTERIZATION.md#gap-and-consumer-index). T05 receipt closed with the applicable base-block and literal fixture comparisons (E40, E43, E47–E49), including malformed and inert HTML source and code-span boundaries. T06 receipt closed with accepted list and quote fixture projections (E51–E52, E54–E55). T07 receipt closed with accepted table and image fixture comparisons (E57–E58, E60–E61). T08 receipt closed with the applicable code span, escape, entity, and label fixture checks (E63, E66, E69–E70). T09 receipt closed with the combined-style and literal fixture checks in E75. T10 and T12 receipts remain open. Each T05–T09 recipient records applicable passing fixtures; T10 records complete semantic corpus results; T12 records complete native parity. |
| OWE-T02 | T02 | T17 | open | E17/E18 supply fixed baseline identities/procedures/results in the [report](T02-S2-PERFORMANCE.md), [original raw record](measurements/t02-s2-v1.json) and [native record](measurements/t02-s2-native-v1.json). Baseline accepted by user PASS in E19. T17 receipt requires comparable replacement measurements for all original metrics plus the external dense visual endpoint, matching build/hardware/geometry/thermal/observation conditions, and the unchanged 20% gate. B06 remains a separate T12 native acceptance blocker. |
| OWE-T03 | T03 | T19 | open | E21 supplies S1 scaffold evidence; E24 supplies S2 presets/procedures and local Mac checks. Linux/GCC and Windows/MSVC x64/v143 Debug/Release clean configure/build/smoke, intentional nonzero failure and ordinary recovery are **not executed**; exact environments/commands/imports remain owed via B03. T19.S1 receipt also requires final clean-candidate macOS/Apple Clang, Windows/MSVC and Linux/GCC builds/tests and runtime-dependency inspection. |
| OWE-T04 | T04 | T05, T06, T07, T08, T09, T10, T12 | open | E37 supplies the Swift value adapter and test-only native paragraph proof. T05 receipt closed with typed base blocks, Swift adapter comparison, and partial-build cleanup through the C API (E40, E43, E47–E49). T06 receipt closed with list and quote ownership, adapter, and interruption checks (E51–E52, E54–E55). T07 receipt closed with the equivalent table and image checks (E57–E58, E60–E61). T08 receipt closed with the core-only lexical and prepared-source checks (E63, E66, E69–E70). T09 receipt closed with E75's owned inline tokens and prepared-source checks. T10 records document-level syntax and lifetime evidence. T12 records accepted production selection. |
| OWE-T05 | T05 | T08, T09, T10 | open | T08 receipt closed with the literal, escape, and entity interactions (E63, E66, E69–E70). T09 receipt closed with E75's protected code, escapes, and nested styles. T10.S3 records the complete corpus. |
| OWE-T06 | T06 | T11 | open | E52 and E55 accept semantic list and quote coverage. T11.S2 closes with native list markers, indentation, quote presentation, and relevant UI evidence. |
| OWE-T07 | T07 | T10, T11 | open | E57–E58 supply the accepted table structure. E60–E61 supply the accepted image metadata. T10.S3 owes formatted-cell semantics. T11.S2 owes native table and image presentation and image access checks. |
| OWE-T08 | T08 | T09, T10 | open | E69 supplies the accepted final data, provenance, and literal and escape fixture evidence (E70). T09 receipt closed with the passing combined-style fixtures using final checked-in data (E75). T10 retains its combined fixture obligation. |
| OWE-T09 | T09 | T11, T12 | open | E75 supplies the combined-style corpus. T11.S1 checks attributed-run traits and UTF-8 to native text projection, including combining marks at a consumed delimiter boundary. T12 checks production parity on the corpus. |
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
| E07 | T01.S1 integration | Accepted coverage and PASS policy clarification committed as `8cfe810`; `git merge --ff-only codex/t01-s1-coverage-map` on main and `git push origin main` succeeded on 2026-11-06. | Six-document diff passed source/test inventory, local-link/anchor, whitespace and scope checks. Remote main was verified at the base before integration. This documentation-only closeout records the successful delivery and is carried through the same main-push/merged-branch-cleanup authorization. No runtime claims or core implementation. | T01.S1 accepted and delivered; next implementation slice T01.S2. |
| E08 | T01.S2 corpus candidate | Uncommitted on `codex/t01-s2-fixture-corpus`, base `6954ff458b18f8d46714b3cddaa9edab29087f5c`; JSON SHA-256 `1898b3a7fce27b1be2f4c3f54f350bca38f36fece4140f1df0df5fa9078ccaec`; test SHA-256 `236222482355e3415d8f2a00f0661268464c2c3a5ef8766add53ed9040d6027d`; corpus contract SHA-256 `2ef82a40b194f48d9bee07035fcbc7bc2080ba7e4102bdee2b2faae7b3574e81`. Phase 01 discovery and this ledger complete the five-file candidate; no self-referential ledger hash. | **PASS, automated:** `xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' -derivedDataPath /tmp/MarkyT01S2 test -only-testing:MarkyTests` on macOS 27.0.1/26A434 arm64, Xcode 27.2/27B52. Final Debug result: 106 functions / 109 executions, zero failures/skips, including both new checks and all 40 unchanged fixtures. Final bundle `/tmp/MarkyT01S2/Logs/Test/Test-Marky-2026.11.06_13-20-42-+0100.xcresult`; first passing run ended `13-17-55-+0100.xcresult`. Negative-control run used the same command with `-only-testing:MarkyTests/MarkdownCompatibilityTests`: MD-003 first run text, MD-008 code text, MD-027 first run traits, MD-030 first destination deliberately replaced with incorrect expectations. Exit 65 and detailed test diagnostics named all four IDs (six assertions failed including two native-text comparisons), then original JSON bytes restored and the full suite passed. Negative bundle ended `13-19-47-+0100.xcresult`. Initial restricted build failed in the existing Swift macro process; required Xcode access resolved it. Python 3 audit confirmed 40 ordered unique IDs, D01–D18 references, existing provenance function names and new-file newline/whitespace. Supervisor reviewed source, expectations, projection and explorer findings; local discovery links, focused scope and `git diff --check` passed. No UI/Release/signed-sandbox, performance, Windows/Linux or replacement-core claim. | User **PASS** ("pass") on 2026-11-06; E09 records acceptance. B04/G01 and remaining G02–G09 characterization retain T01.S3 ownership; T01 and OWE-T00 remain unfinished. |
| E09 | T01.S2 acceptance | User reply "pass", 2026-11-06, accepts E08's 40-fixture corpus, checks and focused diff. JSON/test/contract SHA-256 values reverified identical to E08. | Acceptance-only STATUS bookkeeping; fixture data, test code, corpus contract and production sources unchanged. Existing full unit/negative-control evidence remains valid; static whitespace/discovery/scope checks repeated. No new runtime claim. | T01.S2 **done**. PASS authorizes committing the focused changes, merging into local main, pushing main and deleting the merged task branch; execution recorded separately. No PR requested. |
| E10 | T01.S2 integration | Accepted five-file slice committed as `ee778b7b79b35744f612e0172d87de6c92002db9` on 2026-11-06. | `git merge --ff-only codex/t01-s2-fixture-corpus` on main and `git push origin main` succeeded. Remote main was checked at the clean base before integration. Accepted JSON/test/contract hashes matched E08; corpus IDs, requirement/provenance references, local discovery links, focused scope and `git diff --check` passed. No fixture, test or production-code change after the full unit/negative-control evidence. This final STATUS-only checkpoint records delivery and is carried through the same authorized main push and merged-branch cleanup. | T01.S2 accepted and delivered; T01.S3 next, T01/OWE-T00 unfinished. |
| E11 | T01.S3 characterization candidate | Uncommitted seven-file candidate on `codex/t01-s3-characterization`, base `ff949b62121dced0604e277a098eba751938a98a`. JSON SHA-256 `c66388eb8fb862dab8bf83c8f6c4d738dc978b6cf8ba09f5afbce21dd96eadb4`; test `e0594ff1e4c5fca820151466d32053ab1a8b253d26a3af3301ee4e77026d0af9`; characterization `22dd79faa10667388d3b889948643fc24cd3e4e20114f464b445ad5e9ebdc749`; S2 notes `3522e41126908c22afaa586a047c027402b9c2d2fa8716c600779516d5149a0c`; phase 01 `7336d6dc28e664403b510d988d6b991f05e98601d79dfb291b91935de6318dc9`; phase 04 `825cb4d23bf7e863e94a4969bc24413111d3d008630d752e608811551a126af7`. This ledger is the seventh file (no self-referential hash). | **PASS, automated:** macOS 27.0.1/26A434 arm64, Xcode 27.2/27B52, Debug. `xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS' -derivedDataPath /tmp/MarkyT01S3 -resultBundlePath /tmp/MarkyS3Final.xcresult test -only-testing:MarkyTests`: 106 functions per xcresult summary, zero failures/skips/expected failures/runtime warnings, both corpus checks and 92 fixtures passed. Pre-control full suite also passed (`Test-Marky-2026.11.06_13-34-32-+0100.xcresult`). Negative run: same command with result bundle `/tmp/MarkyS3Negative.xcresult` and `-only-testing:MarkyTests/MarkdownCompatibilityTests`, expected failure; detailed results identify all four mutations: MD-041 helper text, MD-060 quote strong trait, MD-072 canonically equivalent but byte-distinct label, MD-078 destination. JSON restored byte-for-byte with `cmp` before final run and hash rechecked. Static audit: sequential 92 IDs, all D01–D19 represented, valid block/run shapes, original 40 fixture values unchanged, six candidate hashes, local links/anchors and whitespace passed. Initial sandboxed build could not execute Swift macros; rerun outside tool sandbox succeeded. One test-diagnostic compile error was corrected before final checks. CoreSimulator version warning did not affect Mac tests. No UI tests, Release, signed sandbox/manual flow, performance or other-OS execution; T02 retains those baseline obligations. | User **PASS** ("pass"), 2026-11-06; acceptance recorded separately in E12. No Git integration was executed at E11 verification time. |

| E12 | T01.S3 acceptance | User reply "pass", 2026-11-06, accepts E11’s seven-file candidate, 92-fixture expectations, characterized exceptions and T08.S1 wording. All six candidate hashes reverified unchanged before bookkeeping. | Acceptance-only updates to STATUS and characterization acceptance wording (new characterization SHA-256 `0e56ec75fde0e53c666f0acf8fbf7d75310797d3d0bd67237ca6e7d0066dfca4`); JSON/test/phase/S2 values unchanged. E11 full-unit and negative-control evidence remains valid. Static scope/link/whitespace checks repeated; no additional runtime claim. | T01/S3 done; B04 and OWE-T00 closed. OWE-T01 open with all seven receiving-ticket receipts outstanding. PASS authorizes focused commit, merge to main, main push and merged-branch cleanup; Git execution follows separately. No PR requested. |
| E13 | T01.S3 integration | Accepted seven-file slice committed as `cea77e930afaf2fd118c669a6be47812d8392e3e`, 2026-11-06. | `git merge --ff-only codex/t01-s3-characterization` on main and `git push origin main` succeeded. Remote main was verified at clean base `ff949b6` before integration. Merged local task branch deleted with `git branch -d`; no task branch push or PR. E11 JSON/test/phase/S2 hashes and E12 acceptance-only characterization hash verified; no executable fixture/test change after the passing unit/negative-control runs. Static scope/link/whitespace checks passed. This final STATUS-only checkpoint is carried through the same authorized main push. | T01/S3 accepted and delivered; B04/OWE-T00 closed, OWE-T01 receipts remain open. |
| E14 | T02.S1 current-Mac baseline | Source `32c6451cc2cd13ec7ed73f859de66d2eae337782`, initially clean; uncommitted documentation-only candidate on `codex/t02-s1-mac-baseline`. [Baseline report](T02-S1-MAC-BASELINE.md) SHA-256 `08fe4097b279505fc2fc31b6f63ef88914047ece66052d4aa208e94630f19e1c`; phase 01 discovery and STATUS complete the three-file diff. Report records exact commands, tree/corpus/binary identities, environment and bundle locations. | **PASS, automated:** macOS 27.0.1/26A434 arm64, Xcode 27.2/27B52. Debug full suite: 106 unit functions / 109 executions and 8 UI tests, 114 functions / 117 executions combined, zero failures/skips/expected failures; `/tmp/MarkyT02S1-Debug-Executed.xcresult`. Release build 0.2.4 (5) passed. Both signatures passed deep/strict verification; production Release entitlements have sandbox/user-selected read-only access and no UI-test temporary exceptions. Supervisor inspected three UI attachments. Whitespace, local-link/anchor and unchanged source/test/settings/corpus checks passed. Initial restricted builds failed at macro sandbox creation (exit 65, no tests); authorized retries passed with no code/settings edits. No fresh manual restoration, performance or other-OS claim. | User **PASS** ("pass"), 2026-11-06; acceptance in E15. T02.S2 remains queued. |
| E15 | T02.S1 acceptance | User reply "pass", 2026-11-06, accepts E14 and the focused three-file documentation candidate. Baseline report hash reverified unchanged before bookkeeping. | Acceptance-only report/STATUS wording; current report SHA-256 `d2c01798f80d854a5d9ed4b2f104ae5ae9201f005bf089ce8b45cbc1733358ce`. E14 source/test/settings/corpus and binary identities, unit/UI/build/signing results and limitations remain unchanged. Static scope, links/anchors and whitespace rechecked; no runtime rerun needed for acceptance wording. | T02.S1 **done**, T02 remains in_progress with S2 queued. PASS authorizes focused commit, merge to main, main push and merged-branch cleanup under AGENTS policy; execution recorded separately. No PR requested. |
| E16 | T02.S1 integration | Accepted three-file baseline and acceptance records committed as `4177663`, 2026-11-06. | `git merge --ff-only codex/t02-s1-mac-baseline` on main and `git push origin main` succeeded. Remote main was checked at base `32c6451` before integration. Merged local task branch deleted with `git branch -d`; no task branch push or PR. E14 report hash matched before E15 acceptance-only changes; E15 report hash, source/test/settings/corpus identities, 56 local links/anchors, focused scope and whitespace checks passed. No executable changes since the passing baseline. This final STATUS-only checkpoint uses the same authorized main push. | T02.S1 accepted and delivered. T02.S2 next, still queued; T02 and its measurement obligation remain unfinished. |
| E17 | T02.S2 partial fixed-input baseline; blocked exit | Uncommitted `codex/t02-s2-performance-baseline`, base `f910e20f6a0eb0a296843aa7cfd327d0230075f9`; eight-file candidate, production source/settings/corpus unchanged. [Report](T02-S2-PERFORMANCE.md) SHA-256 `56f0fa83204cbd9b3eae3134876b998f37f4d89431503c9ecef4b06bc61bfeb8`; [raw JSON](measurements/t02-s2-v1.json) SHA-256 `4a3ec80fdc8ece1446b9bd6c516ffbfc7f011beb99895d49e12ba2311890e9a5`; JSON records tooling/executable hashes, hardware/configuration, all samples and summaries. | 48 probe processes passed (8 warm-ups/40 measured); six fresh large-folder app iterations passed with matching kernel peak records. Fixed 704,577-byte document / 5,002-file visible project identities and generation/verification, time medians/ranges, process peaks and cancellation outcomes retained. Independent generation/byte/directory negative controls passed. 106 Debug unit functions / 109 executions passed; all 8 existing Release UI tests passed, 2 explicit opt-in skips. Combined Release invocation failed unit-bundle library validation; Debug retry passed, without changing measured binary/security settings. Both host signatures, source scope, summary arithmetic, local links/anchors and whitespace verified. **Dense full-app probe failed** after 30.77 s, screen Loading, peak 1.246 GiB; earlier AX/visual failures retained, original full-project native/automation cause unresolved; separate untimed non-test single-file opening visibly rendered first content, under different conditions. B05 blocks successful dense median and **current S2 exit**; no standalone sandbox-restoration or other-OS claim. | Pending. Artifact review is not completion of S2 or a waiver of B05/the 20% gate. No user PASS or Git integration. |
| E18 | T02.S2 B05 measurement follow-up | Same branch/base/app as E17; ten-file uncommitted candidate. Report SHA-256 `bb89543b4db2a65f4758c8cf3eb10b12530aacd0bc076f783a4976d1ba81f69f`; native record `b349233be63cb64c6912a00c2fc1a06c6ebed5d62b99a23ece8fb6d22242c25c`; record identifies final tooling/executable hashes, fixtures, conditions, all final samples and exploratory series. User explicitly approved standalone CGEvent input/window screenshots. | Original XCTest repro failed again at 74,160.16 ms; 974/974 main-thread samples under accessibility focus-update traversal. No-injection native CUA inspection also timed out, with 540 main-thread samples under focus-update actions. External native endpoint then passed two six-app series; final pooled-OCR series selected, median 14,801.92 ms, measured range 11,929.95–14,861.29 ms, app peak 2,223,901,360 bytes. All final samples fair thermal (`1`), 1252 × 833; six PIDs joined to kernel reads, all endpoint captures inspected. Earlier series/noisy CPU load retained; near-gate comparisons require repetition. Driver peak 78.13 MiB excluded from app peaks. Optimized strict Swift compilation, signature, fixture/identity checks, four summarizer negative controls, unchanged original folder output, arithmetic/link/whitespace audits passed. App/tests/settings unchanged; no suite rerun or restoration/accessibility claim. | Automated baseline evidence supplied; B05 resolved for measurement, B06 remains open for T12 accessibility/native acceptance. T02.S2 awaiting user review/PASS; no commit/merge/push. |
| E19 | T02.S2 acceptance | User reply **PASS** ("pass"), 2026-11-06, accepts E18's final native endpoint, baseline evidence, tooling and focused diff. Report/native-record hashes verified identical to E18 before acceptance bookkeeping. | Acceptance-only report/STATUS updates; raw records, production/test/settings sources, tooling and measured app unchanged. Existing automated results retain their limits. Static identity, summary, link, whitespace and scope checks repeated; no new runtime claim. | T02.S2 and T02 **done**. PASS authorizes committing the focused candidate, merging into local main, pushing main and deleting the merged task branch. B06 and OWE-T02 remain open; no PR requested. |
| E20 | T02.S2 integration | Accepted ten-file baseline committed as `31ebae6bb8733c46cb23ebcbd263625f882a38b2`, 2026-11-06. | `git merge --ff-only codex/t02-s2-performance-baseline` on main and `git push origin main` succeeded. Remote main was checked at clean base `f910e20` before integration and verified at `31ebae6` after push. Merged local task branch deleted. Accepted tooling/raw identities, summary arithmetic, local links, whitespace and focused source scope passed; no new runtime checks or production change. This STATUS-only final checkpoint records execution and is carried through the same authorized main push. | T02/T02.S2 accepted and delivered. Next roadmap selection T03.S1; not started. B06 and OWE-T02 remain open for their native acceptance/comparison consumers; B03 unchanged. |
| E21 | T03.S1 standalone build | Uncommitted `codex/t03-s1-core-build`, base `d3780ba1fff0163eb8c0a47ceb0d594be565c255`; nine-file candidate. [Report](T03-S1-CORE-BUILD.md) records exact executable/build-input SHA-256 identities, commands and environment. | PASS: fresh Debug/Release configure/builds; 1/1 CTest each; intentional executable exit 1 / CTest exit 8 each; ordinary recovery passes. Release has NDEBUG and active checks. Core-only archive build, archive/symbol/link inspection, manifest/dependency review, local links, whitespace and focused scope passed. No compiler warnings. Mac arm64 only; no parser, Swift integration, app runtime, performance or Windows/Linux claim. | Pending user review/PASS; T03.S1 awaiting_acceptance. No commit/merge/push/PR. |
| E22 | T03.S1 acceptance | User **PASS** ("pass"), 2026-11-06, accepts E21's nine-file candidate and evidence. Core source/build/harness/README SHA-256 identities and retained Debug/Release pass/fail logs verified unchanged before bookkeeping. | Acceptance-only report/STATUS updates; E21 checks retain their original scope and limits. Local links, whitespace and exact file scope rechecked. No new runtime execution. | T03.S1 **done**; T03 remains in progress. PASS authorizes focused commit, merge to local main, main push and merged task-branch cleanup. No PR requested. |
| E23 | T03.S1 integration | Accepted nine-file candidate committed as `ef0248ef28d513936596db9afdb355aa531b9849`, 2026-11-06. | Local main fast-forward merge and `git push origin main` succeeded; origin/main verified at `ef0248e` after push (clean base `d3780ba` before integration). Merged local task branch deleted; no task branch was pushed. Core identities, exact file scope, links, whitespace and retained E21 evidence passed. This STATUS-only final closeout uses the same authorized main push; no runtime rerun or production app change. | T03.S1 accepted/done and delivered. T03 remains in progress; next sibling selection T03.S2, not started. B03/B06 and OWE-T01/OWE-T02/OWE-T03 remain open for their named consumers. |
| E24 | T03.S2 platform configurations/procedures | Uncommitted six-file candidate on approved `codex/t03-s2-platform-builds`, base `e92588fd5db5ed6ea60395738da1613c923f6a97`; [report](T03-S2-PLATFORM-BUILDS.md) identifies preset/source hashes, commands and environments. | Fresh repository Mac Apple Clang Debug/Release configure/build, 1/1 smoke passes, intentional executable exit 1 / CTest exit 8, ordinary 1/1 recovery; host filtering/foreign disablement and zero-test rejection passed. No compiler warnings. Archive/runtime inspection, ignored outputs, unchanged S1 inputs, full diff, 75 local links/anchors and whitespace passed. CMake/CTest 4.4.5; no Linux/GCC or Windows/MSVC execution. | Pending user review/PASS; T03.S2 awaiting_acceptance. Branch/application executed. User subsequently authorized review commits/task-branch push/PR and automatic finding fixes (E25); user acceptance and merge remain pending. No later slice started. |
| E25 | T03.S2 requested CodeRabbit review | User explicitly requested publication via `gh` and automatic fixes, 2026-11-06. Six-file candidate committed/pushed as `4e63f04bd49a7ba92531be3fae6b5ebd4ba7748a`; [PR #4](https://github.com/pedjamusic/marky/pull/4). E24 input hashes/scope reconfirmed before publication. | CodeRabbit check **SUCCESS**, completed 2026-11-06 18:38:10 UTC. Its [review summary](https://github.com/pedjamusic/marky/pull/4#issuecomment-6692457268) covers all six files through `4e63f04` and reports no actionable comments; inline finding count is zero. No corrective implementation change needed. No formal GitHub review approval is claimed. This report/STATUS closeout is bookkeeping beyond the reviewed head; E24 build inputs remain identical. | User PASS and merge pending. Review commit/task-branch push/PR publication executed; main remains unchanged. |
| E26 | T03.S2 acceptance | User **PASS** ("pass"), 2026-11-06, for PR #4 at `dad49a7824244f9c5493491b48af89a39160e739`. E24 source/preset hashes, six-file branch scope, 75 local links/anchors and whitespace reconfirmed. | T03.S2 **done**; T03 remains in progress. CodeRabbit completed review of `4e63f04` without actionable findings. The `dad49a7` bookkeeping-only follow-up check was skipped: manual review required for this OSS repository. No full review of later metadata or new runtime validation is claimed. B03/B06 and open owes remain with their consumers. | User PASS authorizes merge of the requested PR, local main synchronization, publication of integration bookkeeping and merged task-branch cleanup. Execution is recorded separately. |
| E27 | T03.S2 PR integration | Accepted review candidate `dad49a7`, acceptance checkpoint `10a63e36e3dfb2e9cdfc9cb48c82437b5941ed19`; [PR #4](https://github.com/pedjamusic/marky/pull/4) merged as `cf800a10473dc6b6f900e605041a94730496f477`, 2026-11-06. | `gh pr merge --merge --match-head-commit` succeeded with the exact acceptance checkpoint. Local main fast-forwarded to the GitHub merge; merged remote/local task branch deleted after ancestry verification. Core/preset hashes and retained E24 evidence unchanged; final scope, links and whitespace rechecked. This STATUS-only closeout uses the same authorized main push; no new runtime validation is claimed. | T03.S2 accepted/done and delivered. T03 remains in progress with S3 queued. B03/B06 and OWE-T01/OWE-T02/OWE-T03 remain with named consumers. |
| E28 | T03.S3 SwiftPM/static Xcode integration | Verified seven-file candidate prepared from clean `main/dd7c7e0` in an isolated snapshot. [S3 report](T03-S3-XCODE-INTEGRATION.md) records commands, build input hashes and signed Release app identity. | PASS on macOS arm64: Xcode Debug and Release builds, 106 unit tests, 1 focused reader UI test, Release signature and sandbox entitlement checks, static link evidence and a C++20 smoke linked against each Xcode-built object. No fetched packages. Standalone SwiftPM static archive and CMake Debug/Release 1/1 smoke, expected exit 8 and 1/1 recovery passed. | Submitted for user review and focused Release smoke. E29 records acceptance. Windows/Linux remain with B03/OWE-T03. |
| E29 | T03.S3 acceptance | User **PASS** ("pass"), 2026-11-07, for the signed Release candidate 0.2.4 (5) from E28. | Confirmed Release executable hash, exact build inputs and retained successful Xcode and CTest failure-control logs. Acceptance bookkeeping adds no runtime execution. | T03.S3 and T03 accepted/done. PASS authorizes commit, local main merge, main push and merged local branch cleanup. |
| E30 | T03.S3 integration | Accepted seven-file candidate committed as `7bab1fa667b72f3167402828e88823c72bec58f1`, 2026-11-07. | Local `main` fast-forwarded with `git merge --ff-only codex/t03-s3-xcode-integration` and pushed to `origin/main`. Remote main verified at the candidate commit before deleting the merged local task branch. This STATUS-only handoff uses the same authorized main push. | T03.S3 delivered. T04.S1 is next. Windows/Linux execution and final dependency inspection remain with B03/OWE-T03. |
| E31 | T04.S1 C document interface and result lifetime | Verified snapshot based on clean `main/6a569764fd35e3ace7e7ff373d2197b8ab158174`. [Report](T04-S1-DOCUMENT-INTERFACE.md) records commands and build input hashes. | macOS arm64 Debug/Release 1/1 CTest, intentional exit 8 and 1/1 recovery; the borrowed-input regression control also failed with exit 8. ASan/UBSan 1/1, strict C11 and Swift consumer executions, static local package and Xcode Debug build with 106 unit tests passed. | The verified patch was applied on the approved local branch and accepted in E32. Windows/Linux execution remains with B03/OWE-T03. |
| E32 | T04.S1 acceptance | User **PASS** ("pass"), 2026-11-07, for the applied candidate on `codex/t04-s1-document-interface` at base `6a56976`. | Verified that the applied core files match the E31 snapshot. The previous fresh Debug run on the branch passed 1/1 CTest. Acceptance bookkeeping adds no new runtime execution. | T04.S1 accepted/done. PASS authorizes commit, local main merge, main push and merged local branch cleanup. |
| E33 | T04.S1 integration | Accepted eleven-file candidate committed as `ef686cb3257925cdf494ab0996039038b3afc4a7`, 2026-11-07. | Local `main` fast-forwarded with `git merge --ff-only codex/t04-s1-document-interface` and pushed to `origin/main`. Verified remote main at the candidate commit before deleting the merged local task branch. This STATUS-only handoff uses the same authorized main push. | T04.S1 delivered. T04.S2 is next. Windows/MSVC and Linux/GCC execution remain with B03/OWE-T03. |
| E34 | T04.S2 failures and cancellation | Verified snapshot based on clean `main/5eb7a1b2bd6e2b6577e9b599061caa36846fc72a`. [Spec and evidence](T04-S2-FAILURES-AND-CANCELLATION.md) record commands, input hashes and the patch. | Mac arm64 Debug/Release 2/2 CTest, expected exit 8 and recovery, 100 Release repeats, ASan/UBSan and TSan 2/2, and zero leaks in the fault executable. Negative controls detected early publication, abandoned ownership and a non-atomic flag. C11/Swift consumers, static package and Xcode Debug unit suite passed. | Applied on the approved local branch. Fresh branch Debug/Release builds each passed 2/2 CTest. Acceptance is recorded in E35. Windows/Linux remain with B03/OWE-T03. |
| E35 | T04.S2 acceptance | User **PASS** ("pass"), 2026-11-07, for the applied candidate on `codex/t04-s2-failures-and-cancellation` at base `5eb7a1b`. | Verified all eight build input hashes against the E34 report. Reran both suites in the existing branch Debug and Release build directories with 2/2 passing in each. | T04.S2 accepted/done. PASS authorizes commit, local main merge, main push and merged local branch cleanup. |
| E36 | T04.S2 integration | Accepted nine-file candidate committed as `c66948f4936e0184e77ada46d59d9345046a7c68`, 2026-11-07. | Fast-forwarded `main` with `git merge --ff-only codex/t04-s2-failures-and-cancellation`, pushed to `origin/main`, and verified remote main at the candidate commit before deleting the merged local branch. This STATUS-only handoff uses the same authorized main push. | T04.S2 delivered. T04.S3 is next. Windows/MSVC and Linux/GCC execution remain with B03/OWE-T03. |

| E37 | T04.S3 Swift value adapter and native paragraph proof | Reviewed uncommitted snapshot based on clean `main/1c304d759476306c97a71d048d74d5c2db4a46c4`; [report](T04-S3-SWIFT-PARAGRAPH.md) records candidate hashes and commands. | PASS on arm64 macOS: 110 unit tests, including four adapter tests, one reader UI smoke, signed Release/static linkage, 2/2 standalone CTest in Debug and Release. Disposable probe verified cleanup, typed failures, overlapping work and in-flight cancellation. Missing releases and cancellation forwarding failed as expected. | User PASS recorded in E38. The native control proof runs in the hosted test target. Windows/Linux and production parity remain with their named gates. |
| E38 | T04.S3 acceptance | User **PASS** ("pass"), 2026-11-07, accepts the reviewed E37 candidate. User authorized this small slice directly on `main`. | Applied the exact four-file patch to clean `main/1c304d7` and compared all four files with the snapshot before bookkeeping. The two Swift input hashes and signed Release executable hash match E37. Acceptance bookkeeping adds no runtime execution. | T04.S3 and T04 accepted/done. PASS authorizes the focused commit and main push. |
| E39 | T04.S3 integration | Accepted four-file candidate committed directly on `main` as `6c33854a225656a80782473b1940d0493f381cfc`, 2026-11-07. | `git push origin main` succeeded, and `git ls-remote --exit-code origin refs/heads/main` verified the candidate revision. The user directed this small slice to stay on `main`. This STATUS-only closeout uses the same main push authorization. | T04 accepted and delivered. T05.S1 is next. Windows/Linux and production parity remain with their named gates. |
| E40 | T05.S1 fences and literal matcher | Uncommitted on `codex/t05-s1-fenced-code` at `c6bc744831f96ed6b05134e9affff7ecf4ec66a6`. The eight-file implementation, tests and core README patch has SHA-256 `5bae26bd7bf49c516af4efead6f52651f88b3cda20ad2db7460d7fd8a6a5cba8`, excluding this ledger. It is the binary Git diff against HEAD plus the no-index diff of `core/src/LiteralSyntax.h` against `/dev/null`. | macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, macOS SDK and Xcode 27.2 (27B52), CMake/CTest 4.4.5. The two [macOS presets](../../core/README.md#macos) configured in fresh directories with an explicit SDK. `cmake --build` and `ctest --test-dir <build> --output-on-failure --no-tests=error` passed 2/2 each. Both harness controls failed with exit 8 and recovered. A disposable Release copy with weakened closer comparisons failed on MD-008, MD-009 and the partial backtick closer test. ASan/UBSan with strict compiler warnings passed 2/2. A strict C11 client linked the Release archive and verified 200,000 ordered blocks from 3,100,000 input bytes after freeing the input. `xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' -configuration Debug -parallel-testing-enabled NO -only-testing:MarkyTests test` passed 112 tests with zero failures or skips. The shared corpus test checks MD-002, 008–011, 034 and 053–056. The same scheme built in Release and `codesign --verify --deep --strict` passed for Marky.app. | User PASS pending. The production reader remains on Swift, so no UI runtime or production parity claim. Windows/MSVC and Linux/GCC remain open. |
| E41 | T05.S1 acceptance | User **PASS** ("pass"), 2026-11-08, for the E40 candidate on `codex/t05-s1-fenced-code`. | The eight-file patch matched E40 byte for byte and all 13 recorded build input hashes matched. Debug and Release CTest reruns passed 2/2 each. Signed Release verification passed with access to the macOS trust store. The executable SHA-256 matched `02100940318b36d83ce743e700ba4c79e83bee56ba7692edd8a4998763d04edf`. | User PASS authorizes commit, fast-forward to local main, main push and merged-branch cleanup. |
| E42 | T05.S1 integration | Accepted candidate and acceptance record committed as `8d231620d88b85b5cb115347b76962c696613169`, 2026-11-08. | `git merge --ff-only codex/t05-s1-fenced-code` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deleting the merged local task branch. This handoff changes only STATUS and uses the same main-push authorization. | T05.S1 delivered. T05.S2 is next. Windows/MSVC and Linux/GCC execution remains with B03/OWE-T03. |
| E43 | T05.S2 base blocks | Isolated `/tmp/MarkyT05S2.vKpDcB/source` at `164e0dcd95bcaa74f9a839dc13fe8bbca2def654`. Seven-file implementation patch SHA-256 `1cdb5a3191d7a6c01f81ff26a38ecd09ae8c2e51be1b7b0dfd8fce98aad8d967` (binary Git diff, excluding STATUS). The 14 build-input hashes are in `checks/build-inputs.sha256` beside the snapshot. | macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, Xcode and macOS SDK 27.2, CMake/CTest 4.4.5. Configured the two macOS presets in fresh directories with explicit SDK, built with `cmake --build <build> --parallel 3`, and ran `ctest --test-dir <build> --output-on-failure --no-tests=error`. Debug and Release each passed 2/2, detected the forced harness failure (exit 8), and recovered. ASan/UBSan plus strict compiler warnings passed 2/2. A Release mutation triggered the hard-break, Setext precedence, and vertical blank-line regressions. A strict C11 consumer verified 300,000 ordered blocks from 4,740,000 input bytes after freeing the input. `xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' -configuration Debug -parallel-testing-enabled NO -only-testing:MarkyTests test` passed 113 tests in six suites, including 32 full base-block projections and two fence literal projections with reference definitions. The same scheme built in Release and `codesign --verify --deep --strict` passed. The sandbox entitlement was present and the Release executable SHA-256 is `a789cb106043c60b0f89826c411c068669d374ea5cc72ebb38e82f178b66800c`. | User PASS pending. Core-only scope with no production UI runtime or Windows/Linux execution claimed. B07 remains for T05.S3. |
| E44 | T05.S2 candidate application | User replied **“yes”** to creating `codex/t05-s2-base-blocks` and applying the E43 patch, 2026-11-08. Created the local branch from clean `main/164e0dcd95bcaa74f9a839dc13fe8bbca2def654` and applied the eight-file patch. | The applied seven-file implementation diff and all 14 recorded build-input hashes matched E43. Fresh Debug and Release macOS preset builds with an explicit SDK each passed CTest 2/2 from the task branch. `git diff --check` passed. The Mac unit and signing evidence remains from the byte-identical build inputs in E43. | User PASS pending for the applied uncommitted candidate. |
| E45 | T05.S2 acceptance | User **PASS** ("pass"), 2026-11-08, for the E44 candidate on `codex/t05-s2-base-blocks`. | The implementation diff matched E43 and all 14 build-input hashes matched. The Release executable matched its E43 SHA-256. Debug and Release CTest reruns each passed 2/2. | User PASS authorizes commit, fast-forward to local main, main push and merged-branch cleanup. |
| E46 | T05.S2 integration | Accepted candidate and acceptance record committed as `d08801f7a11a532150e10a180cf65c1c58bc8f04`, 2026-11-08. | `git merge --ff-only codex/t05-s2-base-blocks` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deleting the merged local task branch. This STATUS-only handoff uses the same main-push authorization. | T05.S2 delivered. T05.S3 is next, with B07 open. Windows/MSVC and Linux/GCC execution remains with B03/OWE-T03. |
| E47 | T05.S3 malformed input and interruption | Isolated `/tmp/MarkyT05S3.2qOKVF/source` at `5936de13649d86e68ab32595377560316829cce3`. Five-file implementation patch SHA-256 `b3553caa278d3f2978050211a778a6fbbe3d89b48a81801377d63f3bd0b59c74` (binary Git diff excluding STATUS). The candidate patch and 58 build-input hashes are in `checks/` beside the snapshot. | macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, Xcode and macOS SDK 27.2, CMake/CTest 4.4.5. The macOS Debug and Release presets configured with an explicit SDK and `-Wall -Wextra -Wpedantic -Werror`, built, and passed 2/2 CTest each. Both detected the forced harness failure (exit 8) and recovered. The Release fault suite passed 100 runs. The two B07 regressions failed before the fix. Removing the per-line cancellation poll failed the fault test with exit 8. ASan/UBSan and TSan builds each passed 2/2. `leaks --atExit -- marky_core_fault_tests` reported zero leaks. The Release archive omitted the test hooks, and a strict C11 consumer checked 300,000 ordered blocks after freeing its input. `xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' -configuration Debug -parallel-testing-enabled NO -only-testing:MarkyTests test` passed 113 tests in six suites with zero failures or skips. The same scheme built in Release. `codesign --verify --deep --strict` passed and the app-sandbox entitlement was true. The Release executable SHA-256 is `a692bb4b36b90ca6149159e4269f3dec527e63f09a186e7a80fb20d0cfe1b837`. | Pending branch application and user PASS. No production UI execution or Windows/Linux verification. Local review covered repository standards and the T05.S3 spec. |
| E48 | T05.S3 candidate application | User replied **“branch was supposed to be opened before any code change. go”**, 2026-11-08. Created `codex/t05-s3-malformed-input-and-interruption` from clean `main/5936de13649d86e68ab32595377560316829cce3` before applying the six-file E47 patch to the repository. | The applied patch matched E47 before this ledger update and all 58 build-input hashes matched. Fresh macOS Debug and Release preset builds from the branch, with an explicit SDK and strict warnings, each passed 2/2 CTest. `git diff --check` passed. The Mac unit and signing evidence remains from the byte-identical inputs in E47. | User PASS pending for the applied uncommitted candidate. |
| E49 | T05.S3 and T05 acceptance | User **PASS** ("pass"), 2026-11-08, for the E48 candidate on `codex/t05-s3-malformed-input-and-interruption`. | The five-file implementation patch and all 58 recorded build-input hashes matched E47. The signed Release executable hash matched E47. The applied Debug and Release CTest suites reran and each passed 2/2. The remote main revision was verified at the candidate base. | T05.S3 and T05 accepted. User PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E50 | T05.S3 and T05 integration | Accepted candidate and acceptance record committed as `fe2d30f369354161b7d69ef09f6925d1ef73a0d2`, 2026-11-08. | `git merge --ff-only codex/t05-s3-malformed-input-and-interruption` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This STATUS-only handoff uses the same main-push authorization. | T05 delivered and B07 resolved. T06.S1 is next. Windows/MSVC and Linux/GCC execution remains with B03/OWE-T03. |
| E51 | T06.S1 lists and task states | Uncommitted on `codex/t06-s1-lists-and-task-items` at `361c05c7108614cad872176e21cc23cff46e9c51`. Eight-file patch SHA-256 `44508a2586ce4e203157bdfd477a6bbacb3388aafe8ad4e5d8fd31cb50326d40` includes the new Unicode header and excludes this ledger. Patch and 62 build-input hashes are in `/tmp/MarkyT06S1.p68FRn/`. | macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake/CTest 4.4.5, Xcode/SDK 27.2. Both macOS presets configured with explicit `CMAKE_OSX_SYSROOT` and `-Wall -Wextra -Wpedantic -Werror`, built, and passed 2/2 CTest each. Both detected deliberate harness failure (exit 8) and recovered. The MD-015 regression failed on the base. A separate Release mutation detected altered depth and missing uppercase task recognition. Debug builds with `-fno-omit-frame-pointer -fsanitize=address,undefined` and `-fno-omit-frame-pointer -fsanitize=thread` passed 2/2 each. `leaks --atExit -- marky_core_fault_tests` found zero leaks, including interruption with a partially constructed list. A strict C11 consumer linked to the Release archive and verified 300,000 items from 6,450,000 bytes after freeing its input. The consumer repeated 150,000 groups of a checked parent and a nested `01)` child with one continuation, separated by a blank line. One run of `/usr/bin/time -l` measured 0.03 s elapsed and 44,072,960 bytes maximum RSS for generation, parse, verification, and release. The Unicode 17.0.0 tables matched Swift 6.4.2's numeric and grapheme suffix predicates over all Unicode scalars. | User PASS pending. The [Mac run below](#t06s1-mac-run) covers nine list projections and the signed Release build. The standards and spec review was performed in-session under AGENTS policy. Quote, table, image, and inline interpretation stay with their receiving slices. Unicode whitespace outside ASCII indentation can expose a list marker after Swift's block trimming even when its item preparation cannot read that marker. The portable parser requires a readable marker on the original line and retains such source. This edge is outside the accepted fixtures. Windows/MSVC and Linux/GCC execution remain under B03/OWE-T03. |
| E52 | T06.S1 acceptance | User **PASS** ("pass"), 2026-11-08, for the E51 candidate on `codex/t06-s1-lists-and-task-items`. | The eight-file implementation diff and all 62 build-input hashes matched E51. The signed Release executable hash matched E51. Debug and Release CTest reruns each passed 2/2. Remote main matched the verified base `361c05c`. | T06.S1 accepted. PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E53 | T06.S1 integration | Accepted candidate and acceptance record committed as `76d2f3dd1a31832a83cecab3fc81899dac61f209`, 2026-11-08. | `git merge --ff-only codex/t06-s1-lists-and-task-items` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This STATUS-only handoff uses the same main-push authorization. | T06.S1 delivered. T06.S2 is next. |
| E54 | T06.S2 blockquote structure | Uncommitted on `codex/t06-s2-blockquote-structure` at `3fbeaff52b2bfd1b1af0028b5a4be8ab1c2e457e`. Eight-file patch SHA-256 `ced2de49be10d3ac2a153751f7dbfbb03f7cbb885f009f1cd944b018cc8a412b` excludes this ledger. Patch and logs are in `/tmp/MarkyT06S2.SOm5R9/`. | [Verification below](#t06s2-mac-run). macOS arm64 Debug/Release and ASan/UBSan CTest passed 2/2 each. Both normal builds detected intentional harness failure and recovered. Fault tests injected allocation failure and cross-thread cancellation after an owned quote line was buffered. Apple `leaks` reported zero leaks. Six Swift compatibility tests and the full Mac test scheme passed. In-session standards and spec review found no remaining actionable findings. | E55 records user PASS. MD-024 verifies separation from table source while table recognition is pending in T07.S1. Inline interpretation and native quote presentation remain with their receiving slices. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E55 | T06.S2 acceptance | User **PASS** ("pass"), 2026-11-08, for E54 on `codex/t06-s2-blockquote-structure`. | The eight-file patch matched E54 byte for byte. Debug and Release CTest reruns each passed 2/2. Remote main matched the candidate base `3fbeaff`. | T06.S2 and T06 accepted. PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E56 | T06.S2 and T06 integration | Accepted candidate and acceptance record committed as `bd91edea992d946a4481257244cc993f2bd219df`, 2026-11-08. | `git merge --ff-only codex/t06-s2-blockquote-structure` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This STATUS-only handoff uses the same main-push authorization. | T06 delivered. T07.S1 is next. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E57 | T07.S1 portable tables | Verified uncommitted on `codex/t07-s1-table-parsing` at `c03e622da5e2365d2d2009a5f21ed30e012944b2`. Eight-file patch SHA-256 `001e931fa9f3f477aad7dff823d716681aca00d249a596c120008143d694fb67` excludes this ledger. Patch and logs are in `/tmp/MarkyT07S1.bkn5Sf/`. | [Verification below](#t07s1-mac-run). Debug, Release, and ASan/UBSan CTest passed 2/2 each. The Swift proof adapter matched all 19 applicable fixtures. The full Mac scheme passed 116 unit and eight UI tests, with two opt-in performance tests skipped. In-session standards and spec review found no remaining actionable findings. | E58 records user PASS. MD-090 verifies the table terminates before a recognized image. Image metadata belongs to T07.S2, inline cell semantics to T10.S3, and native table presentation to T11.S2. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E58 | T07.S1 acceptance | User **PASS** ("pass"), 2026-11-08, for E57 on `codex/t07-s1-table-parsing`. | The eight-file working-tree patch matched E57 byte for byte. Debug and Release CTest reruns each passed 2/2. Remote main matched the candidate base `c03e622`. | T07.S1 accepted. PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E59 | T07.S1 integration | Accepted candidate and acceptance record committed as `df7cb77d77af80d1dcbe68cc2273a8bd1fc4331d`, 2026-11-08. | `git merge --ff-only codex/t07-s1-table-parsing` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This STATUS-only handoff uses the same main-push authorization. | T07.S1 delivered. T07.S2 is next when selected. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E60 | T07.S2 standalone image metadata | Uncommitted on `codex/t07-s2-image-metadata` at `ef83f74bad8ffba9859ab294d567a41abb3e55b0`. Seven-file patch SHA-256 `8b1635a0e61d6a4de909cf8129effe4652d924b174f8036afbe139a1420dd652` excludes this ledger. Patch and logs are in `/tmp/MarkyT07S2.2t1YQa/`. | [Mac verification](#t07s2-mac-run). Debug, Release, and AddressSanitizer plus UndefinedBehaviorSanitizer CTest passed 2/2 each. The Swift proof adapter checked nine image-related corpus fixtures. The full macOS scheme passed 117 unit tests and eight UI tests, with two opt-in performance tests skipped. | E61 records user PASS. T10 owns inline and reference interpretation. T11.S2 owns native image presentation and access. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E61 | T07.S2 and T07 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E60. | The seven-file working-tree patch matched E60 byte for byte. macOS Debug, Release, and sanitizer CTest reruns each passed 2/2. Remote main matched the candidate base `ef83f74`. | T07.S2 and T07 accepted. PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E62 | T07.S2 and T07 integration | Accepted candidate and acceptance record committed as `2e71ef40f11d38190ca88177d2a36e1033734a0b`, 2026-11-13. | `git merge --ff-only codex/t07-s2-image-metadata` and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This ledger-only handoff uses the same main-push authorization. | T07 delivered. T08.S1 is next when selected. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E63 | T08.S1 literal code spans | Uncommitted on `codex/t08-s1-literal-code-spans` at `be3ca2f69f79410a223da666ab968fafb00a3d87`. The four-file patch under `core/` has SHA-256 `c17bbf86b10b4ade7af9da265bdd93867789bf2f5f333643e22b38cd7220e578`. The patch and run artifacts are in `/tmp/MarkyT08S1.V9cc3V/`. | [Mac verification](#t08s1-mac-run). Portable Debug, Release, and sanitizer CTest each passed 2/2. The shared corpus probe matched code text for 15 fixtures. The full Mac scheme passed 117 unit tests and eight UI tests, with two opt-in performance tests skipped. | Awaiting user PASS. The scanner works on prepared source inside the core. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E64 | T08.S1 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E63. | The four-file patch matched E63 byte for byte. macOS Debug, Release, and sanitizer CTest reruns each passed 2/2. The 15-fixture probe passed again. Remote main matched the candidate base `be3ca2f`. | PASS authorizes the focused commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E65 | T08.S1 integration | Accepted candidate and acceptance record committed as `4cd3d3ddc2d40f74bbec99b8ccfeba108298022b`, 2026-11-13. | Local `main` fast-forwarded to the candidate and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This ledger-only handoff uses the same main-push authorization. | T08.S1 delivered. T08.S2 is next when selected. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E66 | T08.S2 inline escapes, breaks, and entities | Verified before commit on `codex/t08-s2-inline-escapes-entities` at `784481073f62194062b604f9426d09ae846a31a8`. The six-file build and test patch has SHA-256 `99638270aa530f0c835e6ff53590fbee539079c0b0d473e4c66f7108547cca1d`. The patch and run artifacts are in `/tmp/MarkyT08S2.MnrjHS/`. | [Mac verification](#t08s2-mac-run). Debug, Release, and sanitizer CTest each passed 2/2. A separate probe matched 12 corpus fixtures. The Mac suite passed 117 unit tests. | Named entity evidence is provisional. T08.S3 owns final offline data and reference-label normalization. B03/OWE-T03 still tracks Windows/MSVC and Linux/GCC execution. |
| E67 | T08.S2 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E66. | All eight candidate files matched the review patch byte for byte before acceptance bookkeeping. Mac Debug, Release, and sanitizer CTest each passed 2/2 again. The 12-fixture probe passed again. Local and remote main matched the candidate base `7844810`. | PASS authorizes the focused commit, fast-forward to local main, main push, and merged-branch cleanup. |
| E68 | T08.S2 integration | The accepted candidate and acceptance record landed as `3dae9f88ae892a3dbcb84a2a6612948cbe798d4d`, 2026-11-13. | Local `main` fast-forwarded and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This ledger-only handoff uses the same main-push authorization. | T08.S2 delivered. T08.S3 is next when selected. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E69 | T08.S3 final offline entity and Unicode data | Uncommitted on `codex/t08-s3-offline-inline-data` from `677b30586f0bcc78d29246d95a942e79d2b13814`. The 11-file candidate patch excluding this ledger is `/tmp/marky-t08s3-build.jFcB2r/T08.S3.patch`, SHA-256 `ef0ff1b9570d14608f2d731c8cc2f9d3f1bc1071a52a7290c00293b2790665bc`. | [Mac verification](#t08s3-mac-run). Offline Debug, Release, and sanitizer CTest each passed 2/2. All 2,125 named entities matched WHATWG and Swift. All 12 prior shared corpus comparisons and 1,122,065 Swift label-key comparisons passed. Xcode passed 117 unit tests and bundled the notices. | User PASS pending. T10.S2 owns reference resolution. T09 and T10 receive final-data interaction fixtures after T08 acceptance. B03/OWE-T03 still tracks Windows/MSVC and Linux/GCC execution. |
| E70 | T08.S3 and T08 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E69. | The 11-file patch hash and reverse application check matched the working tree. The tested core snapshot matched byte for byte. Debug, Release, and sanitizer CTest reruns passed 2/2 each. Regeneration, all 12 corpus comparisons, 2,125 entity outputs, and 1,122,065 label comparisons passed again. Remote main matched the base `677b305`. | PASS authorizes commit, fast-forward to local main, main push, and merged-branch cleanup. T08 receipts for OWE-T01, OWE-T04, and OWE-T05 are closed. OWE-T08 is open for T09 and T10. |
| E71 | T08.S3 and T08 integration | The accepted candidate and PASS record landed as `adfac85022829e46b37be4d473b4b7d12c4639bf`, 2026-11-13. | Local `main` fast-forwarded and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. This ledger-only handoff uses the same main-push authorization. | T08 delivered. T09.S1 is next when selected. OWE-T08 is open for T09 and T10. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E72 | T09.S1 emphasis delimiter rules | Uncommitted on `codex/t09-s1-emphasis-delimiters` from `99721bf6178b57af7eed418fb5b6ab0411eb7c80`. The eight-file patch excluding this ledger is `/tmp/MarkyT09S1.5uTT8q/T09.S1.patch` with SHA-256 `ae1b83c73568f6be920764b46b1519f4830e206a7aba745daecbd300ed7bb827`. | [Mac verification](#t09s1-mac-run). Both CTest targets passed in Debug, Release, and the sanitizer build. Xcode passed 117 unit tests. The portable pass matched all 14 selected shared fixtures. | User PASS pending. T09.S2 owns combined-style parity and T09 receipt closure for OWE-T01, OWE-T04, OWE-T05, and OWE-T08. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E73 | T09.S1 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E72. | The patch hash and reverse application check matched. Debug, Release, and sanitizer CTest each passed 2/2 again. Unicode data regeneration and all 14 shared fixture comparisons passed again. The Foundation comparison reproduced the same results. Local and remote `main` matched `99721bf`. | PASS authorizes the focused commit, fast-forward to local `main`, push of `main`, and merged-branch cleanup. |
| E74 | T09.S1 integration | The accepted candidate and PASS record landed as `a7523b571b938cc78319af47835049d83eae6564`, 2026-11-13. | Local `main` fast-forwarded and `git push origin main` succeeded. `git ls-remote --exit-code origin refs/heads/main` confirmed the candidate before deletion of the merged local branch. The final ledger update uses the same main-push authorization. | T09.S1 delivered. T09.S2 is next when selected. The combined trait and range work, open T09 receipts, and non-Mac execution remain in their assigned slices. |
| E75 | T09.S2 nested and combined styles | Uncommitted on `codex/t09-s2-combined-styles` from `0951527400c91623d017b087b54a155bdd5a69f1`. The two-file code/test patch excluding this ledger is `/tmp/MarkyT09S2.v3jeem/T09.S2.patch`, SHA-256 `3cf9027cc144f8fd4d6f8195b69af8547960ce2c8bfd22bd57162f9e3493d4b6`. | [Mac verification](#t09s2-mac-run). Both CTest targets passed in Debug, Release, and the sanitizer build. Xcode passed 117 unit tests. The Release probe matched 17 shared fixtures and the list/quote portion of MD-071. | User PASS pending. Review the patch and the recorded test results. PASS authorizes commit, merge, push of `main`, and local branch cleanup. Windows/MSVC and Linux/GCC execution remains under B03/OWE-T03. |
| E76 | T09.S2 and T09 acceptance | User **PASS** ("pass"), 2026-11-13, accepts E75. | The patch hash and reverse application check matched the working tree. Debug, Release, and sanitizer CTest each passed 2/2 again. All 17 shared fixtures and both direct comparisons matched the recorded results. The separate combining-mark sweep reproduced 426 style differences with identical visible bytes. Local and remote `main` matched `0951527`. | PASS authorizes the focused commit, fast-forward to local `main`, push of `main`, and merged-branch cleanup. |

### T06.S1 Mac run

From the repository root, the focused check and complete test scheme used the following commands. The focused check passed all five tests. Its list check compared item order, exact marker and prepared source bytes, and depth for MD-015–018, MD-058–059, MD-061, MD-067, and MD-071. The complete run passed 114 unit tests in six suites and eight UI tests, including native list indentation. The two opt-in T02.S2 performance UI tests were skipped.

```sh
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath /tmp/MarkyT06S1.p68FRn/xcode \
  -parallel-testing-enabled NO -only-testing:MarkyTests/MarkdownCompatibilityTests test
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath /tmp/MarkyT06S1.p68FRn/xcode \
  -parallel-testing-enabled NO test
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Release -derivedDataPath /tmp/MarkyT06S1.p68FRn/xcode-release build
```

The Release app is `/tmp/MarkyT06S1.p68FRn/xcode-release/Build/Products/Release/Marky.app`, version 0.2.4 (5). `codesign --verify --deep --strict` passed and `com.apple.security.app-sandbox` was true. The Release executable SHA-256 is `a41643fd8b05f02c49f4bfb453f3e42ac9b4c183e4e24ffa115dacf30e756952`. These app checks exercise the current Swift reader and the core proof adapter through separate paths.

### T06.S2 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake/CTest 4.4.5, Xcode 27.2 (27B52), macOS SDK 27.2. Run from the repository root with a fresh temporary directory for `T06_BUILD`:

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release; do
  build_dir="$T06_BUILD/core-$config"
  cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$config" \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
  cmake --build "$build_dir" --parallel 4
  MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --test-dir "$build_dir" --output-on-failure -R '^marky_core_tests$'
  ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath "$T06_BUILD/xcode" -parallel-testing-enabled NO \
  -only-testing:MarkyTests/MarkdownCompatibilityTests test
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath "$T06_BUILD/xcode" -parallel-testing-enabled NO test
```

Both intentional failures exited 8. The sanitizer run repeated Debug in a separate directory with `-fno-omit-frame-pointer -fsanitize=address,undefined` appended to `CMAKE_CXX_FLAGS`. `leaks --atExit -- <Debug-build>/marky_core_fault_tests` passed. Before quote recognition was added, the C tests failed on MD-019, MD-058, and MD-060. The same tests passed with recognition enabled.

The Swift quote test compared block order, depths, and prepared source bytes for MD-019, MD-024, MD-058, MD-060, MD-061, and MD-071. The portable tests also verify CRLF, embedded NUL, empty quoted lines at different depths, code source spanning lines, and preservation of quote-like graphemes. The complete Mac run passed 115 unit tests and eight UI tests, with two opt-in performance tests skipped.

A synthetic C11 consumer linked the Release archive and verified 300,001 quote lines after freeing the input. The 3,700,001-byte input repeated 100,000 CRLF groups of an outer line, a nested line with Unicode and NUL, an empty quoted line, and a blank separator. Its final line used one million quote markers. A local Python subprocess run measured 0.0525 s elapsed and 27,721,728 bytes maximum RSS for generation, parsing, verification, and release. This was a stress check. The T02/T17 performance comparison uses its fixed fixtures.

### T07.S1 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake/CTest 4.4.5, Xcode 27.2 (27B52), macOS SDK 27.2. Run from the repository root with a fresh temporary directory for `T07_BUILD`:

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release; do
  build_dir="$T07_BUILD/core-$config"
  cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$config" \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
  cmake --build "$build_dir" --parallel 4
  MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --test-dir "$build_dir" -R '^marky_core_tests$' --output-on-failure
  ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
leaks --atExit -- "$T07_BUILD/core-Debug/marky_core_fault_tests"
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath "$T07_BUILD/xcode" -parallel-testing-enabled NO \
  -only-testing:MarkyTests/MarkdownCompatibilityTests test
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
  -configuration Debug -derivedDataPath "$T07_BUILD/xcode" -parallel-testing-enabled NO test
```

Both deliberate CTest failures exited 8 and the ordinary tests recovered. The sanitizer run repeated Debug in a separate directory with `-fno-omit-frame-pointer -fsanitize=address,undefined` appended to `CMAKE_CXX_FLAGS`. Apple `leaks` reported zero leaks. The MD-024 block-order check failed on the base parser and passed after table recognition. Fault tests interrupted after the first owned table body row and verified typed failure, cross-thread cancellation, and successful recovery.

The seven-test Swift compatibility suite compared prepared cell bytes, alignment, and block order for MD-020–026, MD-062–068, and MD-088–092. The portable harness also checked CRLF, Unicode, embedded NUL, retained escapes, normalized width, invalid accessors, and source ownership. A local differential probe agreed with the Swift row splitter on 2,000 seeded rows containing ASCII syntax, combining accents, whitespace, and emoji.

A C11 Release archive consumer and the Swift proof adapter verified a 331,074-byte table with 32,768 columns and 100,000 one-cell rows, including indexed reads of virtual empty cells. A separate C11 stress input used one 4,504,518-byte document with 3,000 distinct unmatched backtick runs in one row. It took 3.8181 s with repeated scans and 0.0155 s with the indexed matcher in local subprocess observations. These are stress observations. The T02/T17 comparison uses its fixed fixtures.

### T07.S2 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, Xcode 27.2 (27B52), and macOS SDK 27.2. Run from the repository root with a fresh temporary directory for `T07S2_BUILD`.

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release; do
	build_dir="$T07S2_BUILD/core-$config"
	cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$config" \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" \
		-DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
	cmake --build "$build_dir" --parallel 4
	MARKY_CORE_TEST_FORCE_FAILURE=1 ctest --test-dir "$build_dir" -R '^marky_core_tests$' --output-on-failure
	ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
leaks --atExit -- "$T07S2_BUILD/core-Debug/marky_core_fault_tests"
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
	-configuration Debug -derivedDataPath "$T07S2_BUILD/xcode" -parallel-testing-enabled NO test
```

The two intentional test failures exited 8. The ordinary tests passed on the next run. The sanitizer run repeated Debug in a separate directory with `-fno-omit-frame-pointer -fsanitize=address,undefined` appended to `CMAKE_CXX_FLAGS`. `leaks` reported zero leaks. Fault tests injected allocation failure and cross-thread cancellation after the core owned all three image fields.

The new C checks failed before image blocks were emitted and passed with recognition enabled. The Swift suite covered MD-037–039, MD-079–083, and MD-090. It verified exact metadata bytes, the table-to-image transition, and prepared prose for malformed and inline syntax. The reference-image case remains prepared source until T10 handles definitions and inline alt text.

A local comparison checked 7,020 combinations against the Swift matcher. It found that the core accepted vertical tabs and form feeds inside titles that Swift rejects. After correcting the matcher, all 7,020 comparisons agreed. A C11 consumer verified every field in 100,000 image blocks after freeing the 7,900,000-byte input.

### T08.S1 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, Xcode 27.2 (27B52), and macOS SDK 27.2. Set `T08S1_BUILD` to a fresh temporary directory and run from the repository root.

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release; do
	build_dir="$T08S1_BUILD/core-$config"
	cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$config" \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" \
		-DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
	cmake --build "$build_dir" --parallel 4
	ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
	-configuration Debug -derivedDataPath "$T08S1_BUILD/xcode" -parallel-testing-enabled NO test
```

The sanitizer build repeated Debug in `core-Sanitizers` with `-fno-omit-frame-pointer -fsanitize=address,undefined` appended to `CMAKE_CXX_FLAGS`. The portable tests start from paragraphs and table cells returned by the C document API. They check MD-041–044, prepared UTF-8 byte ranges, escapes, literal punctuation, padding, line endings, and table pipes. Disabling padding removal in a temporary copy made the MD-043 regression and four related cases fail with CTest exit 8.

An independent probe linked the Release archive and compared literal code bytes with the checked-in expectations for MD-004, MD-013–014, MD-022, MD-028, MD-034, MD-041–044, MD-048, MD-062, MD-064, MD-069, and MD-074. The comparison covered code text and checked range ordering and bounds. Emphasis, links, and entities remain later inline work. The shared matcher follows Swift's table delimiter boundaries when a combining mark attaches to a backtick. Foundation's inline parser differs on that edge outside the accepted fixtures. Recheck it for T12 reader parity.

### T08.S2 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, Xcode 27.2 (27B52), and macOS SDK 27.2. Set `T08S2_BUILD` to a fresh temporary directory and run from the repository root.

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release; do
	build_dir="$T08S2_BUILD/core-$config"
	cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$config" \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" \
		-DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror'
	cmake --build "$build_dir" --parallel 4
	ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
	-configuration Debug -derivedDataPath "$T08S2_BUILD/xcode" -parallel-testing-enabled NO \
	test -only-testing:MarkyTests
```

The sanitizer build repeated Debug in `core-Sanitizers` with `-fno-omit-frame-pointer -fsanitize=address,undefined` appended to `CMAKE_CXX_FLAGS`. The Xcode run used local package caches after the restricted run failed to write them. The production reader still uses Swift, so the Xcode run covers the existing Mac unit suite and package integration. UI tests were outside this run.

Portable tests check token text and contiguous byte ranges in prepared paragraphs and table cells. They cover soft line folding, retained breaks, escape parity, code isolation, malformed entities, and decoded punctuation that stays literal. A temporary Release build with `NotEqualTilde` decoding disabled failed MD-073 with CTest exit 8.

A probe linked the Release archive and matched text and code bytes against MD-003, MD-028–029, MD-041–047, MD-073, and MD-086. The portable tests also check the lexical portion of MD-074. Its emphasis remains T09 work. A seeded check of 5,015 numeric references matched Python UTF-8 encoding with the expected replacement policy for null, surrogates, and out-of-range scalars.

The numeric parser follows the observed Mac limit of eight digits in either base. It requires a semicolon. The named entries exercise single-scalar, multi-scalar, and newline output. T08.S3 replaces the provisional entries and reruns the checks offline. The lexer preserves source spelling, including decomposed accents. Reference-label normalization for MD-072 belongs to T08.S3, with resolution in T10.S2. The accepted inert HTML fixtures cover decoded brackets here. Raw HTML tag and autolink boundaries still need parity checks when inline links and the full corpus are implemented.

### T08.S3 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, and Xcode 27.2 (27B52) with the macOS 27.2 SDK. From the repository root, the offline run copied `core/` into a fresh temporary directory and ran CMake and CTest under a profile that denied network access and reads from the downloaded upstream-data directory. Set `T08S3_BUILD` to a fresh directory. The second deny rule records the location used in E69.

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
cp -R core "$T08S3_BUILD/core"
cat > "$T08S3_BUILD/offline.sb" <<'PROFILE'
(version 1)
(allow default)
(deny network*)
(deny file-read* (subpath "/private/tmp/marky-t08s3-data"))
PROFILE
(
	cd "$T08S3_BUILD"
	/usr/bin/sandbox-exec -f offline.sb /bin/sh -eu -c '
		for config in Debug Release Sanitizers; do
			mode="$config"
			flags="-Wall -Wextra -Wpedantic -Werror"
			if [ "$config" = Sanitizers ]; then
				mode=Debug
				flags="$flags -fno-omit-frame-pointer -fsanitize=address,undefined"
			fi
			cmake -S core -B "$config" -G "Unix Makefiles" -DCMAKE_BUILD_TYPE="$mode" \
				-DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$1" -DCMAKE_CXX_FLAGS="$flags"
			cmake --build "$config" --parallel 4
			ctest --test-dir "$config" --output-on-failure --no-tests=error
		done
	' sh "$sdk_path"
)
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
	-configuration Debug -derivedDataPath "$T08S3_BUILD/xcode" -parallel-testing-enabled NO \
	test -only-testing:MarkyTests
```

- Both CTest executables passed in all three configurations. The Release test executable imports only `libc++` and `libSystem`. The Xcode unit run passed 117 tests in six suites. The bundled notices matched the source file byte for byte. The production reader uses its Swift parser. UI tests were outside this run.
- The [regeneration procedure](../../core/README.md#update-the-inline-data) reproduced both generated headers byte for byte. A probe linked to the Release archive checked the complete set of 2,125 semicolon-terminated names against pinned WHATWG code points, including token kind and full source range. A direct Foundation Markdown probe matched the same set. A temporary build with the `emsp` name family misordered and canonical decomposition disabled failed the new entity and MD-072 checks with CTest exit 8.
- The Release corpus probe matched text and literal code bytes for MD-003, MD-028–029, MD-041–047, MD-073, and MD-086. CTest reran the provisional lexer assertions against the final table, including the lexical portion of MD-074. MD-072 checks label-key equivalence and the sharp-S distinction. Reference resolution belongs to T10.S2.
- A Release probe compared 1,122,065 labels with the Swift whitespace and lowercase pipeline plus canonical decomposition. It covered every valid scalar inside a label, 10,000 seeded mixed labels, and a 40,000-mark run. Foundation's decomposition helper left two Todhri characters composed. The oracle used their Unicode 17 decompositions after Swift string equality confirmed each equivalent form. The comparison found zero differences.

### T09.S1 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, Xcode 27.2 (27B52), and macOS SDK 27.2. Set `T09S1_BUILD` to a fresh directory and run from the repository root.

```sh
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
for config in Debug Release Sanitizers; do
	mode="$config"
	flags='-Wall -Wextra -Wpedantic -Werror'
	if [ "$config" = Sanitizers ]; then
		mode=Debug
		flags="$flags -fno-omit-frame-pointer -fsanitize=address,undefined"
	fi
	build_dir="$T09S1_BUILD/core-$config"
	cmake -S core -B "$build_dir" -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE="$mode" \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_OSX_SYSROOT="$sdk_path" -DCMAKE_CXX_FLAGS="$flags"
	cmake --build "$build_dir" --parallel 4
	ctest --test-dir "$build_dir" --output-on-failure --no-tests=error
done
xcodebuild -scheme Marky -project Marky.xcodeproj -destination 'platform=macOS,arch=arm64' \
	-configuration Debug -derivedDataPath "$T09S1_BUILD/xcode" -parallel-testing-enabled NO \
	test -only-testing:MarkyTests
```

- The internal resolver takes one prepared inline region. The tests assert visible text, style flags, literal kinds, and exact UTF-8 source ranges. They cover punctuation, Unicode neighbors, intraword underscores, adjacent runs, unmatched syntax, escapes, entities, code isolation, and breaks. A 40,000-run case exercises incompatible openers and closers. Disabling the rule of three in a temporary copy failed its regression check with CTest exit 8.
- The Unicode regeneration check reproduced the committed-format headers byte for byte using the pinned T08 data. The Release probe matched text and traits for MD-013, MD-026, MD-028–029, MD-041–044, MD-048, MD-070, MD-073–074, and MD-085–086. It obtained prepared paragraphs and table cells from the C document API. The macOS unit run includes the shared native corpus. UI tests were outside this run.
- A separate comparison with Foundation matched 6,274 of 6,327 direct inline inputs. All 53 differences involved three interacting asterisk runs, with at least one run three or more markers wide. Four changed the visible marker text. For example, `**a*b****` emits strong `a` and combined `b` with one trailing star in the core. Foundation leaves the initial `**a` literal and emphasizes `b` with three trailing stars. Use these cases in T09.S2 when establishing combined-style parity. Also carry the separate combining-mark projection case `a*\u{0301}b*c` into T11.S1, where the native adapter maps portable byte ranges to native text ranges.
- The production Mac reader uses its Swift parser. This slice exposes the resolver to portable callers with prepared source. Document-level invocation and cooperative cancellation for inline processing must be verified when the resolver becomes part of document creation.

### T09.S2 Mac run

macOS 27.2 (26B123) arm64, Apple Clang 21.0.0, CMake and CTest 4.4.5, Xcode 27.2 (27B52), and macOS SDK 27.2. Run the [T09.S1 build and test commands](#t09s1-mac-run) with a fresh build directory. The E75 builds, probes, patch, and logs are in `/tmp/MarkyT09S2.v3jeem`. The Xcode run used `-resultBundlePath /tmp/MarkyT09S2.v3jeem/MarkyTests-final.xcresult`. The result summary reports 117 passed and zero failures, skips, or runtime warnings.

- The portable fixtures check exact visible text, token kind, traits, and half-open prepared UTF-8 ranges. They include MD-027 and MD-069, same-trait nesting, overlapping asterisk runs, mixed-width strikes, adjacent tildes and underscores, breaks, and all three styles around Unicode code and protected punctuation. The escape and entity cases use the final checked-in T08 data. The candidate's new tests failed against the base implementation with CTest exit 8. All existing S1 checks passed on the candidate.
- The Release probe matched MD-013, MD-026–029, MD-041–044, MD-048, MD-060, MD-069–070, MD-073–074, and MD-085–086. It resolved prepared paragraphs, table cells, and the reassembled quote body from the C document API. For MD-060 it compared per-line traits as the shared fixture does. For MD-071 it checked the list and quote traits plus the strong heading label; T10 checks link syntax and destinations in MD-004, MD-032, MD-071, and MD-077.
- The direct comparison with Foundation matched all 6,327 S1 inputs and 55,272 additional inputs covering three runs up to width 12 and seeded mixtures of up to ten runs with code, entities, escapes, and Unicode. A separate 58,320-input boundary sweep matched visible bytes throughout. Its 426 style differences all involved a combining accent next to delimiters. For example, the portable resolver marks the bytes for the letter in `***x***\u{0301}` as strong and emphasized. The native character projection displays the resulting grapheme without those traits. T11.S1 owns this projection alongside the earlier `a*\u{0301}b*c` case.
- The scope and coding-standards checks were performed in-session under repository policy. The Swift reader still uses its production parser. This core-only candidate uses the existing prepared-region resolver. Document-level invocation and inline cancellation are due when the resolver is wired into document creation. Native UI and Windows/Linux execution were outside this run.

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
| Commit / merge / main push / delete merged branch | User clarification, 2026-11-06: "pass means authorization, unless i specifically ask for PR. so commit merge etc. that is what PASS means" | `8cfe810` committed, merged with `--ff-only` into main and successfully pushed to origin/main. This final checkpoint uses the same authorized main push; remove the merged local task branch after publication. No task branch was pushed. |
| Open PR | Requires a specific user request | Not requested or executed for T01.S1. |

### T01.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Corpus, tests and handoff edits | User selected T01.S2, 2026-11-06 | Implemented and verified in E08; accepted by user PASS in E09. |
| Create local branch | User reply: "Yes, create the branch" for `codex/t01-s2-fixture-corpus` | Created from clean `main/6954ff4`. Initial restricted-shell Git write failed; authorized execution with required filesystem access succeeded. No worktree was needed for read-only exploration. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-06, for E08 under AGENTS policy | `ee778b7` committed, merged with `--ff-only` into local main and pushed to origin/main. This final checkpoint uses the same authorized main push; delete the merged local task branch after publication. No task branch pushed. |
| Open PR | Requires a specific user request | Not requested or executed. |

### T01.S3 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Characterization fixtures, checks and handoff | User selected T01.S3, 2026-11-06 | Implemented and verified in E11; user PASS accepted in E12. |
| Create local branch | User reply: "Yes, create the branch" for `codex/t01-s3-characterization` | Created from clean `main/ff949b6`. Initial restricted Git write failed; authorized escalation succeeded. Read-only explorer made no edits or Git mutations; no worktree created. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-06, accepts E11 under AGENTS policy | `cea77e9` committed, fast-forwarded into main and pushed to origin/main; merged local task branch deleted. E13 records execution; this final STATUS-only closeout uses the same authorized main push. |
| Open PR | Requires a specific user request | Not requested or executed. |

### T02.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Current-Mac baseline and handoff | User selected T02.S1, 2026-11-06 | Fresh Debug full unit/UI tests, signed Release build, baseline report and ledger/discovery updates. No app behavior/settings changes. |
| Create local branch | User reply: "Yes, create the branch" for `codex/t02-s1-mac-baseline` | Created from clean `main/32c6451`. Initial restricted Git write failed; authorized execution access succeeded. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-06, accepts E14 under AGENTS policy | `4177663` committed, fast-forwarded into main and pushed to origin/main; merged local task branch deleted. E16 records execution; this final STATUS-only closeout uses the same authorized main push. |
| Open PR | Requires a specific user request | Not requested or executed. |
| T02.S2 local branch | User explicitly answered “Yes, create the branch”, 2026-11-06 | Created `codex/t02-s2-performance-baseline` from clean `main/f910e20f6a0eb0a296843aa7cfd327d0230075f9`; restricted-shell ref creation failed, approved execution-access retry succeeded. No source/Git history changed by that failure. |
| T02.S2 commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-06, accepts E18 under AGENTS policy | `31ebae6` committed, fast-forwarded into main and pushed to origin/main; remote revision verified and merged local task branch deleted. E20 records execution; final STATUS-only delivery bookkeeping uses the same authorized main push. No PR requested. |

### T03.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Core build, harness and evidence edits | User selected T03.S1, 2026-11-06 | Nine-file candidate implemented/verified in E21; no production app changes. |
| Create local branch | User explicitly replied “Yes, create the local branch” for `codex/t03-s1-core-build` | Created from clean `main/d3780ba1fff0163eb8c0a47ceb0d594be565c255`; restricted ref write failed, authorized execution-access retry succeeded. Read-only exploration used no worktree or edits. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-06, accepts E21 under repository policy | `ef0248e` committed, merged with `--ff-only` into main and pushed to origin/main; remote revision verified and merged local task branch deleted. E23 records execution; this STATUS-only closeout uses the same authorized main push. |
| Open PR / push task branch | Requires an explicit user request | Not requested or executed. |

### T03.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Platform configurations, procedures and evidence | User selected T03.S2, 2026-11-06 | Six-file candidate applied/verified in E24, reviewed in E25 and accepted by user PASS in E26. |
| Create local branch | User explicitly replied **“Yes, create the local branch”** for `codex/t03-s2-platform-builds` and candidate application | Created from clean `main/e92588fd5db5ed6ea60395738da1613c923f6a97`; restricted ref write failed, authorized execution-access retry succeeded. Read-only explorers made no repository edits or Git mutations. |
| Review commits / task-branch push / open PR / fix findings | User: **“send to `gh` for CodeRabbit code review. auto-fix findings.”**, 2026-11-06 | `4e63f04` committed and pushed to `origin/codex/t03-s2-platform-builds`; PR #4 created via `gh`, CodeRabbit review requested and completed without actionable findings (E25). This report/STATUS review closeout uses the same publication authorization. |
| Merge / main integration / merged-branch cleanup | User **PASS** ("pass"), 2026-11-06, accepts PR #4 at `dad49a7` under the requested PR workflow | Acceptance checkpoint `10a63e3` pushed; PR #4 merged with exact-head check as `cf800a1`; local main fast-forwarded and merged remote/local branch deleted. E27 records execution; this STATUS-only closeout uses the same authorized main push. |

### T03.S3 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Swift package, static Xcode integration and verification | User selected T03.S3, 2026-11-07 | Seven-file candidate prepared and verified in a temporary snapshot (E28). |
| Create local task branch and apply candidate | User replied **“go for it”** to creating `codex/t03-s3-xcode-integration` and applying the verified patch | Created from clean `main/dd7c7e0` after the restricted ref write was denied. Applied the patch and compared build inputs with the verified snapshot. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-07, accepts E28 under repository policy | Executed in E30. |

### T04.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| C interface, ownership tests and evidence edits | User selected T04.S1, 2026-11-07 | Implemented and verified in an isolated snapshot (E31). |
| Create local task branch and apply candidate | User replied **“YES please”**, 2026-11-07 | Created `codex/t04-s1-document-interface` from clean `main/6a56976` and applied the verified patch. Compared each applied file to the snapshot before handoff bookkeeping. |
| Commit / merge / main push / delete merged branch | User **PASS** ("pass"), 2026-11-07, accepts the applied E31 candidate under repository policy | `ef686cb` committed, merged with `--ff-only` into main and pushed to origin/main. Verified the remote revision before deleting the merged local task branch (E33). This STATUS-only handoff uses the same authorized main push. |

### T04.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Spec, core implementation and verification | User selected T04.S2 and asked to design a spec and implement it, 2026-11-07 | Implemented and verified in an isolated source snapshot (E34). |
| Create local task branch and apply candidate | User replied **“yes”** to creating `codex/t04-s2-failures-and-cancellation` and applying the verified patch, 2026-11-07 | Created from clean `main/5eb7a1b` after the restricted ref write was denied. The nine applied files matched the snapshot before handoff bookkeeping. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass"), 2026-11-07, accepts the applied E34 candidate under repository policy | Executed in E36. |

### T04.S3 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Spec, implementation handoff and review | User selected T04.S3 and requested a spec, implementer handoff and supervisor review, 2026-11-07 | Implemented in an isolated source snapshot, reviewed and verified (E37). |
| Apply on local main | User directed this small slice to stay on `main`, 2026-11-07 | Applied the reviewed patch directly to clean `main/1c304d7` and verified candidate identity (E38). |
| Commit and push main | User **PASS** ("pass"), 2026-11-07, accepts E37 under repository policy | Executed in E39. |

### T05.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T05.S1 | User replied **“proceed please and thanks”** to the branch and implementation request, 2026-11-08 | Created `codex/t05-s1-fenced-code` from clean `main/c6bc744` before edits. Verified the uncommitted candidate in E40. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass"), 2026-11-08, accepts E40 under repository policy | Authorized in E41 and executed in E42. |

### T05.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Select and implement T05.S2 | User selected T05.S2, 2026-11-08 | Prepared and verified the isolated candidate in E43. |
| Create local branch and apply candidate | User replied **“yes”** to creating `codex/t05-s2-base-blocks` and applying the verified patch, 2026-11-08 | Executed in E44. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass"), 2026-11-08, accepts E44 under repository policy | Authorized in E45 and executed in E46. |

### T05.S3 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Select and implement T05.S3 | User selected T05.S3 and specified both B07 cases, 2026-11-08 | Prepared and verified the isolated candidate in E47. |
| Create local branch and apply candidate | User replied **“branch was supposed to be opened before any code change. go”**, 2026-11-08 | Executed in E48. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass"), 2026-11-08, accepts E48 under repository policy | Authorized in E49 and executed in E50. |

### T06.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T06.S1 | User selected T06.S1 and explicitly directed creating a local `codex/` branch before editing, 2026-11-08 | Created `codex/t06-s1-lists-and-task-items` from clean main at `361c05c` before the first edit. E51 records the verified candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts the verified E51 candidate under repository policy, 2026-11-08 | Authorized in E52 and executed in E53. |

### T06.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T06.S2 | User selected T06.S2 and replied **"Yes, create the local branch"**, 2026-11-08 | Created `codex/t06-s2-blockquote-structure` from clean `main/3fbeaff` before edits. The restricted shell could not write the ref. The authorized execution-access retry succeeded. E54 identifies the verified candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts the verified E54 candidate under repository policy, 2026-11-08 | Authorized in E55 and executed in E56. |

### T07.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T07.S1 | User selected T07.S1 and replied **"Yes, create the local branch"**, 2026-11-08 | Created `codex/t07-s1-table-parsing` from clean `main/c03e622` before applying changes to the repository. E57 identifies the verified candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E57 under repository policy. | Authorized in E58 and executed in E59. |

### T07.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T07.S2 | User selected T07.S2 and replied **"Create the branch"**, 2026-11-13. | Created `codex/t07-s2-image-metadata` from clean `main/ef83f74` before editing. E60 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E60 under repository policy. | Authorized in E61 and executed in E62. |

### T08.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T08.S1 | User selected T08.S1 and replied **"Create the branch"**, 2026-11-13. | Created `codex/t08-s1-literal-code-spans` from clean `main/be3ca2f` before editing. E63 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E63 under repository policy. | E64 records authorization and E65 records execution. |

### T08.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T08.S2 | User selected T08.S2 and replied **"Create the branch and implement"**, 2026-11-13. | Created `codex/t08-s2-inline-escapes-entities` from clean `main/7844810` before editing. E66 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E66 under repository policy. | E67 records authorization and E68 records execution. |

### T08.S3 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T08.S3 | User selected T08.S3 and replied **"Create the branch and implement"**, 2026-11-13. | Created `codex/t08-s3-offline-inline-data` from clean `main/677b305` before editing. E69 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E69 under repository policy. | E70 records authorization and E71 records execution. |

### T09.S1 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T09.S1 | User selected T09.S1 and replied **"Create the branch and implement"**, 2026-11-13. | Created `codex/t09-s1-emphasis-delimiters` from clean `main/99721bf` before editing. E72 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E72 under repository policy. | E73 records authorization and E74 records execution. |

### T09.S2 authorization

| Operation | Authorization | Executed / evidence |
| --- | --- | --- |
| Create local branch and implement T09.S2 | User selected T09.S2 and replied **"Create the branch and implement"**, 2026-11-13. | Created `codex/t09-s2-combined-styles` from clean `main/0951527` before editing. E75 identifies the candidate. |
| Commit, merge, push and merged-branch cleanup | User **PASS** ("pass") accepts E75 under repository policy. | E76 records authorization. |

## Contract amendments

None. The agreed contract is recorded in CONTRACT.md. A later amendment must cite the explicit user decision, affected requirement/fixture/ticket IDs, and necessary revalidation. Differences from current behavior remain blocked unless the user approves that scope change.
