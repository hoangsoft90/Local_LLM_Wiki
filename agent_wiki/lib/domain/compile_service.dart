import '../ai/llm_provider.dart';
import '../ai/output_parser.dart';
import '../ai/prompts.dart';
import '../core/models/answer_result.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/models/patch_op.dart';
import '../core/util/util.dart';
import '../data/wiki_repository.dart';
import 'settings_service.dart';

/// Compile (Flow A): one source → pages + claims (status ≤ supported),
/// merged directly, no inbox (openspec: compile capability).
class CompileService {
  final WikiRepository repo;
  final LlmProvider llm;
  final SettingsService settings;

  CompileService(this.repo, this.llm, this.settings);

  /// Compile a source into the wiki. Returns what was created.
  Future<CompileResult> compile(SourceRecord source) async {
    final p = Prompts.compile(source);
    final model = await settings.primaryModel();
    final raw = await llm.structured(
        system: p.system, user: p.user, model: model);

    repo.logAiRun({
      'op': 'compile',
      'model': model,
      'prompt_version': Prompts.promptVersion,
      'input_ids': [source.id],
      'output_ids': <String>[],
    });

    final normalized = normalizeCompile(raw, source.content);
    if (normalized.pages.isEmpty) {
      return const CompileResult();
    }

    final ops = <PatchOp>[];
    final pageIds = <String>[];
    var claimCount = 0;

    for (final np in normalized.pages) {
      final existing = repo.getPageByTitle(np.title);
      final pageId = existing?.id ?? newId();
      if (existing == null) {
        ops.add(PatchOp.createPage(
          pageId: pageId,
          title: np.title,
          pageType: np.pageType,
        ));
        pageIds.add(pageId);
      }
      for (final claim in np.claims) {
        final evidence = claim.evidence.map((e) {
          return {
            'source_id': source.id,
            'source_version': source.version,
            'location': e['location'],
            'quote': e['quote'],
          };
        }).toList();
        ops.add(PatchOp.addClaim(
          pageId: pageId,
          statement: claim.statement,
          hypothesis: claim.hypothesis,
          evidence: evidence,
        ));
        claimCount++;
      }
    }

    if (ops.isEmpty) return const CompileResult();
    repo.applyOps(ops, actor: Author.agent);
    return CompileResult(
      pagesCreated: pageIds.length,
      claimsAdded: claimCount,
      pageIds: pageIds,
    );
  }
}
