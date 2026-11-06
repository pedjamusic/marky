# Phase 6 — Project rules

These are static ticket definitions. [CONTRACT](../CONTRACT.md) is authoritative; [STATUS](../STATUS.md) owns all live state, evidence, blockers, and obligation closure. Apply [completion and acceptance](../README.md#completion-and-acceptance) to every ticket. A whole-ticket prerequisite means accepted completion. A slice prerequisite requires that slice's recorded technical verification, without implying whole-ticket or user acceptance. Every slice inherits its ticket prerequisites and earlier sibling slice evidence unless explicitly stated otherwise.

This phase can progress independently of parser work once its explicit prerequisites are verified. The core receives metadata, opaque identities, relative path segments, native match results, and ordering inputs. Native adapters retain filesystem enumeration, absolute paths/canonicalization, security access, persistence, localization, and OS-language matching. Different native matching behavior across OSes is the approved boundary.

## T13 — Eligibility and project trees

### Goal

Extract reusable entry eligibility and tree assembly from native filesystem operations.

### Prerequisites

Verified `T03.S1` and `T04.S2` evidence; accepted whole `T04` is not required. These slice prerequisites permit progress independently of parser tickets.

### Inputs

Read [tree/scanner owner](../../../Marky/FileNode.swift), [view model](../../../Marky/ViewModels/ContentViewModel.swift), [favorites store](../../../Marky/Services/ProjectFavoritesStore.swift), and [project regression tests](../../../MarkyTests/MarkyTests.swift). Apply [project rules](../CONTRACT.md#project-rules) and [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T13.S1 | Eligibility from supplied metadata: supported extensions, hidden entries, package entries, regular files, directory symlinks, and document symlinks. | Portable fixtures distinguish eligible Markdown, excluded text/hidden/package/special entries, skipped linked directories, and linked regular documents retaining project-local identity. Native metadata acquisition remains outside core. |
| T13.S2 | Tree assembly with empty-folder pruning and explicit complete versus partial input semantics. | Portable fixtures verify nested retained ancestors, empty branches, stable identities, complete/partial result distinctions, and failure/unknown input; incomplete enumeration cannot become evidence that absent favorites are missing. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T13`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T13`: origin `T13`; recipient `T16`. Deliver eligibility/tree fixtures and metadata/completeness contract. Close when T16 native enumeration and complete/partial/failure paths reproduce those results.

### Acceptance

Both slices pass identical portable fixtures with no absolute-path, canonicalization, filesystem, or security APIs inside core. Record the applicable review.

### Handoff

Deliver the tree/metadata contract to `T14.S1` and `T15.S1` after T13 acceptance; provide native integration cases for T16.

## T14 — Index and query filtering

### Goal

Build a reusable project index and filtering rules while preserving native language matching.

### Prerequisites

Accepted `T13`.

### Inputs

Read [tree/scanner owner](../../../Marky/FileNode.swift), [view model](../../../Marky/ViewModels/ContentViewModel.swift), [favorites store](../../../Marky/Services/ProjectFavoritesStore.swift), and [project regression tests](../../../MarkyTests/MarkyTests.swift). Consult [outline tests](../../../MarkyTests/FilesOutlineTests.swift) and [outline owner](../../../Marky/FilesOutlineView.swift). Apply [project rules](../CONTRACT.md#project-rules).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T14.S1 | Index based on opaque identity and relative path segments, with stable parent/child relationships. | Portable fixtures verify distinct document-link identities, nested paths, index lookups, and identity-preserving rebuilds without resolving native paths. |
| T14.S2 | Filtering from native-supplied match results and ordering, retaining ancestors, favorite-path query behavior, and empty-query semantics. | Portable fixtures verify ancestor retention, folder/document matches, favorites matching their approved path query, empty-query full results, and stable supplied order. Native adapters test their own localized matching separately. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T14`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T14`: origin `T14`; recipient `T16`. Deliver index/query fixtures and native matching/order input contract. Close when T16 search/favorites and native outline checks cover each case.

### Acceptance

Both slices pass; core filtering consumes supplied matching/order decisions and does not impose a cross-platform locale algorithm. Record the applicable review.

### Handoff

Provide the accepted index/query contract and obligation cases to `T16.S2`.

## T15 — Favorite reconciliation

### Goal

Express membership and reconciliation decisions without moving the native persistence backend.

### Prerequisites

Accepted `T13`.

### Inputs

Read [tree/scanner owner](../../../Marky/FileNode.swift), [view model](../../../Marky/ViewModels/ContentViewModel.swift), [favorites store](../../../Marky/Services/ProjectFavoritesStore.swift), and [project regression tests](../../../MarkyTests/MarkyTests.swift). Read [session and grants](../../../Marky/Services/ProjectSessionService.swift). Apply [project rules](../CONTRACT.md#project-rules) and [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T15.S1 | Favorite membership decisions for complete, partial, and unknown availability. | Fixtures retain excluded/unavailable/unknown entries and prune only confirmed missing entries with sufficient evidence; single-file partial views preserve favorites outside their view. |
| T15.S2 | Reconciliation against the latest store state, preserving concurrent edits and authorized alias-migration decisions. | Fixtures cover edits while probes are pending, dictionary-only authorized alias migration, retained unknown legacy locations, and reconciliation applied to the latest state. Native storage and native alias/canonical identity acquisition remain unchanged. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T15`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T15`: origin `T15`; recipient `T16`. Deliver completeness/reconciliation/concurrent-edit/authorized-alias fixtures. Close when T16 integration tests confirm them with the existing native persistence backend.

### Acceptance

Both slices pass and preserve unknown availability and latest-store edits. The core emits decisions; native code still owns persistence, alias authorization, and grants. Record the applicable review.

### Handoff

Provide accepted reconciliation rules and obligation cases to `T16.S2`.

## T16 — Native project integration

### Goal

Use core project rules in the macOS app while preserving access, navigation, and stored favorites.

### Prerequisites

Accepted `T13`, `T14`, and `T15`.

### Inputs

Read [tree/scanner owner](../../../Marky/FileNode.swift), [view model](../../../Marky/ViewModels/ContentViewModel.swift), [favorites store](../../../Marky/Services/ProjectFavoritesStore.swift), and [project regression tests](../../../MarkyTests/MarkyTests.swift). Read [session/grant owner](../../../Marky/Services/ProjectSessionService.swift), [outline tests](../../../MarkyTests/FilesOutlineTests.swift), [UI tests](../../../MarkyUITests/MarkyUITests.swift), and [signed sandbox acceptance](../../CODE_QUALITY_VERIFICATION.md). Apply [project rules](../CONTRACT.md#project-rules), [boundary and lifetime](../CONTRACT.md#boundary-and-lifetime), and [verification and performance](../CONTRACT.md#verification-and-performance).

### Slices

| ID | Output | Verification and exit |
| --- | --- | --- |
| T16.S1 | Native enumeration adapter supplying core metadata and identities, with balanced grants and failed-open preservation. | Project regressions cover packages/special files/symlinks, unreadable children, unavailable bookmarks, explicit-open precedence, cancellation/latest requests, active-project preservation, and balanced scope release. |
| T16.S2 | Core index/search/favorites integration using existing persistence and single-file fallback. | Regressions cover native matching/order, favorites path filtering, partial fallback, concurrent edits, unknown availability, and authorized alias migration; incoming T13/T14/T15 obligations have native evidence. |
| T16.S3 | Native UI acceptance and exact signed, sandbox-enabled candidate. | Relevant unit/UI tests pass; inspect large folders, selection/expansion, search/favorites, keyboard/focus, failures, cancellation, reopen/restoration, and single-file fallback. Provide exact candidate/manual steps and obtain user PASS. |

### Blockers

Read [STATUS](../STATUS.md), filtering blocker and obligation records whose affected or receiving tickets include `T16`. Resolve any applicable prerequisite blocker before starting its affected slice; record new evidence there.

### Owes

`OWE-T16`: origin `T16`; recipients `T17`, `T19`. Supply accepted native integration, large-tree/favorite stress inputs, and sandbox acceptance cases. Close when T17 resource/performance evidence and T19 final native signed-candidate evidence cover them.

### Acceptance

All slices pass with existing persistence and native grants intact; user reports PASS for the exact signed candidate. Record incoming obligation closure evidence in STATUS.

### Handoff

Provide T16 evidence and fixed large-project inputs to `T17.S1` after T12 acceptance, and preserve the native acceptance checklist for `T19.S2`.

## Phase exit

`T13`–`T16` have accepted completion and the exact signed macOS integration candidate has user PASS. Complete/partial/unknown handling, failed-open preservation, grants, concurrent favorite edits, and single-file fallback have evidence. T13/T14/T15 obligations close through T16 evidence; T16 obligations continue to T17/T19.
