# Module: Patch Engine

Vị trí: `agent_wiki/lib/domain/patch_engine.dart` + `core/models/patch_op.dart`
· spec: `openspec/capabilities/patch-engine`

## 8 ops

| op | payload | Ghi chú |
|---|---|---|
| `create_page` | page_id?, title, page_type, body? | seed template headings; chặn duplicate title |
| `add_claim` | page_id, statement, hypothesis, evidence[] | cần evidence (trừ hypothesis); status supported/unverified; quote verbatim |
| `add_evidence` | claim_id, source_id, source_version, location, quote | quote verbatim |
| `link_pages` | source_page_id, target_page_id, link_type | INSERT OR IGNORE |
| `update_claim_status` | claim_id, new_status | agent không set cross_checked/human_verified |
| `deprecate_claim` | claim_id, reason | status=deprecated + deprecated_reason |
| `add_decision` | page_id, problem, decision, rationale | chỉ page_type=decision; set 3 sections |
| `append_section` | page_id, heading, content | append dưới heading (tạo nếu thiếu) |

## Section editing

- `setSections(markdown, {heading: content})` — thay nội dung section, giữ phần còn lại, tạo missing section ở cuối.
- `appendToSection(markdown, heading, content)` — append vào section có sẵn hoặc tạo mới.
- Heading regex: `^(#{1,6})\s+(.*)$`.

## Bất biến

- Validate hết trước khi ghi (fail → `PatchException`, không ghi gì).
- Mỗi op thành công → `insertRevision(target_type, target_id, patchJson)`.
- Mọi mutation ghi cả canonical + index (page: `store.writePage` + `index.updatePage`).

## Actor rules

- `Author.agent` → compile (Luồng A), claim ≤ supported, không upgrade trust.
- `Author.human` → apply draft từ inbox (Luồng B) sau khi review/corroboration.
