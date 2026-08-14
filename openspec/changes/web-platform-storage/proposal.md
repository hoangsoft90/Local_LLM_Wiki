# Change: Web Platform — Storage split (SQLite mobile / localStorage web)

## Motivation

AgentWiki is mobile-first (iOS + Android) but the storage layer is hard-wired to
`dart:io` + native SQLite, which cannot compile or run on Flutter web. Add a web
target where the **interface and business logic stay identical** (canonical
markdown/JSON store + derived index + patch engine + all services/UI), while the
storage backend switches per platform:

- iOS / Android: keep SQLite (`IndexDb`, pinned `sqlite3 2.9.4`) + real filesystem.
- Web: localStorage-backed virtual filesystem + in-memory derived index rebuilt
  from canonical files (no SQLite, no FTS5).

## Design

- **`FileSystem` abstraction** (`lib/data/fs/`): synchronous path-based ops
  (`exists`, `createDir`, `listFiles`, `readAsString`, `writeAsString`,
  `delete`, `deleteRecursive`). Implementations: `IoFileSystem` (dart:io) and
  `LocalStorageFileSystem` (pure Dart over a `Map<String,String>` — bound to
  `window.localStorage` on web, injectable in VM tests). Selected by a
  conditional-import factory (`fs_factory.dart`).
- **`WikiIndex` abstraction** (`lib/data/wiki_index.dart`): the exact method
  surface `WikiRepository`/`PatchEngine` already call on `IndexDb`.
  Implementations: `IndexDb implements WikiIndex` (SQLite, io-only file) and
  `LocalStorageIndex` (in-memory maps, loaded from canonical files at open,
  same search contract with lightweight token scoring). Selected by
  `index_factory.dart` conditional import — `database.dart` (sqlite3) is
  excluded from the web compile graph.
- **`WikiStore`** becomes backend-agnostic (takes a `FileSystem`); all
  `File`/`Directory` usage removed. `WikiRepository` loses `dart:io` entirely
  (reads, rebuild, export all go through `FileSystem`; root resolved by
  `kIsWeb`).
- **Non-storage platform gaps closed with conditional stubs**:
  - `google_mobile_ads` has no web support → `AdService`/`AdBanner` become
    conditional exports; web stub returns no ad (banner hidden, app unaffected).
  - `ImportService`: `importFromPath` (io) + `importFromText` (bytes from
    `file_picker` on web).
  - `flutter_secure_storage` has an endorsed web impl (already transitive).
  - `path_provider` guarded by `kIsWeb` (not called on web).
  - Export uses `getDirectoryPath` which web doesn't support → settings screen
    shows a snackbar on web instead.
- **Derived-index parity note:** links/revisions are already ephemeral in SQLite
  (`rebuild()` drops them); the web index mirrors that (in-memory only, rebuilt
  from canonical at open) so behavior is consistent across platforms.

## Impact

- New files: `lib/data/fs/*`, `lib/data/wiki_index.dart`,
  `lib/data/index_factory.dart`, `lib/data/index_io.dart`,
  `lib/data/index_web.dart`, `lib/domain/file_reader*`, web ad stubs,
  `agent_wiki/web/` (platform scaffold), `test/web_storage_test.dart`.
- Modified: `wiki_store.dart`, `wiki_repository.dart`, `database.dart`,
  `import_service.dart`, `ads/*`, `ui/widgets/ad_banner.dart`,
  `ui/screens/{sources,home,settings}_screen.dart`, `pubspec.yaml`,
  `.github/workflows/build-apk.yml` (add web build job).
- No change to canonical file format, patch ops, prompts, or business logic.

## Acceptance

- `flutter analyze` clean; existing 28 tests still pass (io path unchanged).
- `flutter build web` compiles (web graph excludes sqlite3/google_mobile_ads).
- New `test/web_storage_test.dart` (runs on VM): the full repository stack
  (import → compile → ask/search → draft → accept → rebuild) works over
  `LocalStorageFileSystem` + `LocalStorageIndex`.
