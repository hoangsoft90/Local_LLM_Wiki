# Capability: Compile (Flow A)

## Overview

Compile ingests **one source** and produces pages + claims (status ≤ `supported`), merged **directly** into the wiki — no inbox. It is the automatic ingestion leg of the compounding loop.

## Requirements

- **REQ-1** Input: one imported source (id + version). Output: `{pages: [{title, page_type, claims: [{statement, evidence: [{source_version, location, quote}]}]}]}`.
- **REQ-2** Every claim MUST quote evidence directly from the source (quote is a verbatim substring). Parser validates evidence presence; claims without evidence are rejected.
- **REQ-3** Claims are created at `supported` (direct evidence) or `unverified` (no evidence — must be explicitly flagged by the model as hypothesis). Never `cross_checked`/`human_verified`.
- **REQ-4** Compile generates patch ops (`create_page` + `add_claim`, with evidence embedded in each `add_claim.evidence[]`) applied via the patch engine (Flow A: automatic, no review). `add_evidence` is not emitted by compile — it is a separate op for Flow B.
- **REQ-5** TEST-002: compile → page created, ≥1 claim, all claims have evidence, nothing passes through the inbox.
- **REQ-6** Existing pages with same title are merged into (append) rather than duplicated; new claims link to the existing page.

## Behavior

- Run is logged with `op: compile` in `.ai/runs/`.
- Compile never triggers cross-model corroboration (that is Flow B only — TEST-010).
