import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../core/models/enums.dart';
import '../core/models/models.dart';
import 'state/app_state.dart';
import 'widgets/ad_banner.dart';
import 'widgets/claim_card.dart';

class PageScreen extends StatelessWidget {
  final String pageId;
  const PageScreen({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final page = app.repo.getPage(pageId);
    if (page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: const Center(child: Text('This page no longer exists.')),
      );
    }
    final claims = app.repo.claimsForPage(page.id);
    final links = app.repo.linksFor(page.id);
    final revisions = app.repo.listRevisions(targetId: page.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(page.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'deprecate') {
                _confirmDeprecate(context, app, page);
              }
            },
            itemBuilder: (_) => [
              if (!page.deprecated)
                const PopupMenuItem(
                  value: 'deprecate',
                  child: Text('Deprecate page'),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _TypeChip(label: page.pageType.label),
                if (page.deprecated) ...[
                  const SizedBox(width: 8),
                  const _TypeChip(label: 'Deprecated', warning: true),
                ],
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: page.markdown,
              selectable: true,
            ),
            const SizedBox(height: 24),
            Text('Claims (${claims.length})',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (claims.isEmpty)
              Text('No claims on this page yet.',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.outline)),
            for (final c in claims) ...[
              ClaimCard(claim: c, repo: app.repo),
              const SizedBox(height: 8),
            ],
            if (links.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Links',
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final link in links)
                    _LinkChip(link: link, currentId: page.id),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Audit trail (${revisions.length} revisions)',
                  style: theme.textTheme.labelLarge),
              children: [
                for (final r in revisions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      r.targetType == RevisionTargetType.claim
                          ? Icons.fact_check_outlined
                          : Icons.description_outlined,
                      size: 18,
                    ),
                    title: Text(
                      r.patchJson,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    subtitle: Text(_fmt(r.createdAt)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeprecate(
      BuildContext context, AppState app, PageRecord page) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deprecate page?'),
        content: Text(
            '"${page.title}" stays on disk but will be marked deprecated '
            'and struck through everywhere.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deprecate')),
        ],
      ),
    );
    if (ok == true) {
      app.repo.deprecatePage(page.id);
      app.refresh();
    }
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool warning;
  const _TypeChip({required this.label, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFC62828) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final LinkRecord link;
  final String currentId;
  const _LinkChip({required this.link, required this.currentId});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final targetId = link.sourcePageId == currentId
        ? link.targetPageId
        : link.sourcePageId;
    final page = app.repo.getPage(targetId);
    return ActionChip(
      avatar: Icon(switch (link.linkType) {
        LinkType.supports => Icons.thumb_up_outlined,
        LinkType.refutes => Icons.thumb_down_outlined,
        LinkType.supersedes => Icons.fast_forward_outlined,
        LinkType.related => Icons.link,
      }, size: 14),
      label: Text('${link.linkType.wire} · ${page?.title ?? 'page'}'),
      onPressed: () {
        if (page == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageScreen(pageId: page.id)),
        );
      },
    );
  }
}
