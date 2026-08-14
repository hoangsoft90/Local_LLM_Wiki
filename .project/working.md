# AgentWiki — Working log

> Nhật ký chi tiết (KI). **Nguồn chính khi session start: `../working.md`** (root) — được đọc tự động theo AGENTS.md. File này giữ log chi tiết; giữ đồng bộ với root khi cập nhật.
> Format ngày: `YYYY-MM-DD` (ISO). Dọn mục cũ >1–2 tuần.

## 2026-08-14

- [x] Push + build APK trên GH Actions (không build local): commit `0c9ee72` (docs) + `c737832`
      (HTTP fix) → CI `Build APK` success, artifact `agentwiki-apk` ~29MB.
- [x] Fix release HTTP: `usesCleartextTraffic="true"` + `INTERNET` permission trong main
      `AndroidManifest.xml` (trước đó INTERNET chỉ ở debug/profile).
- [x] Web platform storage split (`openspec/changes/web-platform-storage`): `FileSystem`
      abstraction (io/localStorage, conditional factory) + `WikiIndex` (IndexDb implements;
      `LocalStorageIndex` in-memory rebuild từ canonical). `WikiStore`/`WikiRepository` bỏ hết
      `dart:io`. Web stubs: ads (google_mobile_ads không hỗ trợ web), import bytes, export guard.
      Thêm web platform + `web ^1.1.0` + CI job build-web. Verify: analyze sạch · 34/34 test
      (thêm `web_storage_test.dart` VM) · `flutter build web` OK.
- [x] In-app Guidance & Onboarding (`openspec/changes/in-app-guidance`): module `lib/ui/guidance/`
      (FeatureBadge · SpotlightOverlay · DisabledStateHelper · GuidanceController + shared_preferences),
      tích hợp first-run tour Home (Ask→Import→Inbox), badge New Inbox, disabled-helper nút Ask.
      Verify: analyze sạch · 44/44 test (thêm `guidance_test.dart`) · build web OK.
- [x] Code review toàn diện: fix FeatureBadge "New" chưa render (wire Inbox tab), SpotlightOverlay
      kẹt khi target null (fallback visible tooltip), bỏ nền hồng DEBUG sau banner, guard export iOS.
- [x] AdMob monetization (`openspec/changes/ads-monetization`): flag `testAds=true` (mọi ad unit →
      test ID Google cả 2 platform khi dev); interstitial + `AdCooldown` (2 phút, trigger đổi tab,
      không lúc khởi động); UMP consent (io, web stub) gating banner+interstitial; `SafeArea`
      SearchScreen chống 3-button nav che; `NSUserTrackingUsageDescription` iOS. Verify: analyze
      sạch · 48/48 test (thêm `ad_cooldown_test.dart`) · build web OK.
- [x] Navigation audit + safe-back + deep-link: rà toàn bộ nav (5 tabs + push routes + dialogs) —
      không điểm chết. Fix: `onGenerateRoute` cho deep-link `#/page/<id>` + fallback mọi route lạ
      (trước: crash "no route generator"); `DeepLinkPage` gate init (chống LateInitializationError
      khi deep link là initial route); PageScreen not-found root → nút Home; `PopScope` back hệ
      thống trong tour → skip tour; dọn warning web (wasm dry-run `sqlite3`/ffi →
      `--no-wasm-dry-run`). Verify: analyze sạch · 52/52 test (thêm `navigation_test.dart`) ·
      build web 0 warning.

## 2026-08-11

- [x] Setup AdMob production (Android): App ID `ca-app-pub-6917313063209470~4401678345` + banner `ca-app-pub-6917313063209470/1911246375` (`useTestAds=false`); iOS giữ test; interstitial/rewarded ID lưu config chưa dùng.

## 2026-08-09

