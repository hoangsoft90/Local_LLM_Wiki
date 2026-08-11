# Capability: Patch Engine

## Overview

The semantic patch engine is the **only** way pages and claims mutate. The LLM emits patch operations; the app validates and applies them to canonical files, updates the derived index, and records revisions.

## Requirements

- **REQ-1** Supported patch ops:
  - `create_page` — (page_id?, title, page_type, body) — body seeded with fixed template headings.
  - `add_claim` — (page_id, statement, evidence[], hypothesis?) — new claim at `supported` if evidence present else `unverified`; author is the patch `actor` (`human`|`agent`).
  - `add_evidence` — (claim_id, source_id, source_version, location, quote).
  - `link_pages` — (source_page_id, target_page_id, link_type) — link_type ∈ `related | refutes | supports | supersedes`.
  - `update_claim_status` — (claim_id, new_status) — constrained by transition rules (claims spec REQ-6).
  - `deprecate_claim` — (claim_id, reason).
  - `add_decision` — (page_id, problem, decision, rationale) — writes into fixed `## Problem / ## Decision / ## Rationale` sections.
  - `append_section` — (page_id, heading, content) — appends to existing heading or creates at end.
- **REQ-2** Fixed template headings per `page_type` (stable patch targets):
  | page_type | Template headings |
  |---|---|
  | concept | `## Summary`, `## Details` |
  | summary | `## Sources covered`, `## Key points` |
  | decision | `## Problem`, `## Decision`, `## Rationale` |
  | hypothesis | `## Hypothesis`, `## Evidence`, `## Status` |
  | rejected | `## Idea`, `## Why rejected` |
  | note | `## Note` |
- **REQ-3** Applying a patch:
  1. Validate op + payload (reject unknown ops, missing ids, invalid enum values).
  2. Apply to canonical file(s) (markdown body / claim JSON / frontmatter `claim_ids`).
  3. Update SQLite index in the same logical step.
  4. Write a `revisions` row with `target_type ('page'|'claim')`, `target_id`, serialized patch, `created_at`.
- **REQ-4** `create_page` for `decision` must produce a body with all three decision headings pre-created.
- **REQ-5** Patch application is atomic per op: if validation fails, nothing is written.
- **REQ-6** TEST-009: every mutation (page + claim) has a `revisions` row with correct `target_type`.

## Behavior

- Flow A applies patches automatically after compile; Flow B applies only after Accept in the inbox (promote spec).
- `deprecate_claim` is preferred over deletion; `delete` is not a patch op.
- Page deprecation is a repo-level action (`deprecatePage`), not one of the 8 ops: it flips frontmatter `status: deprecated` and records a `{"op":"deprecate_page"}` revision.
