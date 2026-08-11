# Tasks — AI Provider

> Implemented — see `agent_wiki/lib/ai/` (28/28 tests pass).

- [x] LlmProvider interface (`generate` / `structured`).
- [x] OpenRouter client + error mapping (401/402/429).
- [x] Mock provider (deterministic tests) + Demo provider (offline, no key).
- [x] Secure API key storage (`flutter_secure_storage`; `FileKeyStore` fallback → `settings.json`).
- [x] Prompt sectioning + JSON output parser + injection defense (TEST-011).
- [x] `.ai/runs` logging (op, model, prompt_version, input_ids, output_ids, ts).
