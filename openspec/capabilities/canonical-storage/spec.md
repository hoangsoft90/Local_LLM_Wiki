# Capability: Canonical Storage

## Overview

AgentWiki stores all knowledge as human-readable, git-friendly files (Markdown + JSON). A SQLite database with FTS5 is maintained **derived** from those files and can be destroyed and rebuilt at any time without data loss.

## Requirements

- **REQ-1** Canonical layout under `<app-documents>/agentwiki/`:
- `wiki.yaml` — wiki metadata (name, created_at) + settings (primary/corroboration models).
- `pages/<filename>.md` — page body + YAML frontmatter with `page_id`, `title`, `page_type`, `claim_ids[]`, `created_at`, `updated_at`, `status` (optional, `active|deprecated`).
- `sources/<source_id>.md` — immutable source content + frontmatter.
- `claims/claim_<id>.json` — canonical claim record (JSON).
- `inbox/draft_<id>.json` — Flow B draft bundles (`pending | accepted | rejected`).
- `settings.json` — non-canonical app settings; API-key fallback (`key_*`) only.
- `.agentwiki/index.sqlite` — derived index.
- `.ai/runs/<run_id>.json` — AI run log.
- **REQ-2** Frontmatter is parsed and written losslessly for the fields the app owns; unknown frontmatter keys are preserved.
- **REQ-3** SQLite schema is frozen per project.md §3 (tables `wikis, sources, pages, claims, evidence, links, revisions, pages_fts`).
- **REQ-4** `pages_fts` is a standalone FTS5 table (not external-content) storing `page_id, title, content, summary`; kept in sync transactionally on writes.
- **REQ-5** A `rebuildIndex()` operation drops and recreates all derived SQLite tables from canonical files (TEST-007).

## Behavior

- Reads prefer SQLite for search/query speed; writes always go through canonical files first, then update the derived index (sequential steps — not wrapped in a DB transaction).
- Canonical file is the source of truth in any conflict.
- Rebuild must be idempotent and produce identical search results (TEST-007).
