import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../core/models/answer_result.dart';
import 'page_screen.dart';
import 'state/app_state.dart';

class _Exchange {
  final String question;
  final AnswerResult result;
  final bool saved;
  const _Exchange(this.question, this.result, this.saved);
}

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _controller = TextEditingController();
  final List<_Exchange> _exchanges = [];
  bool _busy = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _busy) return;
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _controller.clear();
    });
    try {
      final result = await app.asker.ask(q);
      if (!mounted) return;
      setState(() => _exchanges.insert(0, _Exchange(q, result, false)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ask failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(_Exchange exchange) async {
    final app = context.read<AppState>();
    setState(() => _saving = true);
    try {
      // Re-run retrieval to know which pages were used.
      final hits = app.repo.search(exchange.question, limit: 8);
      final draft = await app.asker.draftFromAnswer(
        question: exchange.question,
        answer: exchange.result,
        usedHits: hits,
      );
      if (!mounted) return;
      final idx = _exchanges.indexOf(exchange);
      setState(() => _exchanges[idx] =
          _Exchange(exchange.question, exchange.result, true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          draft.ops.isEmpty
              ? 'Nothing new to save — no draft created.'
              : 'Draft with ${draft.ops.length} ops sent to the Inbox.',
        ),
      ));
      app.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask the wiki'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _exchanges.isEmpty
                  ? _EmptyAsk()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exchanges.length,
                      itemBuilder: (_, i) =>
                          _ExchangeView(exchange: _exchanges[i],
                              onSave: () => _save(_exchanges[i]),
                              saving: _saving),
                    ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _ask(),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Ask a question…',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _ask,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAsk extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Ask anything about your wiki',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Answers use only knowledge already compiled into the wiki — '
              'with citations you can verify.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeView extends StatelessWidget {
  final _Exchange exchange;
  final VoidCallback onSave;
  final bool saving;

  const _ExchangeView(
      {required this.exchange, required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              exchange.question,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkdownBody(
                data: exchange.result.answer,
                selectable: true,
              ),
              if (exchange.result.citations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in exchange.result.citations)
                      _CitationChip(citation: c),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: saving ? null : onSave,
                    icon: exchange.saved
                        ? const Icon(Icons.check, size: 18)
                        : const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(exchange.saved
                        ? 'Saved to inbox'
                        : 'Save to wiki'),
                  ),
                  const Spacer(),
                  if (saving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CitationChip extends StatelessWidget {
  final AnswerCitation citation;
  const _CitationChip({required this.citation});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final page = app.repo.getPage(citation.pageId);
    return ActionChip(
      avatar: const Icon(Icons.link, size: 14),
      label: Text(page?.title ?? 'Page'),
      onPressed: () {
        final target = app.repo.getPage(citation.pageId);
        if (target == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageScreen(pageId: target.id)),
        );
      },
    );
  }
}
