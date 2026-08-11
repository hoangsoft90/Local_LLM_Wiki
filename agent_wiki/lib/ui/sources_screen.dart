import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/models.dart';
import 'state/app_state.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final sources = app.repo.listSources();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Import source',
            onPressed: () => _import(context, app),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: sources.isEmpty
            ? _EmptySources(onImport: () => _import(context, app))
            : RefreshIndicator(
                onRefresh: () async => app.refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sources.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${sources.length} source(s) — immutable & versioned',
                          style: theme.textTheme.bodySmall!
                              .copyWith(color: theme.colorScheme.outline),
                        ),
                      );
                    }
                    return _SourceTile(source: sources[i - 1]);
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _import(BuildContext context, AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || !context.mounted) return;

    try {
      final source = app.importer.importFromPath(path);
      messenger.showSnackBar(SnackBar(
        content: Text('Imported "${source.title}" v${source.version} — '
            'compiling…'),
      ));
      final compiled = await app.compiler.compile(source);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          compiled.claimsAdded > 0
              ? 'Compiled ${compiled.claimsAdded} claims into '
                  '${compiled.pagesCreated} page(s)'
              : 'Compiled with no new claims.',
        ),
      ));
      app.refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _EmptySources extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptySources({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No sources yet',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Import a markdown file (docs, notes, transcripts…) and it '
              'becomes an immutable, versioned source.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Import a source'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final SourceRecord source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.article_outlined,
              size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(source.title,
            style: theme.textTheme.bodyLarge!
                .copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'v${source.version} · sha256 ${source.shortHash()}…\n'
          '${_fmt(source.importedAt)} · ${source.content.length} chars',
          style: theme.textTheme.bodySmall!
              .copyWith(color: theme.colorScheme.outline),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
