# AgentWiki — Knowledge Items (KI)

> Entry point cho bộ Knowledge Items của project. Mỗi file trả lời một loại câu
> hỏi khác nhau — đọc file phù hợp thay vì đọc hết.

## Chỉ mục

| File | Trả lời câu hỏi |
|---|---|
| [`overview.md`](overview.md) | Project này là gì? Tech stack? Cấu trúc repo? Roadmap? |
| [`architecture.md`](architecture.md) | Kiến trúc & các quyết định bất biến (D1–D10)? Data model? Luồng write? |
| [`patterns.md`](patterns.md) | Code theo pattern nào? Convention đặt tên? Bẫy kỹ thuật đã gặp? |
| [`state.md`](state.md) | Đang ở đâu? Đã làm gì, test ra sao, còn việc gì? |
| [`ai-rules.md`](ai-rules.md) | Agent code trong repo này phải tuân thủ gì? |
| [`working.md`](working.md) | Nhật ký làm việc (có ngày tháng ISO) |
| [`modules/`](modules/) | Chi tiết từng module (storage-engine, patch-engine, ai-layer, mobile-ui) |

## Ngữ cảnh nhanh

- **Sản phẩm:** Hosted LLM Wiki — agent (AI) lặp trên cùng một tập file tri thức và
  **tái sử dụng kết quả cũ** ("agent iterate on same files, reuse past results").
- **Spec nguồn (đã khóa):** `.plan/plan1_final_2.md` → được port thành
  OpenSpec đầy đủ tại [`openspec/`](../openspec/).
- **Trạng thái:** Phase 0–2 đã code xong (Engine + AI loop + Trust layer),
  app mobile Flutter `agent_wiki/` — analyze sạch, 28/28 test pass, APK debug build được.
- **Monetization:** AdMob banner (test IDs) ở Home + Page — xem `context.md` (root).
- **Git:** branch `master`, chưa có commit nào (toàn bộ đang untracked).

## Liên kết chính

- OpenSpec: `openspec/project.md` (định nghĩa sản phẩm & DoD TEST-001..011)
- App: `agent_wiki/` (README riêng tại `agent_wiki/README.md`)
- Thiết kế gốc: `.plan/plan1_final_2.md`
