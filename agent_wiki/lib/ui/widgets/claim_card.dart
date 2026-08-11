import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../data/wiki_repository.dart';
import 'status_badge.dart';

/// A claim card: statement + status badge + evidence quotes with source
/// staleness warnings (claims spec REQ-6, sources spec REQ-6).
class ClaimCard extends StatelessWidget {
  final Claim claim;
  final WikiRepository repo;

  const ClaimCard({super.key, required this.claim, required this.repo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deprecated = claim.status == ClaimStatus.deprecated;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    claim.statement,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          deprecated ? TextDecoration.lineThrough : null,
                      color: deprecated
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(claim.status, small: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'by ${claim.author.wire} · ${_fmt(claim.updatedAt)}',
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (claim.evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final e in claim.evidence) _EvidenceLine(repo: repo, e: e),
            ],
          ],
        ),
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

class _EvidenceLine extends StatelessWidget {
  final WikiRepository repo;
  final Evidence e;

  const _EvidenceLine({required this.repo, required this.e});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = repo.getSource(e.sourceId);
    final stale =
        source != null && e.sourceVersion < source.version;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${e.quote}”',
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '— ${source?.title ?? e.sourceId} v${e.sourceVersion}'
            '${e.location != null ? ' · ${e.location}' : ''}',
            style: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (stale)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 12, color: Color(0xFFB26A00)),
                  const SizedBox(width: 4),
                  Text(
                    '⚠ evidence source changed (now v${source.version})',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: const Color(0xFFB26A00),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
