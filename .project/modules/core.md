# Module: Core (models & util)

Vị trí: `agent_wiki/lib/core/`

## models/enums.dart

- Enums có `wire` + `label`: `PageType`, `ClaimStatus`, `Author`, `LinkType`,
  `RevisionTargetType`, `DraftStatus`; `fromWire` fallback an toàn.
- `pageTypeTemplates` + `templateHeadings(type)` — headings cố định cho patch engine.

## models/models.dart

- `PageRecord` (immutable, `copyWith`), `SourceRecord` (hash/version, `toJson/fromJson`),
  `Evidence`, `Claim` (canonical JSON schema, `copyWith`),
  `LinkRecord`, `Revision`, `WikiMeta`, `SearchHit`.

## models/patch_op.dart

- `PatchOp(op, data)` + 8 factory constructors; `toJson/fromJson`.
- Dùng null-aware map entries (`'page_id': ?pageId`) cho field optional.

## models/draft_bundle.dart

- `DraftBundle` — inbox item; `needsCorroboration(sourceIds)` theo REQ-6
  (chỉ upgrade trust hoặc ≥2 sources); `toJson/fromJson`.

## models/answer_result.dart

- `AnswerResult` (+`AnswerCitation`), `CompileResult`, `AcceptResult`.

## util/util.dart

- `newId()` (UUIDv4), `sha256Hex`, `nowIso()`, `slugify`, `pageFilename(title, id)`,
  `truncate`, `ftsQuery(raw, requireAll)` — prefix token, OR/AND.

## util/frontmatter.dart

- `parseFrontmatter` / `renderFrontmatter` — YAML frontmatter lossless; body trim khi parse.
