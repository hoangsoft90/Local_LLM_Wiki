# Tests — Phase 1: AI Loop

> Covered by `agent_wiki/test/acceptance_test.dart` — 28/28 pass.

- [x] TEST-002: compile source (mock LLM) → page created, ≥1 claim with status ≤ supported, every claim has evidence, inbox empty.
- [x] TEST-003: ask question → answer cites correct page/source/version; fabricated citation ids are dropped.
- [x] TEST-004: save answer (Flow B) → page updated via PATCH; old content preserved; new claim stays `supported` (never auto `human_verified`); inbox entry accepted.
- [x] TEST-011: source containing "ignore previous instructions…" → compiled claim unaffected; parser strips injected content.
- [x] Ask with empty wiki → no-knowledge answer without any LLM call.
- [ ] Inbox reject → no page changes; draft marked rejected (no automated test yet).
