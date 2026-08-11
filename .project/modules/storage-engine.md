# Module: Storage Engine

Vị trí: `agent_wiki/lib/data/` · spec: `openspec/capabilities/canonical-storage`, `sources`, `search`, `export-rebuild`

## Các thành phần

- **`WikiStore`** (`wiki_store.dart`) — canonical filesystem:
  - `pages/<filename>.md` (frontmatter: page_id, title, page_type, status, timestamps, claim_ids[])
  - `sources/<id>.md` + `sources/history/<id>-vN.md`
  - `claims/claim_<id>.json` (CANONICAL claim)
  - `wiki.yaml`, `inbox/draft_<id>.json`, `.ai/runs/<id>.json`, `.agentwiki/index.sqlite`
  - Frontmatter lossless (giữ khóa lạ), body trim khi parse.
- **`IndexDb`** (`database.dart`) — derived SQLite:
  - Bảng: `wikis, sources, pages, claims, evidence, links, revisions, _meta, pages_fts` (FTS5 standalone).
  - `rebuild(pages, claims, sources)`: close → xóa file → mở lại → insert.
  - `search(query)`: FTS5 `MATCH` + `bm25` + `snippet(pages_fts, 2, ...)`; fallback LIKE.
- **`WikiRepository`** (`wiki_repository.dart`) — facade duy nhất UI/service dùng:
  - Canonical-first reads: `getPage`/`getClaim` đọc file trước, DB fallback.
  - `importSource` (hash dedupe, version++), `deprecatePage` (frontmatter deprecated + revision),
    `applyOp/applyOps` (qua PatchEngine), `rebuild()`, `exportTo(dest)`, drafts, ai runs, counts.

## Luồng ghi (mọi mutation)

```
validate (engine) → canonical file → index sync (cùng transaction logic) → revisions row
```

## Lưu ý

- Không sửa trực tiếp table pages_fts — đi qua `insertPage/updatePage/deletePageRow`.
- `getPage` scan thư mục pages mỗi lần (OK với wiki nhỏ; nếu lớn → cache/DB-first sau khi
  có cơ chế phát hiện file thay đổi).
- WAL mode bật; `close()` gọi `db.dispose()` (đổi từ `db.close()` khi hạ `sqlite3 2.9.4` — xem `patterns.md §10`).
