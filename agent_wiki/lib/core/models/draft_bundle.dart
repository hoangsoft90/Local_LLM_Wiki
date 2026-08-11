import 'enums.dart';
import 'patch_op.dart';

/// A Flow B draft bundle sitting in the Knowledge Inbox.
/// originOp: 'ask_save' | 'status_upgrade'
class DraftBundle {
  final String id;
  final String originOp;
  final String? question;
  final String? answer;
  final List<PatchOp> ops;
  final String reason;
  final String model;
  final DateTime createdAt;
  DraftStatus status;
  String? rejectReason;
  bool needsReview;
  String? corroborationNote;

  DraftBundle({
    required this.id,
    required this.originOp,
    this.question,
    this.answer,
    required this.ops,
    this.reason = '',
    this.model = '',
    required this.createdAt,
    this.status = DraftStatus.pending,
    this.rejectReason,
    this.needsReview = false,
    this.corroborationNote,
  });

  bool get isPending => status == DraftStatus.pending;

  /// True when cross-model corroboration must run before promote
  /// (openspec promote REQ-6): status upgrades to a higher trust level, or
  /// answers synthesized from ≥2 distinct sources. Trivial ops like
  /// `link_pages` / `deprecate_claim` never trigger it.
  bool needsCorroboration(Set<String> sourceIds) {
    final upgradesTrust = ops.any((o) {
      if (o.op != 'update_claim_status') return false;
      final s = ClaimStatus.fromWire((o.data['new_status'] as String?) ?? '');
      return s == ClaimStatus.crossChecked ||
          s == ClaimStatus.humanVerified;
    });
    if (upgradesTrust) return true;
    if (sourceIds.length >= 2) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin_op': originOp,
        'question': question,
        'answer': answer,
        'ops': ops.map((o) => o.toJson()).toList(),
        'reason': reason,
        'model': model,
        'created_at': createdAt.toIso8601String(),
        'status': status.wire,
        'reject_reason': rejectReason,
        'needs_review': needsReview,
        'corroboration_note': corroborationNote,
      };

  static DraftBundle fromJson(Map<String, dynamic> j) => DraftBundle(
        id: (j['id'] ?? '') as String,
        originOp: (j['origin_op'] ?? 'ask_save') as String,
        question: j['question'] as String?,
        answer: j['answer'] as String?,
        ops: (j['ops'] as List<dynamic>? ?? [])
            .map((o) => PatchOp.fromJson(o as Map<String, dynamic>))
            .toList(),
        reason: (j['reason'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        status: DraftStatus.fromWire((j['status'] ?? 'pending') as String),
        rejectReason: j['reject_reason'] as String?,
        needsReview: (j['needs_review'] ?? false) as bool,
        corroborationNote: j['corroboration_note'] as String?,
      );
}
