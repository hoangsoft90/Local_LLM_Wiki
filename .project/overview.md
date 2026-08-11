# AgentWiki — Overview

> Cập nhật: 2026-08-09

## 1. Sản phẩm

**Hosted LLM Wiki**: một wiki tri thức do LLM vận hành, nơi agent (AI) liên tục
lặp trên **cùng một tập file** và **tái sử dụng kết quả đã làm trước đó** —
tri thức cộng dồn (compounding) thay vì phải research lại từ đầu.

> "The whole point is to have agent iterate on same files, and reuse past
> results. It works quite well."

Vòng lặp cốt lõi phải được chứng minh trước khi xây thêm bất cứ thứ gì:
`import → compile → ask → write-back → reuse`.

## 2. Tech stack

- **Flutter 3.44 / Dart 3.12** — mobile-first (iOS + Android). Desktop deferred.
- **sqlite3 + sqlite3_flutter_libs** — SQLite hiện đại kèm FTS5 + JSON1 (derived index).
- **OpenRouter API (BYOK)** — 1 key truy cập nhiều model (primary + corroboration).
- **yaml / markdown / flutter_markdown** — frontmatter + rendering markdown.
- **file_picker ^10 / path_provider / flutter_secure_storage ^10** — import, paths, API key.
- **google_mobile_ads ^9.0.0 (AdMob)** — banner ads (Home + Page; Android production, iOS test).
- **provider** — state management (ChangeNotifier).
- **uuid / crypto / http / path** — id, SHA-256, OpenRouter HTTP, path utils.

Dependencies đầy đủ: `agent_wiki/pubspec.yaml`.

## 3. Cấu trúc repo

```
.plan/                  # thiết kế gốc + các vòng review (source of truth quyết định)
.draft/prompt.txt       # chuỗi prompt đã dùng để chốt spec
openspec/               # OpenSpec đầy đủ: project.md + capabilities/ + changes/
agent_wiki/             # Flutter app (mobile)
  lib/
    main.dart, app.dart
    core/models/        # enums, PageRecord, SourceRecord, Claim, Evidence, Revision, PatchOp, DraftBundle…
    core/util/          # ids, hashing (SHA-256), slug, FTS query builder, frontmatter
    data/               # wiki_store (canonical files), database (IndexDb + FTS5), wiki_repository (facade)
    domain/             # patch_engine, import/compile/ask/promote/export services, settings
    ai/                 # LlmProvider (interface), OpenRouterProvider, Mock/Demo providers, prompts, output_parser
    ads/                # AdMob: ad_config (test/prod IDs) + AdService singleton
    ui/                 # app_shell + screens (home/ask/page/search/inbox/sources/settings) + widgets (AdBanner…) + state
  test/                 # 28 tests — bao gồm acceptance TEST-001..011
  android/              # AGP 8.9.1 · Gradle 8.14.3 · minSdk 23
  ios/
```

## 4. Roadmap

| Phase | Nội dung | Trạng thái |
|---|---|---|
| Phase 0 — Engine | canonical storage + SQLite/FTS5 + patch engine + search + export/rebuild | ✅ xong |
| Phase 1 — AI loop | import → compile (Luồng A) → ask + citations → draft patch (Luồng B) → Accept/Reject | ✅ xong |
| Phase 2 — Trust | claim_status đầy đủ, cross-model (chỉ Luồng B), revisions page+claim, BYOK multi-provider, source hash | ✅ xong |
| Dogfood | author dùng thật ≥5–7 ngày, nhật ký định tính 3 câu/ngày | ⏳ chưa bắt đầu |
| Gate | metric §6 (Compounding Ratio…) | chờ sau dogfood |
| Phase 3 — Agent | MCP, CLI, session import (Claude Code/Codex/Gemini) | backlog, chỉ nếu Gate pass |
| Sau | Graph viz, Health dashboard, Cloud sync, Team, nightly agent | backlog gated |

## 5. Backlog (không thuộc Phase 0–2)

B1 Inbox UI đầy đủ · B2 Agent Namespace/MCP sandbox · B3 Claim TTL/staleness +
nightly job · B4 Entity Index + hybrid query · B5 Decision/Rejected first-class ·
B6 Session import · B7 Eval fixtures · B8 Metric gate · B9 Semantic Patch hoàn thiện.
