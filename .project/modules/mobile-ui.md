# Module: Mobile UI

Vị trí: `agent_wiki/lib/ui/` · spec: `openspec/capabilities/mobile-ui`

## Shell & điều hướng

- `app_shell.dart` — `NavigationBar` 5 tab (IndexedStack giữ state): Home · Ask ·
  Inbox (badge pending count) · Sources · Settings.
- `AppShellState.switchTab(tab)` — cho Home "Ask/Inbox" quick actions.
- `AppState` (ChangeNotifier + provider) — khởi tạo repo/services khi app start,
  `reloadServices()` sau khi đổi key/model.

## Screens

| Screen | File | Nội dung |
|---|---|---|
| Home | `home_screen.dart` | stats, search bar (→ SearchScreen), quick actions Ask/Import/Inbox, recent pages, empty state |
| Ask | `ask_screen.dart` | hội thoại Q/A, markdown, citation chips (tap → page), Save to wiki → inbox |
| Page | `page_screen.dart` | markdown body, type chip, claim cards + evidence + staleness warning, links, audit trail (revisions), deprecate menu |
| Search | `search_screen.dart` | FTS BM25, snippet highlight |
| Inbox | `inbox_screen.dart` | draft cards: ops preview, corroboration note, Accept/Reject/Force-accept, reject dialog |
| Sources | `sources_screen.dart` | list source (version/hash), import → compile với snackbar progress |
| Settings | `settings_screen.dart` | API key (obscured) + save, primary/corroboration model dropdowns, wiki path, Export, Rebuild index, about |

## Widgets

- `StatusBadge` — màu theo verification hierarchy (xem `patterns.md §8`).
- `ClaimCard` — statement + badge + author/time + evidence lines + `⚠ evidence source changed`.
- `MarkdownBody` từ `flutter_markdown` (dùng trực tiếp trong screen).
- `AdBanner` — AdMob banner (cuối Home + Page); KHÔNG đặt trên Ask (AdMob policy LLM content).

## Conventions

- Material 3, `ColorScheme.fromSeed` (light + dark, themeMode system).
- Mọi lỗi AI/import hiển thị qua SnackBar — không im lặng.
- Hành động destructive (deprecate, rebuild) đều có confirm dialog.
- Không gọi service trực tiếp bằng tay trong widget ngoài `context.read<AppState>()`.
