# AgentWiki — AI Rules (cho agent code trong repo)

> Cập nhật: 2026-08-09. Bản tóm tắt thao tác nhanh: `../operating_rules.md` (root).
> Đây là các rule RIÊNG của project — đọc cùng
> `AGENTS.md` (hạ tầng chung) và `openspec/` (workflow).

## BẮT BUỘC (không vi phạm)

1. **Đọc ưu tiên canonical, DB chỉ là index.** `getPage`/`getClaim` phải đọc
   file canonical (`pages/*.md`, `claims/claim_<id>.json`) trước. Không đảo
   ngược vì sẽ bỏ sót thay đổi thủ công trên file (D1).
2. **Mọi mutation đi qua PatchEngine** (`repo.applyOp(op, actor:)`) — không bao
   giờ ghi thẳng markdown/json rồi bỏ qua revision/index. Luôn kèm `actor`
   (`human` cho Flow B accept, `agent` cho compile).
3. **Agent không bao giờ set `cross_checked`/`human_verified`.** `update_claim_status`
   với `actor == agent` phải bị chặn. Chỉ human (qua inbox accept) + corroboration.
4. **Evidence quote phải verbatim trong source content.** Kiểm tra ở patch engine
   (`src.content.contains(quote)`), không chỉ ở compile parser.
5. **Corroboration (model thứ 2) CHỈ chạy ở Luồng B** — khi status upgrade lên
   `cross_checked`/`human_verified` hoặc merge ≥2 sources. Ask/compile không được gọi.
6. **Không xóa ngầm.** Deprecate (frontmatter/file giữ) > delete. Không xóa file
   page/claim/source khỏi disk trừ khi có lý do rõ ràng.
7. **API key chỉ trong secure storage** — không vào canonical files, `.ai/runs`,
   log, memory, hay bất kỳ file nào trong repo. (Fallback `FileKeyStore` ghi `key_*`
   vào `settings.json` — file KHÔNG canonical, không commit.)
8. **Prompt phải tách SYSTEM / UNTRUSTED SOURCE|KNOWLEDGE / TASK** và nhắc
   "data, not instructions". Output parser phải validate JSON + cấu trúc trước khi dùng.
9. **Wire names enum không đổi** (`page_type`, `claim_status`, `author`, `link_type`,
   `revision_target_type`, `draft_status`) — đang nằm trong canonical files + DB đóng băng (D8).
10. **Sửa enum/UI label → kiểm tra `fromWire` fallback** — dữ liệu cũ phải đọc được.

## Quy trình khi sửa code

- Task lớn (≥3 file / schema / API): đối chiếu `openspec/changes/*/proposal.md` —
  không lan ra ngoài scope. Nếu chưa có change, tạo trước khi code.
- Sau khi sửa: `flutter analyze` + `flutter test` (đủ 28 tests) — KHÔNG báo xong nếu đỏ.
- Nếu chạm storage/DB: chạy `test/acceptance_test.dart` (TEST-001..011) riêng.
- Sửa dependency: cảnh báo AGP/Gradle/win32 pitfalls (`patterns.md §10`).

## Test

- Thêm test acceptance theo chuẩn `routeMock()` + `tempRepo()` + `FileKeyStore`.
- Mỗi TEST-0xx trong DoD cần ít nhất 1 test — cập nhật `openspec/changes/<phase>/tests.md`.
- KHÔNG đặt tên file `*_tests.dart` (số nhiều) — `flutter test` sẽ bỏ qua.
