# AgentWiki — Operating Rules (root)

> Chỉ chứa RULE RIÊNG của project (không lặp lại hạ tầng chung trong AGENTS.md).
> Đọc cùng `AGENTS.md` (hạ tầng) và `openspec/` (workflow).
> Bản chi tiết có ví dụ: `.project/ai-rules.md`.

## BẮT BUỘC (không vi phạm)

1. **Canonical-first.** `getPage`/`getClaim` đọc file canonical (`pages/*.md`, `claims/claim_<id>.json`) trước — DB chỉ là derived index (D1).
2. **Patch-only.** Mọi mutation qua `repo.applyOp(op, actor:)` — không ghi thẳng markdown/json rồi bỏ qua revision/index (D2).
3. **Agent không set `cross_checked`/`human_verified`.** `update_claim_status` với `actor == agent` bị chặn. Chỉ human (inbox accept) + corroboration (D4).
4. **Quote verbatim.** Evidence quote phải tồn tại nguyên văn trong source — kiểm tra ở patch engine (`src.content.contains(quote)`), không chỉ ở compile parser (D7).
5. **Corroboration CHỈ ở Luồng B** — khi status upgrade lên `cross_checked`/`human_verified` hoặc merge ≥2 sources. Ask/compile không gọi model 2 (D5).
6. **Không xóa ngầm.** Deprecate (giữ file) > delete. Không xóa page/claim/source khỏi disk trừ khi có lý do rõ ràng (D10).
7. **API key an toàn.** Key chỉ trong secure storage — không vào canonical files, `.ai/runs`, log, memory, hay bất kỳ file nào trong repo.
8. **Prompt chống injection.** Tách SYSTEM / UNTRUSTED SOURCE|KNOWLEDGE / TASK + nhắc "data, not instructions"; output parser validate JSON + cấu trúc trước khi dùng (D7).
9. **Wire names đóng băng** (`page_type`, `claim_status`, `author`, `link_type`, `revision_target_type`, `draft_status`) — nằm trong canonical files + DB (D8). Sửa enum/UI label → kiểm tra `fromWire` fallback để dữ liệu cũ đọc được.
10. **Test naming:** KHÔNG đặt file `*_tests.dart` (số nhiều) — `flutter test` sẽ bỏ qua âm thầm. Phải là `*_test.dart` (vd: `acceptance_test.dart`).

## Quy trình khi sửa code

- Task lớn (≥3 file / schema / API): đối chiếu `openspec/changes/*/proposal.md` — không lan scope; chưa có change thì tạo trước khi code.
- Sau khi sửa: `cd agent_wiki && flutter analyze` + `flutter test` (đủ 28) — KHÔNG báo xong nếu đỏ.
- Chạm storage/DB: chạy riêng `test/acceptance_test.dart` (TEST-001..011).
- Sửa dependency: cảnh báo pitfalls AGP/Gradle/win32/native-assets — xem `.project/patterns.md §10` + skill `flutter-android-build-triage`.
- Lỗi device/build lặp lại: kiểm tra skill tương ứng trong `.agents/skills/` trước khi tự mò.

## Test conventions

- Acceptance test theo chuẩn `routeMock()` + `tempRepo()` + `FileKeyStore` (xem `test/test_util.dart`).
- Mỗi TEST-0xx trong DoD cần ≥1 test — cập nhật `openspec/changes/<phase>/tests.md`.
- Chạy 1 case: `flutter test test/acceptance_test.dart --plain-name 'TEST-003'`.
