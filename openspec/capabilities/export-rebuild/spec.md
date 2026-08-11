# Capability: Export & Rebuild

## Overview

Everything the wiki knows lives in canonical files. Export makes that explicit (regenerate a clean wiki tree), and rebuild proves the SQLite index is fully derived.

## Requirements

- **REQ-1** `exportWiki(destDir)`: copies canonical state into a target directory — `wiki.yaml`, `pages/*.md`, `sources/*.md` (+ `sources/history/`), `claims/*.json`, plus an `EXPORT.md` manifest — producing a complete standalone wiki. **The destination directory is deleted and recreated if it already exists.**
- **REQ-2** TEST-006: export → the exported Markdown/JSON reconstructs the entire wiki (pages, claims, evidence, sources all present, content-hash identical).
- **REQ-3** `rebuildIndex()`: drop `index.sqlite`, recreate schema, re-read all canonical files, repopulate tables + FTS. Idempotent (TEST-007).
- **REQ-4** Rebuild never touches canonical files.

## Behavior

- Export + Rebuild buttons in Settings. The schema version is recorded in `_meta.schema_version`; auto-rebuild on version mismatch is not implemented yet.
