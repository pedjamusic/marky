# Phase 0 — Establish the durable roadmap

Read [STATUS](../STATUS.md), the [contract](../CONTRACT.md), and [completion rules](../README.md#completion-and-acceptance). Slice inheritance and status conventions are defined in the entry point.

## T00 — Planning package

**Goal:** a persistent plan that a new session can resume without the originating chat.

**Prerequisites:** editing enabled; explicit authorization for the required local branch/worktree before applying the package in the repository. A temporary review draft can be prepared independently.

**Inputs:** [repository policy](../../../AGENTS.md), [repository README](../../../README.md), [portability assessment](../../AGENT_POLICY_AND_PORTABILITY.md), [scope and dependencies](../CONTRACT.md#scope-and-dependencies), and the user's approved 8-phase/20-ticket/51-slice roadmap as embodied in these definitions.

**Slices:**

| Slice | Output | Verification and exit |
| --- | --- | --- |
| T00.S1 | CONTRACT.md and all eight static phase definitions, preserving approved IDs and scope. | Every ticket contains the required fields; all 20 tickets/51 slices are accounted for with checkable exits and acyclic prerequisites. |
| T00.S2 | STATUS.md with live slice state, blockers/owes/evidence/authorization ledgers; README and AGENTS discovery links. | A fresh session can find its current work and next action; relative links resolve and planned work is distinguished from completed work. |
| T00.S3 | Checked package and a focused documentation diff for user review. | Validate coverage, prerequisites, incoming/outgoing owes, links, whitespace, and documentation-only scope; present the diff and obtain user acceptance. |

**Blockers:** consult the live B01/B02 entries in STATUS. Editing-mode and branch authorization are distinct conditions. Do not carry the historical Plan-mode blocker forward after it is resolved.

**Owes:** `OWE-T00` → T01: executable characterization of current behavior. Close with T01's reviewed coverage map and compatibility corpus; drafting a roadmap is not implementation evidence.

**Acceptance:** user review of the documentation diff. No app build/runtime claims and no version bump. Separate Git permission is required for commit/merge/push.

**Handoff:** record whether the draft is staged or applied, its exact location, checks, and pending review in STATUS. Next action is T01.S1 only after T00 acceptance and a subsequent core-work instruction; this task stops after the documentation delivery.

## Phase exit

T00 is accepted, discovery links work, and the status checkpoint names an unambiguous starting point. No C++ implementation is claimed.
