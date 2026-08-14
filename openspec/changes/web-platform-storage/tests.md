# Tests — Web Platform Storage

> Runs on VM (no browser needed) via injectable `Map<String,String>` storage.

- [ ] `LocalStorageFileSystem`: write/read/list (non-recursive + recursive)/delete/exists round-trip.
- [ ] `WikiRepository` over web stack (open with `rootDir` + `LocalStorageFileSystem`):
  - import source → canonical file + index source present;
  - apply `create_page`/`add_claim` via patch engine → page searchable via
    `repo.search` (search contract identical to SQLite path);
  - save draft → listDrafts shows it;
  - accept draft (actor human) → page updated + revision recorded;
  - `rebuild()` → index rebuilt from canonical, search still returns the page.
- [ ] Existing io tests unchanged: `flutter test` 28/28 pass.
- [ ] `flutter analyze` — no issues.
- [ ] `flutter build web` — compiles (web graph excludes sqlite3 + google_mobile_ads).
