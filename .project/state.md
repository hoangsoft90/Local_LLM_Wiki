# AgentWiki — State

> Cập nhật: 2026-08-09 (cuối phiên code Phase 0–2)

## Trạng thái tổng thể

| Hạng mục | Trạng thái |
|---|---|
| OpenSpec đầy đủ (`openspec/`) | ✅ 1 project.md + 11 capabilities + 3 changes (proposal/tasks/tests) |
| App Flutter mobile `agent_wiki/` | ✅ code xong Phase 0 + 1 + 2 |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **28/28 pass** (gồm acceptance TEST-001..011) |
| Build APK | ✅ qua GH Actions (release `agentwiki-apk` ~29MB) — không build local |
| Web platform | ✅ storage split (localStorage web / SQLite mobile), `flutter build web` OK — chưa test browser thật |
| **Test trên device thật** | ✅ Samsung Galaxy A04 (SM-A045F, Android) qua `adb 192.168.0.101:33929` — install OK, launch OK (pid chạy), UI render 720x1600, logcat sạch (không FATAL, không E/flutter) |
| iOS build | ⏳ chưa build (cần Xcode + simulator/device) |
| Git | ⚠️ branch `master`, **chưa commit gì** — toàn bộ untracked (`.gitignore`, `.opencode/`, `AGENTS.md`, `CLAUDE.md`, `agent_wiki/`, `openspec/`) |

## Đã hoàn thành (theo phase)

- **Phase 0 — Engine**: canonical storage (pages/sources/claims/wiki.yaml),
  IndexDb SQLite + FTS5 + `rebuild()`, Semantic Patch Engine (8 ops + template headings),
  search BM25, export, deprecate-page.
- **Phase 1 — AI loop**: LlmProvider interface + OpenRouter BYOK + Mock/Demo,
  compile (Luồng A tự động), ask + citations, draft patch bundle → inbox Accept/Reject,
  toàn bộ UI mobile (Home/Ask/Page/Search/Inbox/Sources/Settings).
- **Phase 2 — Trust**: status transition rules (agent không set cross_checked/human_verified),
  cross-model corroboration (chỉ Luồng B, đúng REQ-6), revisions page+claim, BYOK
  primary+corroboration models, source versioning + `⚠ evidence source changed`,
  `.ai/runs` log, prompt-injection defense (quote verbatim + parser + SYSTEM separation).
- **Monetization**: AdMob banner (`google_mobile_ads ^9.0.0`, test IDs) — Home + Page;
  bổ sung sau Phase 2 (ngoài spec gốc "no ads").

## Quyết định quan trọng trong phiên này

1. **Mobile-first (iOS+Android)** thay vì Desktop theo spec gốc §1.8 — user chốt.
2. **OpenRouter** là provider đầu tiên (BYOK multi-provider).
3. **Phạm vi code luôn: Phase 0–2 đầy đủ**.
4. Sửa từ review: **đọc canonical trước DB** (getPage/getClaim), **quote verbatim
   kiểm tra cả ở patch engine** (Flow B), corroboration chỉ trigger khi upgrade
   `cross_checked`/`human_verified` hoặc ≥2 sources.
5. Build env: AGP 8.9.1 · Gradle 8.14.3 · Kotlin 2.2.20 · minSdk 23 ·
   file_picker ^10 · flutter_secure_storage ^10 (xem `patterns.md §10`).
6. **AdMob banner** (`google_mobile_ads ^9.0.0`) — Home + Page, không Ask (policy
   LLM content). Android đã production (2026-08-11); iOS còn test (chưa có app iOS trên AdMob).

## Việc còn lại / Backlog

- [ ] **Commit** lần đầu (cả repo: `.plan`, `openspec`, `agent_wiki`, `.project`).
- [ ] Chạy thử trên thiết bị/simulator thật (iOS + Android), đặc biệt luồng
      Import → Compile → Ask → Save → Inbox Accept với OpenRouter key thật.
- [ ] Kiểm tra iOS build (`flutter build ios --no-codesign` hoặc `flutter run -d`).
- [ ] Dogfood period (≥5–7 ngày) + nhật ký 3 câu/ngày (§6 spec) trước Gate.
- [ ] Backlog B1–B9 (`overview.md §5`) — ưu tiên B1 (Inbox UI đầy đủ), B4 (Entity Index), B9 (patch engine hoàn thiện).
- [ ] Có thể bổ sung: demo/example sources để dogfood nhanh không cần API key
      (DemoLlmProvider đã sẵn).

## Số liệu hiện tại

- Pages/claims/sources: chưa có dữ liệu thật (wiki rỗng khi mới mở).
- `.ai/runs`: ghi log mọi op AI (compile/ask/draft_patch/corroborate).
