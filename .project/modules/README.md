# AgentWiki — Modules

Chi tiết từng vùng code trong `agent_wiki/lib/`.

| Module | Vị trí | Đọc khi nào |
|---|---|---|
| [storage-engine](storage-engine.md) | `data/` (`wiki_store.dart`, `database.dart`, `wiki_repository.dart`) | sửa storage/index/rebuild/export |
| [patch-engine](patch-engine.md) | `domain/patch_engine.dart` + `core/models/patch_op.dart` | sửa mutation/ops/templates |
| [ai-layer](ai-layer.md) | `ai/` + `domain/{compile,ask,promote,settings,import}_service.dart` | sửa LLM/prompt/parser/luồng AI |
| [mobile-ui](mobile-ui.md) | `ui/` | sửa màn hình/theme/widgets |
| [core](core.md) | `core/models/`, `core/util/` | model/enum/util chung |