- [x] Chốt quyết định với user: mobile-first (iOS+Android), scope Phase 0–2 đầy đủ, OpenRouter BYOK.
- [x] Viết OpenSpec đầy đủ: `openspec/project.md` + 11 capabilities + 3 changes (phase0-engine, phase1-ai-loop, phase2-trust-layer) — proposal/tasks/tests.
- [x] Scaffold `agent_wiki/` (Flutter 3.44, android+ios), cài deps.
- [x] Core models + canonical storage (`WikiStore`) + `IndexDb` (SQLite+FTS5, rebuild) + `WikiRepository` (canonical-first).
- [x] Semantic Patch Engine: 8 ops, template headings/page_type, revisions page+claim, chặn agent set cross_checked/human_verified.
- [x] AI layer: `LlmProvider` interface, OpenRouter, Mock, Demo (offline), prompts (PROMPT_TYPE markers), output parser chống injection.
- [x] Services: Import, Compile (Luồng A), Ask + citations, Promote/Inbox (Luồng B + cross-model), Export, Settings.
- [x] UI mobile: AppShell 5 tabs + Home/Ask/Page/Search/Inbox/Sources/Settings + status badges/claim cards.
- [x] Tests: 28 pass — frontmatter, patch engine, widget smoke, acceptance TEST-001..011.
- [x] Sửa lỗi review (code-reviewer): getPage canonical-first, quote verbatim ở engine, corroboration chỉ khi upgrade trust, bỏ dead code, dùng yaml package cho wiki.yaml.
- [x] Fix build env: AGP 9.1/Gradle 9.1 → AGP 8.9.1/Gradle 8.14.3/Kotlin 2.2.20; file_picker 3.0.4 → 10.3.10; flutter_secure_storage 11 → 10.3.1; minSdk 23.
- [x] Xử lý ENOSPC (đĩa đầy) → `flutter pub get` lại; build APK debug thành công.
- [x] Cập nhật `.project/` Knowledge Items (README/overview/architecture/patterns/state/ai-rules/modules) + working.md.
- [x] **Test trên Android thật**: `adb -s 192.168.0.101:33929` (Samsung Galaxy A04) — install debug APK OK, launch OK, UI render (screenshot `/tmp/agentwiki_home.png`), logcat không lỗi.
- [x] Fix lỗi device `LateInitializationError: Field 'repo' has not been initialized` — nguyên nhân: UI render trước khi `AppState.init()` (async) xong. Fix: thêm gate `AppHome` (splash cho tới khi `initialized`, màn hình lỗi + nút Thử lại nếu init fail) trong `app.dart`; `init()` chống chạy lại + `retryInit()`. Verify lại trên device: chạy OK, logcat sạch.
- [x] Fix lỗi device `Couldn't resolve native function 'sqlite3_initialize'` — nguyên nhân: `sqlite3 3.5.1` dùng native assets (hook build) còn `sqlite3_flutter_libs 0.6.0+eol` là stub rỗng → APK không kèm lib sqlite3. Fix: hạ `sqlite3 2.9.4` + `sqlite3_flutter_libs 0.5.42` (bundle lib kiểu cũ, FTS5 vẫn OK), đổi `close()` → `dispose()` trong `database.dart`, `flutter clean` + build lại. Verify trên device: app chạy (pid 8727), logcat sạch, **bằng chứng storage**: `app_flutter/agentwiki/.agentwiki/index.sqlite` (+wal/shm) đã được tạo, `wiki.yaml` đúng format → IndexDb mở OK, SQLite native lib hoạt động trên Android thật.
- [x] Tạo 5 skills từ kinh nghiệm 2 phiên (theo writing-great-skills, model-invoked) tại `.agents/skills/`: `flutter-android-build-triage` (blame line + symptom table AGP/Gradle/sqlite3/ENOSPC), `flutter-device-smoke-test` (evidence line, adb loop, run-as quoting trap), `flutter-startup-gate` (init gate chống LateInitializationError — tên gốc `flutter-async-init-gate` bị skill index chặn, đổi tên là load được), `flutter-test-discovery` (`*_test.dart` naming trap), `sqlite-fts5-queries` (snippet/bm25 top-level + probe-first).

## Việc tiếp theo

- [ ] Commit lần đầu (repo chưa có commit nào).
- [ ] Chạy thử trên simulator/device (iOS + Android) với OpenRouter key thật.
- [ ] Kiểm tra iOS build.
- [ ] Dogfood ≥5–7 ngày → Gate (§6 spec).
- [ ] Backlog B1–B9.
