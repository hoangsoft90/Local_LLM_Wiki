import '../ai/llm_provider.dart';
import '../ai/output_parser.dart';
import '../ai/prompts.dart';
import '../core/models/answer_result.dart';
import '../core/models/draft_bundle.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/models/patch_op.dart';
import '../core/util/util.dart';
import '../data/wiki_repository.dart';
import 'patch_engine.dart';
import 'settings_service.dart';

/// Promote & Inbox (Flow B): draft bundles reviewed by the author;
/// cross-model corroboration runs only here (TEST-010).
class PromoteService {
  final WikiRepository repo;
  final LlmProvider llm;
  final SettingsService settings;

  PromoteService(this.repo, this.llm, this.settings);

  List<DraftBundle> listDrafts() => repo.listDrafts();

  int pendingCount() => repo.pendingDraftCount();

  /// Accept a draft: run corroboration when required, then apply via the
  /// patch engine (actor = human).
  Future<AcceptResult> accept(DraftBundle draft) async {
    final sourceIds = _sourceIdsIn(draft);
    var corroborated = true;
    String? note;

    if (draft.needsCorroboration(sourceIds)) {
      final result = await _corroborate(draft, sourceIds);
      corroborated = result.corroborated;
      note = result.notes;
      draft.corroborationNote = note;
      if (!corroborated) {
        draft.needsReview = true;
        repo.updateDraft(draft);
        return AcceptResult(
          applied: false,
          corroborated: false,
          note: 'Corroboration failed: $note',
        );
      }
    }

    try {
      repo.applyOps(draft.ops, actor: Author.human);
    } on PatchException catch (e) {
      return AcceptResult(applied: false, note: e.message);
    } catch (e) {
      return AcceptResult(applied: false, note: '$e');
    }

    draft.status = DraftStatus.accepted;
    draft.corroborationNote = note;
    repo.updateDraft(draft);
    return AcceptResult(applied: true, corroborated: true, note: note);
  }

  /// Force-accept a bundle flagged needs_review (human override).
  Future<AcceptResult> forceAccept(DraftBundle draft) async {
    try {
      repo.applyOps(draft.ops, actor: Author.human);
    } on PatchException catch (e) {
      return AcceptResult(applied: false, note: e.message);
    }
    draft.status = DraftStatus.accepted;
    draft.needsReview = false;
    repo.updateDraft(draft);
    return const AcceptResult(applied: true, corroborated: false);
  }

  void reject(DraftBundle draft, {String? reason}) {
    draft.status = DraftStatus.rejected;
    draft.rejectReason = reason ?? 'Rejected by author';
    repo.updateDraft(draft);
  }

  Future<CorroborationOutcome> _corroborate(
      DraftBundle draft, Set<String> sourceIds) async {
    // Corroborate the strongest claim op in the bundle.
    final statusOp = draft.ops
        .where((o) => o.op == 'update_claim_status')
        .toList();
    if (statusOp.isNotEmpty) {
      final op = statusOp.first;
      final claim = repo.getClaim(op.data['claim_id'] as String);
      if (claim != null) {
        return _runCorroboration(claim.statement, claim.evidence);
      }
    }
    final addClaimOp =
        draft.ops.where((o) => o.op == 'add_claim').toList();
    if (addClaimOp.isNotEmpty) {
      final op = addClaimOp.first;
      final evidence = _evidenceFromOp(op, sourceIds);
      return _runCorroboration(op.data['statement'] as String, evidence);
    }
    // Nothing meaningful to corroborate → pass.
    return const CorroborationOutcome(true, 'No claim to corroborate.');
  }

  Future<CorroborationOutcome> _runCorroboration(
      String statement, List<Evidence> evidence) async {
    final p = Prompts.corroborate(
        claimStatement: statement, evidence: evidence);
    final model = await settings.corroborationModel();
    final raw = await llm.structured(
        system: p.system, user: p.user, model: model);
    repo.logAiRun({
      'op': 'corroborate',
      'model': model,
      'prompt_version': Prompts.promptVersion,
      'input_ids': <String>[],
      'output_ids': <String>[],
    });
    final r = normalizeCorroboration(raw);
    return CorroborationOutcome(r.corroborated, r.notes);
  }

  List<Evidence> _evidenceFromOp(PatchOp op, Set<String> sourceIds) {
    final out = <Evidence>[];
    final raw = (op.data['evidence'] as List?) ?? const [];
    for (final e in raw) {
      final m = e as Map<String, dynamic>;
      out.add(Evidence(
        id: newId(),
        claimId: '',
        sourceId: (m['source_id'] as String?) ?? sourceIds.first,
        sourceVersion: (m['source_version'] as num?)?.toInt() ?? 1,
        location: m['location'] as String?,
        quote: (m['quote'] ?? '') as String,
      ));
    }
    return out;
  }

  Set<String> _sourceIdsIn(DraftBundle draft) {
    final ids = <String>{};
    for (final op in draft.ops) {
      final ev = (op.data['evidence'] as List?) ?? const [];
      for (final e in ev) {
        if (e is Map && e['source_id'] is String) {
          ids.add(e['source_id'] as String);
        }
      }
      if (op.op == 'add_evidence' && op.data['source_id'] is String) {
        ids.add(op.data['source_id'] as String);
      }
    }
    return ids;
  }
}

class CorroborationOutcome {
  final bool corroborated;
  final String notes;
  const CorroborationOutcome(this.corroborated, this.notes);
}
