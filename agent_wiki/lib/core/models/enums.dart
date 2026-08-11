/// Domain enums for AgentWiki, mirroring the frozen schema in
/// openspec/project.md §3 and the claims capability spec.
library;

enum PageType {
  concept('concept', 'Concept'),
  summary('summary', 'Summary'),
  decision('decision', 'Decision'),
  hypothesis('hypothesis', 'Hypothesis'),
  rejected('rejected', 'Rejected'),
  note('note', 'Note');

  final String wire;
  final String label;

  const PageType(this.wire, this.label);

  static PageType fromWire(String s) => values.firstWhere(
        (e) => e.wire == s,
        orElse: () => PageType.note,
      );
}

enum ClaimStatus {
  unverified('unverified', '⚠ Hypothesis'),
  supported('supported', 'Supported'),
  crossChecked('cross_checked', 'Cross-checked'),
  humanVerified('human_verified', '✓ Human verified'),
  contradicted('contradicted', 'Contradicted'),
  deprecated('deprecated', 'Deprecated');

  final String wire;
  final String label;

  const ClaimStatus(this.wire, this.label);

  static ClaimStatus fromWire(String s) => values.firstWhere(
        (e) => e.wire == s,
        orElse: () => ClaimStatus.unverified,
      );
}

enum Author {
  human('human'),
  agent('agent');

  final String wire;

  const Author(this.wire);

  static Author fromWire(String s) =>
      s == 'human' ? Author.human : Author.agent;
}

enum LinkType {
  related('related'),
  refutes('refutes'),
  supports('supports'),
  supersedes('supersedes');

  final String wire;

  const LinkType(this.wire);

  static LinkType fromWire(String s) => values.firstWhere(
        (e) => e.wire == s,
        orElse: () => LinkType.related,
      );
}

enum RevisionTargetType {
  page('page'),
  claim('claim');

  final String wire;

  const RevisionTargetType(this.wire);

  static RevisionTargetType fromWire(String s) =>
      s == 'claim' ? RevisionTargetType.claim : RevisionTargetType.page;
}

enum DraftStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  final String wire;

  const DraftStatus(this.wire);

  static DraftStatus fromWire(String s) => values.firstWhere(
        (e) => e.wire == s,
        orElse: () => DraftStatus.pending,
      );
}

/// Template headings per page_type — stable targets for semantic patches
/// (openspec: patch-engine REQ-2).
const Map<PageType, List<String>> pageTypeTemplates = {
  PageType.concept: ['Summary', 'Details'],
  PageType.summary: ['Sources covered', 'Key points'],
  PageType.decision: ['Problem', 'Decision', 'Rationale'],
  PageType.hypothesis: ['Hypothesis', 'Evidence', 'Status'],
  PageType.rejected: ['Idea', 'Why rejected'],
  PageType.note: ['Note'],
};

/// Markdown section headings (e.g. '## Summary') for a page type.
List<String> templateHeadings(PageType type) =>
    pageTypeTemplates[type]!.map((h) => '## $h').toList();
