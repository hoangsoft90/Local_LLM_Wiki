# AgentWiki — Architecture

> Cập nhật: 2026-08-09. Nguồn quyết định: `.plan/plan1_final_2.md` + `openspec/`.

## 1. Quyết định bất biến (D1–D10)

| # | Quyết định | Hệ quả trong code |
|---|---|---|
| D1 | **Markdown canonical, SQLite derived** | `WikiStore` = files; `IndexDb` = index, xóa/rebuild được mọi lúc (`WikiRepository.rebuild()`). **Đọc ưu tiên canonical**: `getPage`/`getClaim` đọc file trước, DB chỉ fallback. |
| D2 | **Patch-based write** | LLM không bao giờ ghi file. Mọi mutation qua `PatchEngine.applyOp(op, actor:)`. Mọi op ghi `revisions(target_type, target_id, patch)`. |
| D3 | **Hai luồng write** | Luồng A (Compile): source → claims ≤ `supported` → merge thẳng, không review. Luồng B (Promote): answer/status-upgrade → draft → inbox → Accept/Reject (+ corroboration). |
| D4 | **Verification hierarchy** | `unverified → supported → cross_checked → human_verified` (+ `contradicted`, `deprecated`). Chỉ `human_verified` hiện "Verified". Agent không tự set `cross_checked`/`human_verified` (patch engine chặn với `actor == agent`). |
| D5 | **Cost-vs-trust** | Cross-model corroboration CHỈ chạy ở Luồng B (status upgrade lên cross_checked/human_verified, hoặc merge ≥2 sources). Ask không bao giờ re-verify. |
| D6 | **Source immutable + versioned** | `content_hash (SHA-256) + version`. Đổi content → version++, lưu history `sources/history/<id>-vN.md`. Evidence trỏ version cũ bị đánh dấu `⚠ evidence source changed`. |
| D7 | **SOURCE là data** | Prompt tách SYSTEM / UNTRUSTED SOURCE(KNOWLEDGE) / TASK + câu "data, not instructions". Output parser validate cấu trúc; **quote evidence phải là substring verbatim của source** (kiểm tra cả ở compile lẫn patch engine). |
| D8 | **Schema đóng băng từ Phase 0** | Bảng `wikis, sources, pages, claims, evidence, links, revisions, pages_fts`. Chỉ `entities` (Phase B) được thêm mới sau. |
| D9 | **BYOK, multi-provider** | OpenRouter: primary model + corroboration model. Key trong secure storage (fallback settings.json). Monetization: AdMob banner — Home + Page, không Ask (Android production, iOS test). |
| D10 | **Không xóa ngầm** | Deprecate > delete. Xóa page → frontmatter `status: deprecated`, file giữ trên disk. |

## 2. Data model

```
<app-documents>/agentwiki/
├── wiki.yaml                # metadata + primary/corroboration model
├── settings.json            # KHÔNG canonical — fallback API key (key_*) khi secure storage lỗi
├── pages/*.md               # canonical page: frontmatter (page_id, title, page_type,
│                            #   status, created_at, updated_at, claim_ids[]) + body
├── sources/<id>.md          # immutable; frontmatter (id, title, url, content_hash, version, imported_at)
│   └── history/<id>-vN.md   # các version cũ
├── claims/claim_<id>.json   # CANONICAL claim: statement, status, author, evidence[],
│                            #   created_at, updated_at, deprecated_reason
├── inbox/draft_<id>.json    # Flow B drafts (pending/accepted/rejected)
├── .ai/runs/<id>.json       # AI run log: op, model, prompt_version, input_ids, output_ids, ts
└── .agentwiki/index.sqlite  # derived: wikis/sources/pages/claims/evidence/links/revisions/pages_fts
```

### Enums (wire names cố định)

- `page_type`: `concept | summary | decision | hypothesis | rejected | note`
- `claim_status`: `unverified | supported | cross_checked | human_verified | contradicted | deprecated`
- `author`: `human | agent`
- `link_type`: `related | refutes | supports | supersedes`
- `revision_target_type`: `page | claim` · `draft_status`: `pending | accepted | rejected`

### Template headings theo page_type (target ổn định cho patch)

