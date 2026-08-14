import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/app_shell.dart';
import 'ui/guidance/guidance_state.dart';
import 'ui/page_screen.dart';
import 'ui/state/app_state.dart';

class AgentWikiApp extends StatelessWidget {
  const AgentWikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        // In-app guidance state (onboarding tours, feature badges).
        ChangeNotifierProvider(create: (_) => GuidanceController()..init()),
      ],
      child: MaterialApp(
        title: 'AgentWiki',
        debugShowCheckedModeBanner: false,
        // Deep-link / initial-route handling (web URL `#/…`, Android intent,
        // reload). Không có route table → mọi path lạ hiện đang crash với
        // "Could not find a generator for route". Ở đây:
        //   `/page/<id>` → PageScreen (quay về page qua deep link),
        //   mọi path khác/rỗng → AppHome (không bao giờ điểm chết).
        onGenerateRoute: buildAppRoute,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A5CE0),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(centerTitle: false),
          cardTheme: const CardThemeData(elevation: 0),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8A9BFF),
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(centerTitle: false),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const AppHome(),
      ),
    );
  }
}

/// Route builder cho deep links — luôn trả về một route hợp lệ, không bao
/// giờ trả null (không để Navigator rơi vào "no route generator").
Route<dynamic>? buildAppRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  final pageId = deepLinkPageId(name);
  if (pageId != null) {
    // `/page/<id>` — deep link quay về một page cụ thể (web/initial route).
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => DeepLinkPage(pageId: pageId),
    );
  }
  // Mọi path khác (kể cả `/` và path không rõ) → home. Không bao giờ để
  // Navigator rơi vào "no route generator" (điểm chết trên web reload).
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => const AppHome(),
  );
}

/// Trích page id từ route name deep link: `page/<id>` hoặc `/page/<id>`
/// (URL-encoded). Trả null khi không phải deep link page.
String? deepLinkPageId(String routeName) {
  final match = RegExp(r'^/?page/(.+)$').firstMatch(routeName);
  if (match == null) return null;
  final id = Uri.decodeComponent(match.group(1)!);
  return id.isEmpty ? null : id;
}

/// Deep-link gate: giống [AppHome] — PageScreen đọc `app.repo` (late), nếu
/// build trước khi `AppState.init()` xong sẽ `LateInitializationError`. Route
/// `/page/<id>` là INITIAL route (web/deep link) → phải chờ init như home.
class DeepLinkPage extends StatelessWidget {
  final String pageId;
  const DeepLinkPage({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.error != null) {
      return _InitErrorScreen(message: app.error!);
    }
    if (!app.initialized) {
      return const _SplashScreen();
    }
    return PageScreen(pageId: pageId);
  }
}

/// Gate: chỉ render AppShell khi init (mở wiki + services) xong — tránh
/// `LateInitializationError` do UI chạm `app.repo` trước khi khởi tạo.
class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.error != null) {
      return _InitErrorScreen(message: app.error!);
    }
    if (!app.initialized) {
      return const _SplashScreen();
    }
    return const AppShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('AgentWiki',
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text('Opening your wiki…',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.outline,
                )),
          ],
        ),
      ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  final String message;
  const _InitErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Không thể mở wiki',
                    style: theme.textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final app = context.read<AppState>();
                    app.retryInit();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
