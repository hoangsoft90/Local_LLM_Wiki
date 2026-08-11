# AgentWiki — Patterns & Conventions

> Cập nhật: 2026-08-09. Những pattern lặp lại trong codebase + bẫy đã gặp (đừng lặp lại).

## 1. Conventions chung

- **ID**: UUIDv4 (`util.newId()`). Tên file page: `<slug>-<id8>.md`.
- **Timestamp**: ISO-8601 UTC (`util.nowIso()`).
- **Enums**: class enum có `wire` (snake_case, dùng để lưu file/DB) + `label` (UI);
  parse bằng `Xxx.fromWire()` với fallback an toàn.
- **Wire names** cố định theo `openspec/project.md §3` — KHÔNG đổi, vì nằm trong
  canonical files và DB đã đóng băng.

## 2. Canonical-first reads

```dart
// Đọc file canonical trước; DB chỉ fallback (D1).
PageRecord? getPage(String id) {
  for (final f in store.pagesDir.listSync().whereType<File>()) {
    if (parseFrontmatter(f.readAsStringSync()).frontmatter['page_id'] == id) {
      return store.readPage(id, p.basename(f.path));
    }
  }
  return index.getPage(id);
}
```
> Lý do: người/agent có thể sửa `pages/*.md` bằng tay ("iterate on the same
> files") — DB là index derived, đọc phải ưu tiên canonical, không thì bỏ sót.

## 3. Frontmatter round-trip lossless

- `parseFrontmatter(md)` → `{frontmatter, body}`; `renderFrontmatter(fm, body)` tái dựng.
- Body được `.trim()` khi parse để round-trip ổn định cho hashing (TEST-006).
- Khóa lạ trong frontmatter được giữ nguyên.

## 4. Patch op pattern

```dart
final op = PatchOp.addClaim(pageId: ..., statement: ..., evidence: [...]);
final revision = repo.applyOp(op, actor: Author.agent); // human cho Flow B accept
```
- Validate toàn bộ TRƯỚC khi ghi (unknown op / missing field → `PatchException`, không ghi gì).
- Ghi canonical → sync index → `insertRevision(target_type, target_id, patchJson)`.
- Evidence quote phải là **substring verbatim** của source content (kiểm tra trong engine).

## 5. LLM provider pattern

```dart
abstract class LlmProvider {
  Future<String> generate({required String system, required String user, String? model});
  Future<Map<String, dynamic>> structured({required String system, required String user, String? model});
}
```
- App chỉ nói chuyện qua interface; `SettingsService.providerFor(apiKey)` chọn
  OpenRouter / Demo. Test dùng `MockLlmProvider` + `routeMock()` (routing theo `PROMPT_TYPE` marker).
- **Đừng** gọi provider trực tiếp trong UI — đi qua service (compile/ask/promote) để log `.ai/runs`.

## 6. FTS5 — bẫy đã gặp (QUAN TRỌNG)

- `snippet()` và `bm25()` là **hàm top-level, KHÔNG được viết `f.snippet(...)`** khi table bị alias:
  ```sql
  SELECT f.page_id, snippet(pages_fts, 2, '<b>', '</b>', '…', 12) AS snip ...
  FROM pages_fts f JOIN pages p ON p.id = f.page_id
  WHERE pages_fts MATCH ? ORDER BY bm25(pages_fts) LIMIT ?
  ```
  (`snippet` column index: 0=page_id, 1=title, **2=content**.)
- Prefix query: `"tok"*`; dùng **OR** join cho recall khi Ask (câu hỏi tự nhiên),
  AND khi cần precision. `util.ftsQuery(raw, requireAll: false)`.
- Query lỗi → fallback LIKE (đã có trong `IndexDb.search`).

## 7. Rebuild & Export

- `WikiRepository.rebuild()`: quét canonical files → `IndexDb.rebuild(pages, claims, sources)`
  (close → delete file → reopen → insert). Idempotent, không đụng canonical (TEST-007).
- `exportTo(dest)`: copy pages/sources(+history)/claims + wiki.yaml (TEST-006).

## 8. Status hierarchy → màu UI (đừng đổi lung tung)

| status | màu |
|---|---|
| unverified ⚠ Hypothesis | amber `0xFFB26A00` |
| supported | blue `0xFF1565C0` |
| cross_checked | purple `0xFF6A1B9A` |
| human_verified ✓ | green `0xFF2E7D32` |
| contradicted | red `0xFFC62828` |
| deprecated | grey `0xFF616161` (strike-through) |

## 9. Test conventions

- File: `test/*_test.dart` — **LƯU Ý**: `flutter test` mặc định chỉ chạy file khớp
  `*_test.dart` (số nhiều `acceptance_tests.dart` sẽ KHÔNG chạy — đã dính).
- Acceptance: `test/acceptance_test.dart` — 14 test ánh xạ TEST-001..011 (mỗi TEST có thể nhiều test).
- Setup: `tempRepo()` (temp dir) + `FileKeyStore` (tránh platform channel) + `routeMock()`.
- Patch engine test dùng `repo` dynamic (`late dynamic repo`).

## 10. Đã đúc kết (pít-fall build/environment)

- **AGP 9 + Gradle 9.1 không tương thích** với một số plugin pub cũ (file_picker cũ, DSL `implementation`).
  Project đang dùng **AGP 8.9.1 + Gradle 8.14.3 + Kotlin 2.2.20** (android/).
- **file_picker 3.x** là bản 2021, không có `namespace` → fail AGP 8+. Đang dùng `^10.0.0`.
- **flutter_secure_storage 11** xung đột win32 với file_picker 10 → dùng `^10.0.0`.
- **ENOSPC**: máy user gần đầy đĩa → `.pub-cache` bị hỏng → chạy `flutter pub get` lại.
- **sqlite3 3.x (native assets) không chạy trên Android thật** (`sqlite3_initialize` unresolved) → pin `sqlite3 2.9.4` + `sqlite3_flutter_libs 0.5.42` (bundle kiểu cũ, FTS5 OK); `IndexDb.close()` gọi `db.dispose()`.
- **AdMob**: Android đã production — App ID `ca-app-pub-6917313063209470~4401678345` (AndroidManifest) + banner `ca-app-pub-6917313063209470/1911246375` (`lib/ads/ad_config.dart`, `useTestAds=false`). iOS chưa có ad unit → vẫn test. Interstitial/rewarded IDs đã lưu config nhưng chưa có code dùng. KHÔNG đặt banner trên Ask screen (policy LLM content).
- minSdk Android = 23 (yêu cầu flutter_secure_storage).