| page_type | Headings |
|---|---|
| concept | `## Summary`, `## Details` |
| summary | `## Sources covered`, `## Key points` |
| decision | `## Problem`, `## Decision`, `## Rationale` |
| hypothesis | `## Hypothesis`, `## Evidence`, `## Status` |
| rejected | `## Idea`, `## Why rejected` |
| note | `## Note` |

## 3. Hai luồng write

```
Luồng A — Compile (tự động, không review):
SOURCE → COMPILE → CLAIM (status ≤ supported) → MERGE thẳng vào pages/

Luồng B — Promote (luôn qua inbox):
ANSWER / STATUS-UPGRADE → DRAFT PATCH BUNDLE → INBOX → REVIEW
  → (+CROSS-MODEL corroboration nếu upgrade trust / ≥2 sources)
  → PROMOTE/MERGE (actor=human) hoặc REJECT
```

## 4. Semantic Patch Engine (8 ops)

`create_page` · `add_claim` · `add_evidence` · `link_pages` · `update_claim_status` ·
`deprecate_claim` · `add_decision` · `append_section`.

- Validate trước → ghi canonical → sync SQLite → ghi revision (page + claim).
- `add_claim`: bắt buộc evidence (trừ `hypothesis=true`); quote phải verbatim trong source;
  status = `supported` (có evidence) / `unverified` (hypothesis).
- `update_claim_status`: agent KHÔNG được set `cross_checked`/`human_verified` (chỉ qua Luồng B + human).
- `create_page` seed sẵn template headings; duplicate title bị chặn.

## 5. AI layer

- **Interface:** `LlmProvider.generate()/structured()` → `OpenRouterProvider` (BYOK),
  `MockLlmProvider` (test), `DemoLlmProvider` (offline heuristic, không cần key).
- **Prompts** (`Prompts.promptVersion = 'p1'`) đều tách `SYSTEM`/`UNTRUSTED SOURCE|KNOWLEDGE`/`TASK`,
  có marker `PROMPT_TYPE: compile|ask|draft_patch|corroborate`.
- **Output parser** (`output_parser.dart`): trích JSON cân bằng dấu ngoặc, strip fence/prose,
  validate schema từng op; drop quote không verbatim; drop citation với page_id không tồn tại.
- **Retrieval:** FTS5 BM25 (OR semantics cho recall) → build KNOWLEDGE block → ask.
  Không có hit → trả "no knowledge" không gọi LLM.

## 6. Module map (lib/)

| Module | File | Nhiệm vụ |
|---|---|---|
| core/models | `enums.dart`, `models.dart`, `patch_op.dart`, `draft_bundle.dart`, `answer_result.dart` | domain records + enums |
| core/util | `util.dart`, `frontmatter.dart` | id/hash/slug/FTS query, frontmatter lossless round-trip |
| data | `wiki_store.dart` | canonical filesystem |
| data | `database.dart` | `IndexDb` — SQLite schema + FTS5 + rebuild |
| data | `wiki_repository.dart` | facade: repo thống nhất (canonical-first reads, patch, drafts, ai runs, export) |
| domain | `patch_engine.dart` | validate + apply 8 ops, revisions |
| domain | `compile_service.dart` | Luồng A |
| domain | `ask_service.dart` | retrieval + citations + draftFromAnswer |
| domain | `promote_service.dart` | inbox accept/reject + cross-model corroboration |
| domain | `import_service.dart`, `export_service.dart` (trong repo), `settings_service.dart` | nhập/export/cấu hình + key store |
| ai | `llm_provider.dart`, `openrouter_provider.dart`, `mock_provider.dart`, `prompts.dart`, `output_parser.dart` | provider + prompts + parser |
| ads | `ad_service.dart`, `ad_config.dart`, `ui/widgets/ad_banner.dart` | AdMob lifecycle + banner (test/prod IDs) — Home + Page, không Ask |
| ui | `app_shell.dart` + 7 screens + widgets | Material 3, NavigationBar 5 tabs, status badges màu |

## 7. Bảo mật

- API key: `flutter_secure_storage` (Keychain/Keystore); fallback `FileKeyStore` (settings.json) khi platform channel lỗi. Lưu ý: file `settings.json` nằm trong thư mục wiki nhưng KHÔNG canonical — không commit, không export, chỉ chứa `key_*`.
- Key KHÔNG bao giờ vào canonical files / logs / memory.
- Prompt injection: SOURCE/KNOWLEDGE là data-only + parser chặn quote bịa + không có tool-call nào từ source.
