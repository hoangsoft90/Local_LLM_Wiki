import 'enums.dart';

/// Semantic patch operation (openspec: patch-engine REQ-1).
/// The LLM never writes files directly — it emits these ops and the app
/// validates + applies them through the patch engine.
class PatchOp {
  final String op;
  final Map<String, dynamic> data;

  const PatchOp(this.op, this.data);

  factory PatchOp.createPage({
    String? pageId,
    required String title,
    required PageType pageType,
    String? body,
  }) =>
      PatchOp('create_page', {
        'page_id': ?pageId,
        'title': title,
        'page_type': pageType.wire,
        'body': ?body,
      });

  factory PatchOp.addClaim({
    required String pageId,
    required String statement,
    List<Map<String, dynamic>> evidence = const [],
    bool hypothesis = false,
  }) =>
      PatchOp('add_claim', {
        'page_id': pageId,
        'statement': statement,
        'hypothesis': hypothesis,
        'evidence': evidence,
      });

  factory PatchOp.addEvidence({
    required String claimId,
    required String sourceId,
    required int sourceVersion,
    String? location,
    required String quote,
  }) =>
      PatchOp('add_evidence', {
        'claim_id': claimId,
        'source_id': sourceId,
        'source_version': sourceVersion,
        'location': ?location,
        'quote': quote,
      });

  factory PatchOp.linkPages({
    required String sourcePageId,
    required String targetPageId,
    required LinkType linkType,
  }) =>
      PatchOp('link_pages', {
        'source_page_id': sourcePageId,
        'target_page_id': targetPageId,
        'link_type': linkType.wire,
      });

  factory PatchOp.updateClaimStatus({
    required String claimId,
    required ClaimStatus newStatus,
  }) =>
      PatchOp('update_claim_status', {
        'claim_id': claimId,
        'new_status': newStatus.wire,
      });

  factory PatchOp.deprecateClaim({
    required String claimId,
    String? reason,
  }) =>
      PatchOp('deprecate_claim', {
        'claim_id': claimId,
        'reason': ?reason,
      });

  factory PatchOp.addDecision({
    required String pageId,
    required String problem,
    required String decision,
    required String rationale,
  }) =>
      PatchOp('add_decision', {
        'page_id': pageId,
        'problem': problem,
        'decision': decision,
        'rationale': rationale,
      });

  factory PatchOp.appendSection({
    required String pageId,
    required String heading,
    required String content,
  }) =>
      PatchOp('append_section', {
        'page_id': pageId,
        'heading': heading,
        'content': content,
      });

  Map<String, dynamic> toJson() => {'op': op, ...data};

  static PatchOp fromJson(Map<String, dynamic> j) =>
      PatchOp(j['op'] as String, {...j}..remove('op'));
}
