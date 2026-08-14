# AgentWiki — Working log (root)

> Nhật ký ĐANG LÀM — đổi thường xuyên. Format ngày: `YYYY-MM-DD` (ISO).
> Đây là nguồn chính cho session start (đọc tự động theo AGENTS.md).
> Log chi tiết lịch sử: `.project/working.md`.

## 2026-08-14

- [x] **Push code + build APK trên GH Actions** (không build local): repo đã có commit sẵn
      (initial + CI fix), push tiếp `0c9ee72` (docs consolidation) + `c737832` (HTTP fix).
      CI run success, artifact `agentwiki-apk` (~29MB release).
- [x] **Fix release APK HTTP**: `android:usesCleartextTraffic="true"` + `INTERNET` permission
      vào `AndroidManifest.xml` (main) — Android 9+ chặn cleartext mặc định ở release,
      trước đây INTERNET chỉ nằm ở debug/profile manifest.
- [x] **Web platform — storage split (OpenSpec change `web-platform-storage`)**: giữ nguyên
      SQLite (iOS/Android), web dùng localStorage; tách theo platform qua 2 abstraction:
      `FileSystem` (fs_interface/fs_io/local_storage_fs/fs_web/fs_factory — conditional import)
      + `WikiIndex` (wiki_index/index_io/index_web/index_factory; `IndexDb implements WikiIndex`,
      `LocalStorageIndex` in-memory rebuild từ canonical). `WikiStore`/`WikiRepository` hết `dart:io`.
      Web stub: AdService/AdBanner (google_mobile_ads không hỗ trợ web), import qua bytes,
      export bị guard. `flutter create --platforms web`; thêm `web ^1.1.0`; CI thêm job build-web.
      **Verify: analyze sạch · 34/34 test (28 cũ + 6 web_storage_test trên VM) · build web OK**.
- [x] **targetSdk 36** (Google Play yêu cầu từ 31/08/2026): hardcode `compileSdk = 36` +
      `targetSdk = 36` trong `android/app/build.gradle.kts` (không phụ thuộc default Flutter; CI pin 3.44.6).
- [x] **In-app Guidance & Onboarding** (OpenSpec `in-app-guidance`): module `lib/ui/guidance/` —
      `FeatureBadge` (dot/label New, ẩn khi seen), `SpotlightOverlay` (dim + cutout + tooltip auto-position,
      Skip/Next/Done, bước nối tiếp), `DisabledStateHelper` (giải thích lý do disabled + điều kiện unlock khi tap),
      `GuidanceController` (persist `seen.*`/`step.*` qua shared_preferences, chỉ hiện 1 lần, version bump re-show).
      Tích hợp: onboarding first-run 3 bước (Ask→Import→Inbox) trên Home, badge New cho Inbox,
      disabled-helper cho nút Ask. **Verify: analyze sạch · 44/44 test (34 cũ + 10 guidance) · build web OK**.
- [x] **Code review toàn diện (UI/logic/crash)** — fix 4 lỗi: (1) `FeatureBadge` "New" khai báo
      nhưng chưa render ở đâu → wire vào Inbox tab (app_shell); (2) `SpotlightOverlay` kẹt khi
      `globalRectOf` trả null (tooltip vô hình + barrier chặn toàn màn hình, không thoát được)
      → fallback anchor giữa màn hình + re-query target sau khi đo; (3) bỏ nền hồng DEBUG
      `0xFFFFE0E0` sau AdMob banner (hiện ở production khi ad load); (4) guard export Settings
      trên iOS (`getDirectoryPath` không implement → trước đây throw exception không xử lý).
      **Verify: analyze sạch · 44/44 test · build web OK**.
- [x] **AdMob monetization (OpenSpec `ads-monetization`)** — (1) flag `testAds=true` trong
      `ad_config.dart`: mọi ad unit (banner/interstitial/rewarded) dùng test ID Google trên cả 2
      platform khi dev → tránh invalid-traffic; (2) **interstitial + cooldown**: `AdCooldown`
      (pure Dart, clock injectable, có test) + `AdService.loadInterstitial()`/
      `showInterstitialIfAvailable()` (chỉ hiện khi load xong VÀ qua `interstitialMinInterval`
      = 2 phút); trigger khi đổi tab trong AppShell, không bao giờ lúc khởi động; (3) **UMP
      consent**: `ConsentManager` (io = `ConsentInformation`+`ConsentForm`, web = stub), gating
      `AdService.ready` + banner load; `main.dart` kick-off fire-and-forget; thêm
      `NSUserTrackingUsageDescription` (iOS); (4) **chống che khuất bởi 3-button nav**: `SafeArea`
      cho SearchScreen (route full-screen duy nhất thiếu), NavigationBar M3 + AdBanner đã tự xử lý.
      **Verify: analyze sạch · 48/48 test (4 mới: cooldown + config) · build web OK**.

## 2026-08-11

