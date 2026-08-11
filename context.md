# AgentWiki — Context (root)

> File tương đối tĩnh — cập nhật khi có thay đổi lớn về bản chất project.
> Nguồn sâu hơn: `.project/` (overview · architecture · patterns · state · modules).

## Project là gì

**Hosted LLM Wiki** — wiki tri thức do LLM vận hành. Agent (AI) liên tục lặp trên
**cùng một tập file** và **tái sử dụng kết quả đã làm trước đó** — tri thức cộng
dồn (compounding) thay vì research lại từ đầu.

Vòng lặp cốt lõi: `import → compile → ask → write-back → reuse`.

## Trạng thái nhanh (2026-08-09)

- Phase 0 (Engine) + Phase 1 (AI loop) + Phase 2 (Trust) — **đã code xong**.
- `flutter analyze` sạch · `flutter test` **28/28 pass** (gồm acceptance TEST-001..011).
- APK debug build được; **đã test trên Android thật** (Galaxy A04, adb wireless) — app chạy, logcat sạch.
- Git: branch `master`, **chưa commit gì**.
- Chi tiết: `.project/state.md` + `.project/working.md` (log đầy đủ).

## Tech stack

Flutter 3.44 / Dart 3.12 (mobile-first, iOS + Android) · sqlite3 + FTS5 (derived index) ·
OpenRouter BYOK (primary + corroboration models) · yaml / markdown / flutter_markdown ·
provider (state) · file_picker / path_provider / flutter_secure_storage ·
uuid / crypto / http / path. Deps đầy đủ: `agent_wiki/pubspec.yaml`.

## Cấu trúc repo

```
.plan/            # thiết kế gốc + các vòng review (source of truth quyết định)
.draft/           # prompt đã dùng để chốt spec
openspec/         # OpenSpec: project.md + capabilities/ + changes/ (phase0-2)
agent_wiki/       # Flutter app
  lib/core/       # models, util (ids, hash SHA-256, slug, frontmatter)
  lib/data/       # wiki_store (canonical files), database (IndexDb+FTS5), wiki_repository (facade)
  lib/domain/     # patch_engine, import/compile/ask/promote/export services, settings
  lib/ai/         # LlmProvider interface, OpenRouter, Mock/Demo, prompts, output_parser
  lib/ui/         # app_shell + screens (home/ask/page/search/inbox/sources/settings) + widgets + state
  test/           # 28 tests (frontmatter, patch engine, widget smoke, acceptance TEST-001..011)
.project/         # Knowledge Items (README là entry point)
.agents/skills/   # 5 skills model-invoked (build triage, device smoke test, init gate, test discovery, FTS5)
```

## Quyết định kiến trúc cốt lõi (tóm tắt D1–D10)

| # | Quyết định | Nội dung |
|---|---|---|
| D1 | Canonical-first | Markdown/JSON là nguồn sự thật; SQLite chỉ là derived index, đọc canonical trước |
| D2 | Patch-based writes | Mọi mutation qua Semantic Patch Engine (8 ops) — không ghi thẳng file |
| D3 | 2 luồng write | Luồng A (compile tự động, status ≤ supported) · Luồng B (draft → inbox → human accept) |
| D4 | Verification hierarchy | unverified → supported → cross_checked → human_verified; agent không set 2 cấp cao |
| D5 | Corroboration chỉ Luồng B | Cross-model chỉ khi upgrade trust / merge ≥2 sources |
| D6 | Source immutable | Source versioned; content hash; cảnh báo "evidence source changed" |
| D7 | SOURCE = data | Prompt tách SYSTEM/UNTRUSTED/TASK; quote verbatim chống injection |
| D8 | Schema đóng băng | Wire names enum cố định; sửa phải check `fromWire` fallback |
| D9 | BYOK OpenRouter | 1 key nhiều model; key chỉ trong secure storage |
| D10 | Deprecate > delete | Không xóa ngầm page/claim/source khỏi disk |

## AdMob (monetization — banner)

- **Trạng thái**: banner ads (Home + Page screen) bằng `google_mobile_ads ^9.0.0`. **Android đã production** (2026-08-11): App ID `ca-app-pub-6917313063209470~4401678345` + banner `.../1911246375` (`useTestAds=false`). **iOS còn test** — chưa có app/ad unit iOS trên AdMob.
- **Cấu hình native**: Android App ID thật trong `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`) · iOS App ID vẫn là **test ID** `ca-app-pub-3940256099942544~*` trong `Info.plist` (`GADApplicationIdentifier` + SKAdNetworkItems).
- **Interstitial/Rewarded**: ID thật đã lưu trong `lib/ads/ad_config.dart` (`kAndroidProdInterstitial`/`kAndroidProdRewarded`) nhưng **chưa có code dùng**.
- **Khi thêm iOS**: tạo app iOS trên AdMob console → lấy App ID + banner riêng → đổi `Info.plist` + `_kIosProdBanner`.
- **⚠️ Dev build Android giờ cũng load ad thật** (`useTestAds=false` áp cả debug) — tránh click ad của chính mình lúc dev để không dính invalid traffic; nếu cần dev an toàn, tạm bật `useTestAds=true`.
- **KHÔNG đặt banner trên Ask screen** (nội dung LLM-generated dễ bị AdMob hạn chế "replicated/low-value content" — research web 2026).
- Chi tiết hướng dẫn đăng ký AdMob console: `working.md`.

## Việc tiếp theo (chi tiết: `.project/working.md`)

- [ ] Commit lần đầu (repo chưa có commit).
- [ ] Chạy thử luồng Import → Compile → Ask → Inbox Accept với OpenRouter key thật.
- [ ] Kiểm tra iOS build.
- [ ] Dogfood ≥5–7 ngày → Gate metric §6.
- [ ] Backlog B1–B9 (`openspec/` + `.project/overview.md §5`).
