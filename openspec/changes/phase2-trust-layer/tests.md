# Tests — Phase 2: Trust Layer

> Covered by `agent_wiki/test/acceptance_test.dart` — 28/28 pass.

- [x] TEST-009: revision rows exist for both page and claim mutations with correct `target_type`.
- [x] TEST-010: Ask never triggers cross-model; only Flow B promote/status-upgrade does (verified via ai_runs op log).
- [x] TEST-011: injection regression still passes.
- [x] Status transition: agent request to set `human_verified` directly → rejected by patch engine.
- [x] Corroboration: promote with secondary model agreeing → `cross_checked`; disagreeing → `needs_review` (+ force-accept human override).
- [ ] Staleness: source v2 imported while claim evidence points to v1 → UI shows warning (no automated test yet).
- [ ] `.ai/runs` JSON present for every AI op with required fields (partial: TEST-010 asserts op names only).
