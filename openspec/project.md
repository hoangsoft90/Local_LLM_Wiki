# AgentWiki — Project Overview

> Status: OPEN — active development (Phase 0–2)
> Source design: `.plan/plan1_final_2.md` (LOCKED v2) — decisions ported verbatim, adjusted for mobile-first.
> Platform decision (2026-08-09): **Mobile-first (iOS + Android)**. Desktop deferred (contradicts §1.8 of the plan; overridden by owner).

## 1. Mission

AgentWiki is a **hosted LLM wiki** where an AI agent iterates on the same knowledge files over time and **reuses past results** — so that knowledge compounds instead of being re-researched from scratch.

> "Whole point is to have agent iterate on same files, and reuse past results."

The product must prove the **compounding loop** before anything else: import → compile → ask → write-back → reuse.

## 2. Non-negotiable architecture decisions (from locked spec)

| # | Decision | Rule |
|---|---|---|
| D1 | **Canonical storage** | Markdown (+YAML frontmatter) and claim JSON are canonical. SQLite+FTS5 is a **derived index** — deletable and rebuildable at any time. |
| D2 | **Patch-based write** | The LLM never writes files. All mutations go through semantic patch ops applied by the app. |
| D3 | **Two write flows** | Flow A (Compile): ingest → new claims (status ≤ `supported`) → merge directly, no review. Flow B (Promote): status upgrades or synthesized multi-source answers → draft patch → inbox → review (Accept/Reject) → promote. |
| D4 | **Verification hierarchy, not confidence scores** | `unverified → supported → cross_checked → human_verified`, plus `contradicted`, `deprecated`. Only `human_verified` shows "Verified". |
| D5 | **Cost-vs-trust** | Cross-model corroboration triggers **only** in Flow B / promote. Ask never re-verifies. |
| D6 | **Sources are immutable & versioned** | `content_hash (SHA-256) + version`. Evidence pointing at an outdated source version is flagged. |
| D7 | **Sources are DATA, not instructions** | Prompt separated into SYSTEM / UNTRUSTED SOURCE / TASK. Output parser validates structure; injected instructions are rejected/stripped. |
| D8 | **Schema frozen from Phase 0** | Full schema §4 of the plan ships in Phase 0. Only additive change allowed later (`entities` table, Phase B). |
| D9 | **BYOK, multi-provider** | Bring-your-own-key via OpenRouter (one key, many models). Monetization: AdMob banner on Home + Page only — never on Ask. Android uses production ad units; iOS still on test IDs (no iOS AdMob app yet). |
| D10 | **Never silently delete** | Deprecate > delete. Deleted pages become `deprecated`, stay on disk. |

## 3. Data model (canonical vs derived)

```
<app-documents>/agentwiki/
├── wiki.yaml              # wiki metadata + settings
├── pages/                 # *.md, YAML frontmatter (page_id, page_type, claim_ids[])
├── sources/               # *.md, immutable, frontmatter (id, title, url, content_hash, version)
├── claims/                # claim_<id>.json — CANONICAL
├── inbox/                 # draft_<id>.json — Flow B draft bundles
├── settings.json          # non-canonical; API-key fallback (key_*)
├── .agentwiki/index.sqlite# derived index (SQLite + FTS5), rebuildable
└── .ai/runs/*.json        # AI run log (op, model, prompt_version, input/output ids, ts)
```

SQLite tables (derived): `wikis, sources, pages, claims, evidence, links, revisions, pages_fts`. `entities` deferred to Phase B (additive-only exception).

Every `page`/`claim` mutation goes through a patch op and is recorded in `revisions(target_type, target_id, patch)` — for **both** pages and claims.

## 4. Tech stack

- **Flutter 3.44 / Dart 3.12** — mobile-first (iOS + Android).
- **sqlite3 + sqlite3_flutter_libs** — bundled SQLite with FTS5 + JSON1 (pinned `sqlite3 2.9.4` + `sqlite3_flutter_libs 0.5.42` for Android device compatibility).
- **OpenRouter API** (BYOK) — multi-provider access through one key.
- **google_mobile_ads (AdMob)** — banner monetization (Home + Page only; test ad-unit IDs until release).
- **yaml / markdown / flutter_markdown** — frontmatter + rendering.
- **file_picker / path_provider / flutter_secure_storage** — import, storage paths, API-key storage.
- **provider** — lightweight state management.

## 5. Repository layout

```
openspec/        # this spec
.plan/           # design docs (source of truth for decisions)
agent_wiki/      # Flutter app
  lib/
    core/        # models, util (frontmatter, ids, hashing)
    data/        # database, wiki store, repositories
    domain/      # patch engine, services (import/compile/ask/promote/export)
    ai/          # LLM interface, OpenRouter, prompts, output parser
    ads/         # AdMob: ad_config (test/prod IDs), AdService singleton, AdBanner widget
    ui/          # screens + widgets
  test/          # acceptance tests mapping to TEST-001..011
```

## 6. Definition of Done (acceptance tests — global contract)

```
TEST-001 import source            → source record + content_hash
TEST-002 compile (Flow A)         → page created, ≥1 claim (status ≤ supported), every claim has evidence[], no inbox
TEST-003 ask                      → answer + citations pointing at correct source/page+version
TEST-004 save answer (Flow B)     → page updated via PATCH, old content kept (snapshot), new claim stays supported
TEST-005 search                   → new knowledge searchable
TEST-006 export                   → Markdown regenerates the whole wiki
TEST-007 delete index + rebuild   → identical search results
TEST-008 delete page              → deprecated, not removed from disk
TEST-009 every mutation           → recorded in revisions with correct target_type
TEST-010 cross-model corroboration→ only in Flow B/promote; Ask never re-verifies
TEST-011 prompt injection         → "ignore previous instructions…" inside SOURCE has no effect
```

## 7. Roadmap

| Phase | Content | Build time |
|---|---|---|
| Phase 0 — Engine | canonical storage + SQLite/FTS5 index + patch engine + templates + search + export/rebuild | 3–5d |
| Phase 1 — AI loop | import → compile (Flow A) → ask + citations → draft patch (Flow B) → Accept/Reject | 3–5d |
| Phase 2 — Trust | full claim_status, cross-model (Flow B only), revisions for page+claim, BYOK multi-provider, full source hashing | 3–5d |
| Dogfood | author-only usage ≥5–7 days, qualitative daily log (3 questions) | before Gate |
| Phase 3 — Agent | MCP, CLI, session import (Claude Code/Codex/Gemini) — only if Gate passes | +2wk |

## 8. Global conventions

- All timestamps ISO-8601 UTC.
- IDs: UUIDv4 strings (page/claim/source/evidence/revision).
- `claim_status` enum: `unverified | supported | cross_checked | human_verified | contradicted | deprecated`.
- `page_type` enum: `concept | summary | decision | hypothesis | rejected | note`.
- `author` enum: `human | agent`.
- Tests live in `agent_wiki/test/` and map 1:1 to the DoD TEST-0xx contract.
