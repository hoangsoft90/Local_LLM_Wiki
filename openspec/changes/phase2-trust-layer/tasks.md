# Tasks — Phase 2: Trust Layer

- [x] Patch engine: enforce full status transition matrix; reject agent-set `cross_checked`/`human_verified`.
- [x] Cross-model corroboration service (secondary model, Flow B triggers only — status upgrades to cross_checked/human_verified or ≥2-source merges).
- [x] Corroboration failure → `needs_review` flag on draft bundle (+ force-accept human override).
- [x] Settings: primary + corroboration model pickers; persist both.
- [x] Source staleness detection + `⚠ evidence source changed` UI.
- [x] Complete `.ai/runs` logging (op, model, prompt_version, ids, ts).
- [x] Inbox UI: show corroboration note + audit trail (revisions) per bundle.
- [x] Tests: TEST-009, TEST-010 (ask never re-verifies), TEST-011 (regression), status-transition rejection.
