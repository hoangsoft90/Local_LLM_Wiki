# Tasks — Web Platform Storage

- [ ] `FileSystem` interface + `IoFileSystem` (dart:io) + `LocalStorageFileSystem` (pure Map-backed) + `fs_web.dart` (window.localStorage) + conditional `fs_factory.dart`.
- [ ] `WikiIndex` interface; `IndexDb implements WikiIndex`; `LocalStorageIndex` (in-memory, load canonical at open, token-scored search); conditional `index_factory.dart`.
- [ ] `WikiStore` → fs-backed (no `dart:io`); add `listPageFiles`/`readPageFile`/`listClaimFileNames` helpers.
- [ ] `WikiRepository` → no `dart:io`; platform-aware `open()` (kIsWeb root), export via `FileSystem`, rebuild via store helpers.
- [ ] `ImportService` web-safe: `importFromText` + conditional file reader for `importFromPath`.
- [ ] `AdService`/`AdBanner` conditional exports; web stub returns no banner.
- [ ] UI: `sources_screen`/`home_screen` import via bytes on web; `settings_screen` guards export on web.
- [ ] Add web platform scaffold + declare `web` dependency.
- [ ] `test/web_storage_test.dart`: full repo stack over localStorage backend (import → compile → search → draft → accept → rebuild).
- [ ] CI: add `flutter build web` job to `build-apk.yml`.
- [ ] Verify: `flutter analyze` + `flutter test` + `flutter build web`.
