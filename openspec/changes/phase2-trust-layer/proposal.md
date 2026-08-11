# Change: Phase 2 — Trust Layer

## Motivation

Phase 1 proves the loop; Phase 2 makes the knowledge trustworthy enough to be reused by agents as "truth": full claim status lifecycle, cross-model corroboration (Flow B only), revisions for page+claim, BYOK multi-provider with separate corroboration model, and complete source hashing with staleness flags.

## Design

- Enforce full status transition rules (claims spec REQ-6) in the patch engine; agent can never set `cross_checked`/`human_verified` directly.
- Cross-model corroboration service: on Flow B status-upgrade or ≥2-source answer merge, query the secondary model; corroboration required before promote; failures flagged `needs_review`. Ask never triggers it (TEST-010).
- Revisions already cover page+claim (Phase 0); verify + extend UI-visible audit trail.
- BYOK multi-provider settings: primary + corroboration model selection.
- Source staleness: evidence `source_version < latest` → `⚠ evidence source changed` computed at render.
- `.ai/runs` logging complete (op, model, prompt_version, input_ids, output_ids, ts).

## Impact

- Extends `patch-engine`, `ai-provider`, `promote`, `claims`, `mobile-ui`.
- Depends on Phase 1.

## Acceptance

- TEST-009 (audit for both target types), TEST-010, TEST-011, TEST-004 (status never auto-verified).
