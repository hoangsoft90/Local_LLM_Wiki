# Tests — Phase 0: Engine

> Covered by `agent_wiki/test/` (`acceptance_test.dart` + `patch_engine_test.dart`) — 28/28 pass.

- [x] TEST-001: import source file → source record + `content_hash` (SHA-256) present; re-import identical content is a no-op; changed content bumps version.
- [x] TEST-005: after adding a page via patch engine, FTS search finds it.
- [x] TEST-006: export regenerates complete wiki (pages/claims/evidence/sources), hashes match.
- [x] TEST-007: delete `index.sqlite` → rebuild → identical search results.
- [x] TEST-008: delete page → page deprecated in frontmatter, file still on disk.
- [x] TEST-009: every page and claim mutation creates a `revisions` row with correct `target_type`.
- [x] Patch engine validation: unknown op / missing id → rejected, nothing written; invalid enum values fall back via `fromWire` (not rejected).
- [x] Decision page created with all three fixed headings (`## Problem / ## Decision / ## Rationale`).
