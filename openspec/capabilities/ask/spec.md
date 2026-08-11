# Capability: Ask & Citations

## Overview

Ask answers a question using **only** wiki knowledge retrieved via FTS5 (BM25), citing the exact pages/claims used. It is the reuse leg of the loop: answers should get better as the wiki grows.

## Requirements

- **REQ-1** Retrieval: tokenize question → BM25 query against `pages_fts` (ranked), top-K results (default 8) → load pages + their claims (evidence quotes included).
- **REQ-2** Prompt sections: SYSTEM (answer only from knowledge, cite `[Page Title]` / `(claim:<id>)`, mark uncertainty) / KNOWLEDGE (retrieved context, labeled as untrusted-data) / TASK (question).
- **REQ-3** Answer output: `{answer: string, citations: [{page_id, claim_id?, source_id, source_version}]}` — citations MUST reference actually-retrieved items; parser drops fabricated ids.
- **REQ-4** TEST-003: ask → answer + citations pointing at correct source/page+version.
- **REQ-5** Ask **never** verifies or upgrades claims (TEST-010). Cost stays 1 model call.
- **REQ-6** If retrieval is empty, the model must say "no knowledge in wiki" rather than answer from memory.

## Behavior

- The Ask screen shows the answer with tappable citation chips linking to pages.
- "Save answer" button produces a draft patch bundle (promote spec) — not a direct write.
