import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/models/models.dart';
import '../ui/state/app_state.dart';
import 'app_shell.dart';
import 'page_screen.dart';
import 'search_screen.dart';
import 'widgets/ad_banner.dart';

/// Onboarding targets — attached to the Home quick-action buttons so the
/// first-run spotlight tour can highlight them (see app_shell.dart).
final GlobalKey onboardingAskKey = GlobalKey();
final GlobalKey onboardingImportKey = GlobalKey();
final GlobalKey onboardingInboxKey = GlobalKey();

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => app.refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.meta.name,
                            style: theme.textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${app.pageCount} pages · ${app.claimCount} claims · '
                          '${app.sourceCount} sources',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LlmChip(providerName: app.llm.name),
                ],
              ),
              const SizedBox(height: 16),
              _SearchField(),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Ask',
                    color: theme.colorScheme.primary,
                    highlightKey: onboardingAskKey,
                    onTap: () => _goToTab(context, 1),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.file_download_outlined,
                    label: 'Import',
                    color: const Color(0xFF2E7D32),
                    highlightKey: onboardingImportKey,
                    onTap: () => _importSource(context, app),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.inbox_outlined,
                    label: 'Inbox',
                    color: const Color(0xFF6A1B9A),
                    highlightKey: onboardingInboxKey,
                    badge: app.pendingInboxCount,
                    onTap: () => _goToTab(context, 2),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent pages',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  if (app.pages.isEmpty)
                    TextButton(
                      onPressed: () => _goToTab(context, 3),
                      child: const Text('Import a source'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (app.pages.isEmpty)
                _EmptyWiki(app: app)
              else
                for (final page in app.pages.take(20)) _PageTile(page: page),
              const SizedBox(height: 16),
              const AdBanner(),
            ],
          ),
        ),
      ),
    );
  }

  void _goToTab(BuildContext context, int tab) {
    final shell = context.findAncestorStateOfType<AppShellState>();
    shell?.switchTab(tab);
  }

  Future<void> _importSource(BuildContext context, AppState app) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final source = path != null
          ? app.importer.importFromPath(path)
          : file.bytes != null
              // Web: file_picker trả bytes (không có path).
              ? app.importer.importFromBytes(
                  p.basenameWithoutExtension(file.name), file.bytes!)
              : null;
      if (source == null) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Imported "${source.title}" v${source.version} — '
            'compiling…'),
        duration: const Duration(seconds: 2),
      ));
      final compiled = await app.compiler.compile(source);
      messenger.showSnackBar(SnackBar(
        content: Text(
          compiled.claimsAdded > 0
              ? 'Compiled ${compiled.claimsAdded} claims across '
                  '${compiled.pagesCreated} pages'
              : 'Compiled with no new claims.',
        ),
      ));
      app.refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _LlmChip extends StatelessWidget {
  final String providerName;
  const _LlmChip({required this.providerName});

  @override
  Widget build(BuildContext context) {
    final onKey = providerName == 'openrouter';
    final color = onKey ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            providerName == 'openrouter'
                ? 'OpenRouter'
                : 'Demo mode (no key)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      readOnly: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      decoration: InputDecoration(
        hintText: 'Search the wiki…',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final GlobalKey? highlightKey;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.badge = 0,
    this.highlightKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: highlightKey,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 26),
                  if (badge > 0)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: theme.textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  final PageRecord page;
  const _PageTile({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageScreen(pageId: page.id)),
        ),
        title: Text(
          page.title,
          style: theme.textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.w600,
            decoration: page.deprecated ? TextDecoration.lineThrough : null,
            color: page.deprecated
                ? theme.colorScheme.outline
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          page.pageType.label,
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class _EmptyWiki extends StatelessWidget {
  final AppState app;
  const _EmptyWiki({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Your wiki is empty',
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Import a markdown source and AgentWiki will compile it into '
            'pages and evidence-backed claims — ready to be reused later.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
