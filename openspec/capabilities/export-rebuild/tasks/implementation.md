# Tasks — Export & Rebuild

> Implemented — see `agent_wiki/lib/data/wiki_repository.dart` + Settings UI.

- [x] exportWiki(dest) — regenerate full tree (pages/sources(+history)/claims/wiki.yaml + EXPORT.md).
- [x] rebuildIndex() — drop/recreate from canonical.
- [ ] Auto-rebuild on schema mismatch at startup (not implemented — `_meta.schema_version` recorded only).
- [x] TEST-006, TEST-007 coverage.
