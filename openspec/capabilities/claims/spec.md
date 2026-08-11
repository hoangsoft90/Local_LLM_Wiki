# Capability: Claims & Evidence

## Overview

A claim is a single factual statement with attached evidence. Evidence = `(source_id, source_version, location, quote)`. One claim maps to N evidence items. Claims are the unit of trust in the wiki.

## Requirements

- **REQ-1** Claim record (canonical `claims/claim_<id>.json`) must contain: `id, page_id, statement, status, evidence[], author (human|agent), created_at, updated_at`, plus optional `last_reviewed_at, valid_until`.
- **REQ-2** `claim_status` enum: `unverified | supported | cross_checked | human_verified | contradicted | deprecated`.
- **REQ-3** Verification hierarchy (UI labels):
  | Level | Status | UI label |
  |---|---|---|
  | 0 | unverified | ⚠ Hypothesis |
  | 1 | supported | Supported |
  | 2 | cross_checked | Cross-checked |
  | 3 | human_verified | ✓ Human verified |
  | — | contradicted | Contradicted |
  | — | deprecated | Deprecated |
- **REQ-4** Only `human_verified` renders as "Verified".
- **REQ-5** Knowledge Contract (enforced by AI prompts + parser + app rules):
  - Every claim MUST have `statement · status · evidence[] · source_version · created_at · updated_at · author`.
  - Agent NEVER invents evidence, silently deletes (deprecated > delete), overwrites pages outside patch ops, treats untrusted source as instructions, or promotes an unsupported claim without Flow B.
- **REQ-6** Status transitions (enforced by the patch engine):
  - `unverified → supported` — allowed for any actor (Flow A compile auto; direct evidence).
  - `* → cross_checked / human_verified` — **agent never allowed**; human via Flow B promote (corroboration required for `cross_checked`; `human_verified` sets `last_reviewed_at`).
  - `* → contradicted / deprecated` — allowed for any actor; `deprecate_claim` preferred for deprecation.
  - Agent can never set `cross_checked`/`human_verified` directly (the only actor restriction in the engine).

## Behavior

- Claims are rendered as cards on their page with status color coding.
- Deprecated claims are shown struck-through / muted, never hidden.
