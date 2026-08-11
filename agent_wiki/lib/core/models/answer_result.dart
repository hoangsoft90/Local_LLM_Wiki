/// Result of an Ask call with validated citations.
class AnswerResult {
  final String answer;
  final List<AnswerCitation> citations;

  const AnswerResult({required this.answer, this.citations = const []});
}

class AnswerCitation {
  final String pageId;
  final String? claimId;
  final String? sourceId;
  final int? sourceVersion;

  const AnswerCitation({
    required this.pageId,
    this.claimId,
    this.sourceId,
    this.sourceVersion,
  });
}

/// Outcome of a compile run (Flow A).
class CompileResult {
  final int pagesCreated;
  final int claimsAdded;
  final List<String> pageIds;

  const CompileResult({
    this.pagesCreated = 0,
    this.claimsAdded = 0,
    this.pageIds = const [],
  });
}

/// Outcome of accepting a draft bundle (Flow B).
class AcceptResult {
  final bool applied;
  final bool corroborated;
  final String? note;

  const AcceptResult({
    this.applied = false,
    this.corroborated = false,
    this.note,
  });
}
