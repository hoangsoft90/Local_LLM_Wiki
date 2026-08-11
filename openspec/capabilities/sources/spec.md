# Capability: Sources

## Overview

Sources are immutable, versioned documents ingested into the wiki. Every claim's evidence references a source at a specific version.

## Requirements

- **REQ-1** Import accepts a markdown/text file (via file picker) and records: `id, title, url, content, content_hash, version, imported_at` (`wiki_id` is an internal DB column; `metadata` is reserved but not populated).
- **REQ-2** `content_hash` = SHA-256 hex of the content.
- **REQ-3** Re-importing identical content is a no-op (same hash, same version).
- **REQ-4** Re-importing changed content creates a **new version** (`version++`) of the same source; old content is not overwritten.
- **REQ-5** Source canonical file: `sources/<source_id>.md` with YAML frontmatter (`id, title, url, content_hash, version, imported_at`) + raw content.
- **REQ-6** Evidence referencing a source version older than the latest is flagged `⚠ evidence source changed` in the UI (computed at render time).
- **REQ-7** TEST-001: import → source record + content_hash present.

## Behavior

- Import is the entry point of Flow A (compile).
- Sources are never edited in place; a change is always a new version.
