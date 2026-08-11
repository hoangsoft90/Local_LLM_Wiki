# Change: Phase 1 — AI Loop (closed)

## Motivation

With the engine in place, close the compounding loop: import → compile (Flow A, automatic) → ask + citations → draft patch (Flow B) → Accept/Reject. Single model through one interface (`generate`/`structured`); OpenRouter BYOK.

## Design

- Implement `LlmProvider` interface + OpenRouter implementation + `MockLlmProvider` (tests/offline).
- Prompt templates with SYSTEM / UNTRUSTED SOURCE / TASK separation and JSON output schema; strict output parser (rejects malformed, strips prose, never follows source instructions).
- Compile service: source → structured `{pages: [..], claims: [..]}` → patch ops applied automatically (Flow A), status ≤ supported.
- Ask service: FTS5 retrieval → prompt → answer + citations; citations validated against retrieved items.
- Draft-patch service: answer → patch bundle → inbox (`inbox/draft_<id>.json`); Accept/Reject UI (simple buttons).
- Mobile UI: Home, Ask, Page detail, Inbox (simple), Sources, Settings screens.

## Impact

- New capabilities: `ai-provider`, `compile`, `ask`, `promote` (simple review), `mobile-ui`.
- Depends on Phase 0 engine.

## Acceptance

- TEST-002, TEST-003, TEST-004, TEST-011.
