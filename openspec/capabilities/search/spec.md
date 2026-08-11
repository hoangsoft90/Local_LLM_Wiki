# Capability: Search

## Overview

Full-text search over the derived FTS5 index with BM25 ranking, exposing new knowledge instantly (TEST-005) and remaining stable across index rebuilds (TEST-007).

## Requirements

- **REQ-1** Query runs against `pages_fts` (`page_id, title, content, summary`) using `pages_fts MATCH ?` with BM25 ordering, prefix-starred tokens.
- **REQ-2** Results return page id, title, snippet (highlighted match), page_type, and a `deprecated` flag.
- **REQ-3** TEST-005: knowledge added via compile/save is searchable immediately.
- **REQ-4** TEST-007: after deleting `.agentwiki/index.sqlite` and running rebuild, search returns identical results.
- **REQ-5** Deprecated pages still searchable; the result carries a `deprecated` flag and the title is struck through in the UI.

## Behavior

- Search screen: query field + result list; tapping opens page detail.
