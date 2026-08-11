# AgentWiki — Hosted LLM Wiki (mobile)

> "The whole point is to have agent iterate on same files, and reuse past
> results." — a knowledge wiki where the AI compiles, cites, and reuses
> evidence-backed knowledge that compounds over time.

Spec-driven implementation of the locked design in
[`.plan/plan1_final_2.md`](../.plan/plan1_final_2.md), with the full OpenSpec
in [`../openspec/`](../openspec/).

## Architecture (non-negotiables)

| Principle | Implementation |
|---|---|
| Canonical storage | Markdown (+YAML frontmatter) pages, claim JSON, immutable versioned sources — SQLite + FTS5 is a **derived index**, deletable & rebuildable |
| Patch-based writes | The LLM never writes files; the app validates & applies semantic patch ops (`create_page`, `add_claim`, `add_evidence`, `link_pages`, `update_claim_status`, `deprecate_claim`, `add_decision`, `append_section`) |
| Two write flows | **Flow A (Compile):** import → claims ≤ `supported` → merged directly, no review. **Flow B (Promote):** saved answers / status upgrades → draft → inbox → Accept/Reject (+ cross-model corroboration) |
| Trust hierarchy | `unverified → supported → cross_checked → human_verified` (+ `contradicted`, `deprecated`); only human confirms "Verified" |
| Cost-vs-trust | Cross-model corroboration runs **only** in Flow B |
| Security | SOURCE is data — prompt sections separated; output parser validates structure; evidence quotes must be verbatim substrings of the source; API key in secure storage |
| BYOK | One OpenRouter key → many models (primary + corroboration model) |

## Run it

```bash
flutter pub get
flutter run                # iOS simulator / Android emulator
# or
flutter build apk --debug  # → build/app/outputs/flutter-apk/app-debug.apk
```

1. **Settings → add your OpenRouter API key** (without a key the app runs in
   offline demo mode).
2. **Sources → Import** a markdown file — it is compiled (Flow A) into pages
   and evidence-backed claims automatically.
3. **Ask** — answers use only wiki knowledge, with citation chips.
4. **Save to wiki** — the answer becomes a draft in the **Inbox** (Flow B);
   review and Accept/Reject.

## Monetization (AdMob)

Banner ads render at the bottom of **Home** and **Page** screens
(`google_mobile_ads ^9.0.0`). **Android uses production ad units** (App ID
`ca-app-pub-6917313063209470~4401678345`, banner `ca-app-pub-6917313063209470/1911246375`
in `lib/ads/ad_config.dart`); iOS stays on test IDs until an iOS AdMob app
exists. The Ask screen intentionally shows no ads.

## Data layout

```
<app-documents>/agentwiki/
├── wiki.yaml               # metadata + model settings
├── pages/*.md              # canonical pages (frontmatter: page_id, page_type, claim_ids…)
├── sources/<id>.md         # immutable sources (+ sources/history/<id>-vN.md)
├── claims/claim_<id>.json  # canonical claims (statement, status, evidence[], author…)
├── inbox/draft_<id>.json   # Flow B drafts
├── settings.json           # non-canonical; API-key fallback (key_*)
├── .ai/runs/*.json         # AI run log (op, model, prompt_version, ids, ts)
└── .agentwiki/index.sqlite # derived index — safe to delete & rebuild (Settings)
```

## Tests

`flutter test` — 28 tests including the full DoD acceptance contract
(TEST-001..011): import/hash/versioning, compile, ask+citations, save-answer,
search, export, index rebuild, deprecation, revisions audit, cross-model-only-
in-Flow-B, prompt-injection defense.