- [x] **Setup AdMob production (Android)**: App ID `ca-app-pub-6917313063209470~4401678345`
      vào `AndroidManifest.xml`; banner thật `ca-app-pub-6917313063209470/1911246375`
      vào `lib/ads/ad_config.dart` (`useTestAds=false`). iOS giữ test ID (chưa có app
      iOS trên AdMob — quyết định của user: banner Android-only).
- [x] Lưu sẵn interstitial (`.../1759771350`) + rewarded (`.../9446689683`) ID vào
      config — chưa có code dùng (user chọn "chỉ lưu ID").

## 2026-08-09

- [x] Chốt với user: mobile-first (iOS+Android), scope Phase 0–2 đầy đủ, OpenRouter BYOK.
- [x] OpenSpec đầy đủ: `openspec/project.md` + 11 capabilities + 3 changes (proposal/tasks/tests).
- [x] Scaffold `agent_wiki/` + deps (sqlite3, yaml, markdown, flutter_markdown, provider, secure_storage…).
- [x] Core models + canonical storage (`WikiStore`) + `IndexDb` (SQLite+FTS5, rebuild) + `WikiRepository` (canonical-first).
- [x] Semantic Patch Engine: 8 ops, template headings/page_type, revisions page+claim, chặn agent set cross_checked/human_verified.
- [x] AI layer: LlmProvider interface, OpenRouter BYOK, Mock/Demo offline, prompts (PROMPT_TYPE markers), parser chống injection.
- [x] Services: Import, Compile (Luồng A), Ask + citations, Promote/Inbox (Luồng B + cross-model), Export, Settings.
- [x] UI mobile: AppShell 5 tabs + Home/Ask/Page/Search/Inbox/Sources/Settings + status badges/claim cards.
- [x] Tests: 28 pass — frontmatter, patch engine, widget smoke, acceptance TEST-001..011.
- [x] Fix review: getPage canonical-first, quote verbatim ở engine, corroboration chỉ khi upgrade trust, bỏ dead code, yaml package cho wiki.yaml.
- [x] Fix build env: AGP 9.1/Gradle 9.1 → AGP 8.9.1/Gradle 8.14.3/Kotlin 2.2.20; file_picker 3.0.4 → 10.3.10; flutter_secure_storage 11 → 10.3.1; minSdk 23.
- [x] Xử lý ENOSPC → `flutter pub get` lại; build APK debug thành công (~154MB).
- [x] Test trên Android thật: `adb -s 192.168.0.101:33929` (Galaxy A04) — install/launch/UI render OK, logcat sạch.
- [x] Fix `LateInitializationError` trên device — gate `AppHome` (splash → shell, error + Retry) trong `app.dart`; init chống double-run.
- [x] Fix `sqlite3_initialize` trên device — hạ `sqlite3 2.9.4` + `sqlite3_flutter_libs 0.5.42` (native assets 3.x + stub +eol fail); `close()`→`dispose()`. Verify: `app_flutter/agentwiki/.agentwiki/index.sqlite` + `wiki.yaml` tạo OK.
- [x] Tạo 5 skills tại `.agents/skills/` (build triage · device smoke test · startup gate · test discovery · FTS5 queries).
- [x] Tạo memory files root: AGENTS.md/CLAUDE.md (điền phần PROJECT) + context.md + working.md + operating_rules.md.
- [x] **Tích hợp AdMob banner** (`google_mobile_ads ^9.0.0`): AdService singleton (initialize + banner unit id theo platform), widget `AdBanner` (fallback sạch khi load fail), đặt ở Home + Page screen; Android Manifest + iOS Info.plist (test App IDs). Analyze sạch · 28/28 test · build APK OK.
  - **Cách chuyển sang production**: (1) Đăng ký app trên [AdMob console](https://admob.google.com) → thêm app iOS + Android → nhận App ID + tạo banner ad unit → (2) cập nhật App ID trong `AndroidManifest.xml` + `Info.plist` → (3) điền banner IDs vào `lib/ads/ad_config.dart` (`_kAndroidProdBanner`/`_kIosProdBanner`) → (4) `useTestAds = false` → (5) build release + test trên device thật. ⚠️ KHÔNG dùng production ID khi dev (bị ban invalid traffic).

## Việc tiếp theo

- [ ] Push web-platform-storage (đang trong working tree) → CI build APK + web.
- [ ] Kiểm tra build web trên device/browser thật (localStorage persistence, import file).
- [ ] Đăng ký AdMob console → lấy App ID + banner IDs thật → chuyển `useTestAds=false` (xem `lib/ads/ad_config.dart`).
- [ ] Chạy thử luồng Import → Compile → Ask → Inbox Accept với OpenRouter key thật (Settings → nhập key).
- [ ] Kiểm tra iOS build (`flutter build ios --no-codesign` / `flutter run -d`).
- [ ] Dogfood ≥5–7 ngày + nhật ký 3 câu/ngày → Gate metric §6.
- [ ] Backlog B1–B9 (`context.md` / `.project/overview.md §5`) — ưu tiên B1 Inbox UI, B4 Entity Index, B9 patch engine.
