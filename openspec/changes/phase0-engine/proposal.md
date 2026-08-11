# Change: Phase 0 — Engine

## Motivation

Before any AI can iterate, AgentWiki needs the durable knowledge substrate: canonical Markdown/JSON storage, a derived SQLite+FTS5 index, the semantic patch engine, search, and export/rebuild. The schema (project.md §3) must be frozen from this phase so dogfood signal is never interrupted by migrations.

## Design

- Implement canonical storage layout (capability: canonical-storage) with frontmatter-preserving page files, claim JSON, `wiki.yaml`.
- Implement SQLite schema + FTS5 with transactional sync and `rebuildIndex()`.
- Implement the semantic patch engine (8 ops) with fixed page templates and revisions for page+claim.
- Implement search (BM25) and export/rebuild.
- No AI calls in this phase; LLM-dependent flows use the mock provider later.

## Impact

- New capabilities: `canonical-storage`, `sources`, `claims`, `patch-engine`, `search`, `export-rebuild`.
- No existing code (greenfield mobile app).

## Acceptance

- TEST-001, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009 (patch-level), TEST-011 (parser groundwork where applicable).
