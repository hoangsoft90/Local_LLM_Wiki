# Tasks — Phase 0: Engine

- [x] Scaffold Flutter app (`agent_wiki`, platforms android,ios) with deps: sqlite3, sqlite3_flutter_libs, path_provider, path, yaml, markdown, flutter_markdown, uuid, crypto, file_picker, provider, flutter_secure_storage.
- [x] Core models: Wiki, Source, Page, Claim, Evidence, Link, Revision, PatchOp, enums (page_type, claim_status, author).
- [x] `WikiStore` — canonical file layout create/read/write (frontmatter lossless), claim JSON, wiki.yaml.
- [x] `Database` — SQLite schema (wikis, sources, pages, claims, evidence, links, revisions, pages_fts), open at `.agentwiki/index.sqlite`, migrations via schema_version.
- [x] FTS5 sync in writes + `rebuildIndex()` from canonical files.
- [x] Patch engine: 8 ops with validation, page templates per page_type, frontmatter claim_ids maintenance, revisions logging (page+claim).
- [x] Search service: BM25 query + snippet.
- [x] Export service: regenerate complete wiki tree; verify content hashes.
- [x] Deprecation: delete-page → `status: deprecated` frontmatter (page stays on disk).
- [x] Settings service: wiki path, model config, secure API key storage.
- [x] Unit tests: patch ops, frontmatter round-trip, rebuild idempotency, export completeness.
