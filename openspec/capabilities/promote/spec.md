# Capability: Promote & Inbox (Flow B)

## Overview

Promote is the high-risk write leg: merging synthesized multi-source answers or upgrading a claim's trust level. It ALWAYS goes through the Knowledge Inbox where the author Accepts or Rejects. Cross-model corroboration runs here — never in Ask.

## Requirements

- **REQ-1** Flow B pipeline: `ANSWER / STATUS-UPGRADE REQUEST → DRAFT PATCH BUNDLE → KNOWLEDGE INBOX → REVIEW (+CROSS-MODEL) → PROMOTE/MERGE or REJECT`.
- **REQ-2** Draft patch bundle = array of patch ops (patch-engine spec) + metadata (`reason`, `origin_op` = `ask_save | status_upgrade`, `created_at`, `model`).
- **REQ-3** Inbox entries are persisted (file: `inbox/draft_<id>.json` under wiki dir) with status `pending | accepted | rejected`.
- **REQ-4** Accept → validate + apply ops via patch engine (atomic); update bundle status; log to revisions.
- **REQ-5** Reject → discard; bundle marked rejected with optional reason; nothing written.
- **REQ-6** Cross-model corroboration (TEST-010): only triggered on:
  - `update_claim_status` to `cross_checked` or `human_verified`, or
  - merge of an answer synthesized from ≥2 sources.
  It asks the secondary model: "Given claim + evidence, is this supported?" — corroboration required before promote; Ask never triggers it.
- **REQ-7** TEST-004: save answer (Flow B) → page updated via PATCH, old content preserved (append/edit only, no overwrite), new claim stays `supported` (never auto-verified).
- **REQ-8** UI: Inbox screen lists pending drafts with Accept/Reject; simple button-level review for Phase 0–2 (full inbox UI = backlog B1).

## Behavior

- A draft from Ask whose ops contain only new `supported` claims from one source may be demoted to Flow A only by explicit user action; default stays in inbox.
- Corroboration failure → bundle gets `needs_review` note; human decides.
