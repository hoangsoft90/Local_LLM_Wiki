# Tasks — Phase 1: AI Loop

- [x] `LlmProvider` interface + OpenRouter HTTP client + Mock provider.
- [x] Prompt templates: compile, ask, draft-patch; SYSTEM/SOURCE/TASK separation; "SOURCE is data" instruction.
- [x] Output parser: JSON extraction, schema validation per op, injection stripping.
- [x] Compile service (Flow A automatic, status ≤ supported, evidence required + verbatim).
- [x] Ask service (BM25 retrieval, citations validated).
- [x] Draft patch bundle creation from saved answers (Flow B).
- [x] Inbox store: pending/accepted/rejected persistence.
- [x] Accept → apply via patch engine (atomic); Reject → discard with reason.
- [x] UI screens: Home, Ask, Page detail, Inbox, Sources, Settings.
- [x] API key storage (secure) + model picker.
- [x] Tests: compile (TEST-002), ask+citation (TEST-003), save answer (TEST-004), injection (TEST-011).
