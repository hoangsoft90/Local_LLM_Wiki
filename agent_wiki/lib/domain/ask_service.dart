import '../ai/llm_provider.dart';
import '../ai/output_parser.dart';
import '../ai/prompts.dart';
import '../core/models/answer_result.dart';
import '../core/models/draft_bundle.dart';
import '../core/models/models.dart';
import '../core/util/util.dart';
import '../data/wiki_repository.dart';
import 'settings_service.dart';

/// Ask: retrieve knowledge (FTS5 BM25) → answer with citations
/// (openspec: ask capability). Never re-verifies claims (TEST-010).
class AskService {
  final WikiRepository repo;
  final LlmProvider llm;
  final SettingsService settings;

  AskService(this.repo, this.llm, this.settings);

  static const noKnowledgeMessage =
      'The wiki has no knowledge about this yet. '
      'Import a source to start building knowledge.';

  /// Answer a question using wiki knowledge only.
  Future<AnswerResult> ask(String question) async {
    final hits = repo.search(question, limit: 8);
    if (hits.isEmpty) {
      return const AnswerResult(answer: noKnowledgeMessage);
    }
    final knowledge = _buildKnowledge(hits);
    final p = Prompts.ask(question, knowledge);
    final model = await settings.primaryModel();
    final raw = await llm.structured(
        system: p.system, user: p.user, model: model);

    repo.logAiRun({
      'op': 'ask',
      'model': model,
      'prompt_version': Prompts.promptVersion,
      'input_ids': hits.map((h) => h.pageId).toList(),
      'output_ids': <String>[],
    });

    final validIds = hits.map((h) => h.pageId).toSet();
    final validated =
        normalizeAsk(raw, validIds);
    return AnswerResult(
      answer: validated.answer.isEmpty ? noKnowledgeMessage : validated.answer,
      citations: validated.citations
          .map((c) => AnswerCitation(
                pageId: c['page_id'] as String,
                claimId: c['claim_id'] as String?,
                sourceId: c['source_id'] as String?,
                sourceVersion: c['source_version'] as int?,
              ))
          .toList(),
    );
  }

  /// Turn a saved answer into a Flow B draft bundle in the inbox.
  Future<DraftBundle> draftFromAnswer({
    required String question,
    required AnswerResult answer,
    required List<SearchHit> usedHits,
  }) async {
    final knowledge = _buildKnowledge(usedHits);
    final p = Prompts.draftPatch(
        question: question, answer: answer.answer, knowledge: knowledge);
    final model = await settings.primaryModel();
    final raw = await llm.structured(
        system: p.system, user: p.user, model: model);

    repo.logAiRun({
      'op': 'draft_patch',
      'model': model,
      'prompt_version': Prompts.promptVersion,
      'input_ids': usedHits.map((h) => h.pageId).toList(),
      'output_ids': <String>[],
    });

    final ops = parseDraftOps(raw);
    final bundle = DraftBundle(
      id: newId(),
      originOp: 'ask_save',
      question: question,
      answer: answer.answer,
      ops: ops,
      reason: 'Saved answer from Ask',
      model: model,
      createdAt: DateTime.parse(nowIso()),
    );
    repo.saveDraft(bundle);
    return bundle;
  }

  /// Build the KNOWLEDGE context block from search hits.
  String _buildKnowledge(List<SearchHit> hits) {
    final buf = StringBuffer();
    for (final hit in hits) {
      final page = repo.getPage(hit.pageId);
      if (page == null) continue;
      buf.writeln('[${page.title}] (${page.pageType.label})');
      buf.writeln('page_id: ${page.id}');
      final body = page.markdown.replaceAll('\n', ' ').trim();
      buf.writeln('content: ${truncate(body, 600)}');
      final claims = repo.claimsForPage(page.id);
      if (claims.isNotEmpty) {
        buf.writeln('claims:');
        for (final c in claims) {
          buf.writeln('- (claim:${c.id}) ${c.statement} [${c.status.label}]');
          for (final e in c.evidence) {
            buf.writeln('    evidence: "${truncate(e.quote, 200)}" '
                '(source:${e.sourceId} v${e.sourceVersion})');
          }
        }
      }
      buf.writeln();
    }
    return buf.toString();
  }
}
