import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/draft_bundle.dart';
import '../core/models/enums.dart';
import '../core/models/patch_op.dart';
import 'state/app_state.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final drafts = app.promoter.listDrafts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Inbox'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: drafts.isEmpty
            ? _EmptyInbox()
            : RefreshIndicator(
                onRefresh: () async => app.refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: drafts.length,
                  itemBuilder: (_, i) =>
                      _DraftCard(draft: drafts[i]),
                ),
              ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Nothing waiting for review',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Answers you save from Ask land here for your review before '
              'they are merged into the wiki.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  final DraftBundle draft;
  const _DraftCard({required this.draft});

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  bool _busy = false;

  Future<void> _accept(AppState app) async {
    setState(() => _busy = true);
    try {
      final result = await app.promoter.accept(widget.draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.applied
            ? 'Merged into wiki ✓'
            : 'Not merged: ${result.note ?? 'unknown'}'),
      ));
      app.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Accept failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forceAccept(AppState app) async {
    setState(() => _busy = true);
    try {
      await app.promoter.forceAccept(widget.draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merged anyway (human override) ✓')));
      app.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(AppState app) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(),
    );
    if (reason == null) return;
    app.promoter.reject(widget.draft, reason: reason);
    app.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final d = widget.draft;
    final theme = Theme.of(context);
    final pending = d.isPending;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: pending
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  d.originOp == 'status_upgrade'
                      ? Icons.verified_outlined
                      : Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.originOp == 'status_upgrade'
                        ? 'Status upgrade'
                        : 'Saved answer',
                    style: theme.textTheme.titleSmall!
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(status: d.status),
              ],
            ),
            if (d.question != null) ...[
              const SizedBox(height: 6),
              Text('Q: ${d.question}',
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 6),
            Text('${d.ops.length} patch op(s) · ${_ago(d.createdAt)}',
                style: theme.textTheme.bodySmall!
                    .copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 6),
            for (final op in d.ops.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${op.op}${_opPreview(op)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (d.ops.length > 3)
              Text('… and ${d.ops.length - 3} more',
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.colorScheme.outline)),
            if (d.corroborationNote != null) ...[
              const SizedBox(height: 6),
              Text('Cross-check: ${d.corroborationNote}',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: d.needsReview
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                    fontStyle: FontStyle.italic,
                  )),
            ],
            if (d.rejectReason != null) ...[
              const SizedBox(height: 6),
              Text('Rejected: ${d.rejectReason}',
                  style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic)),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _accept(app),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reject(app),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                  if (d.needsReview) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _busy ? null : () => _forceAccept(app),
                      child: const Text('Force accept'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _opPreview(PatchOp op) {
    switch (op.op) {
      case 'add_claim':
        final s = (op.data['statement'] as String?) ?? '';
        return s.length > 50 ? ' — ${s.substring(0, 50)}…' : ' — $s';
      case 'create_page':
        return ' — ${op.data['title'] ?? ''}';
      case 'update_claim_status':
        return ' → ${op.data['new_status'] ?? ''}';
      default:
        return '';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final DraftStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DraftStatus.pending => const Color(0xFF1565C0),
      DraftStatus.accepted => const Color(0xFF2E7D32),
      DraftStatus.rejected => const Color(0xFFC62828),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.wire,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject draft'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Reason (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _controller.text.trim().isEmpty ? 'Rejected' : _controller.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

String _ago(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
