import 'dart:convert';

import '../core/models/enums.dart';
import '../core/models/patch_op.dart';

/// Output parser (openspec: ai-provider REQ-7, TEST-011).
///
/// Extracts the first well-formed JSON object from model output, strips
/// surrounding prose/fences, and validates against per-op schemas. It never
/// follows instructions embedded in source content — data is validated, not
/// executed.

/// Pull the first balanced JSON object out of a text blob.
Map<String, dynamic>? extractJsonObject(String text) {
  var t = text.trim();
  // Strip fenced code blocks.
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(t);
  if (fence != null) {
    t = fence.group(1)!.trim();
  }
  final start = t.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < t.length; i++) {
    final c = t[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        final candidate = t.substring(start, i + 1);
        try {
          final decoded = jsonDecode(candidate);
          if (decoded is Map<String, dynamic>) return decoded;
          return null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

/// Result of compile normalization.
class NormalizedCompile {
  final List<NormalizedPage> pages;
  const NormalizedCompile(this.pages);
}

class NormalizedPage {
  final String title;
  final PageType pageType;
  final List<NormalizedClaim> claims;
  const NormalizedPage(this.title, this.pageType, this.claims);
}

class NormalizedClaim {
  final String statement;
  final bool hypothesis;
  final List<Map<String, dynamic>> evidence;
  const NormalizedClaim(this.statement, this.hypothesis, this.evidence);
}

/// Validate + normalize a compile output against the source content.
/// Evidence quotes must be verbatim substrings of the source (TEST-002,
/// REQ-2). Claims without evidence and not flagged hypothesis are dropped.
NormalizedCompile normalizeCompile(Map<String, dynamic> raw, String source) {
  final pages = <NormalizedPage>[];
  final rawPages = (raw['pages'] as List<dynamic>?) ?? const [];
  for (final rp in rawPages) {
    if (rp is! Map<String, dynamic>) continue;
    final title = (rp['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final pageType = _safePageType(rp['page_type']);
    final claims = <NormalizedClaim>[];
    final rawClaims = (rp['claims'] as List<dynamic>?) ?? const [];
    for (final rc in rawClaims) {
      if (rc is! Map<String, dynamic>) continue;
      final statement = (rc['statement'] as String?)?.trim() ?? '';
      if (statement.isEmpty) continue;
      final hypothesis = (rc['hypothesis'] ?? false) == true;
      final evidence = <Map<String, dynamic>>[];
      final rawEv = (rc['evidence'] as List<dynamic>?) ?? const [];
      for (final re in rawEv) {
        if (re is! Map<String, dynamic>) continue;
        final quote = (re['quote'] as String?)?.trim() ?? '';
        if (quote.isEmpty) continue;
        // Injection defense: quote must actually appear in the source.
        if (!source.contains(quote)) continue;
        evidence.add({
          'location': re['location'] as String?,
          'quote': quote,
        });
      }
      if (!hypothesis && evidence.isEmpty) continue;
      claims.add(NormalizedClaim(statement, hypothesis, evidence));
    }
    if (claims.isEmpty && pageType != PageType.summary) {
      // Still create the page shell if it has claims elsewhere; skip empty.
      continue;
    }
    pages.add(NormalizedPage(title, pageType, claims));
  }
  return NormalizedCompile(pages);
}

PageType _safePageType(dynamic v) {
  if (v is! String) return PageType.note;
  for (final t in PageType.values) {
    if (t.wire == v) return t;
  }
  return PageType.note;
}

/// Validate an ask output: citations must reference actually-retrieved pages.
({String answer, List<Map<String, dynamic>> citations}) normalizeAsk(
    Map<String, dynamic> raw, Set<String> validPageIds) {
  final answer = (raw['answer'] as String?)?.trim() ?? '';
  final citations = <Map<String, dynamic>>[];
  final rawCits = (raw['citations'] as List<dynamic>?) ?? const [];
  for (final rc in rawCits) {
    if (rc is! Map<String, dynamic>) continue;
    final pageId = (rc['page_id'] as String?) ?? '';
    if (pageId.isEmpty || !validPageIds.contains(pageId)) continue;
    citations.add({
      'page_id': pageId,
      'claim_id': rc['claim_id'] as String?,
      'source_id': rc['source_id'] as String?,
      'source_version': rc['source_version'] as int?,
    });
  }
  return (answer: answer, citations: citations);
}

/// Parse a draft-patch output into validated ops (unknown/malformed dropped).
List<PatchOp> parseDraftOps(Map<String, dynamic> raw) {
  final ops = <PatchOp>[];
  final rawOps = (raw['ops'] as List<dynamic>?) ?? const [];
  for (final ro in rawOps) {
    if (ro is! Map<String, dynamic>) continue;
    final op = ro['op'] as String?;
    if (op == null) continue;
    switch (op) {
      case 'create_page':
        final title = (ro['title'] as String?) ?? '';
        final type = _safePageType(ro['page_type']);
        if (title.isEmpty) continue;
        ops.add(PatchOp.createPage(
            pageId: ro['page_id'] as String?,
            title: title,
            pageType: type,
            body: ro['body'] as String?));
        break;
      case 'add_claim':
        final pageId = (ro['page_id'] as String?) ?? '';
        final statement = (ro['statement'] as String?) ?? '';
        if (pageId.isEmpty || statement.isEmpty) continue;
        ops.add(PatchOp.addClaim(
          pageId: pageId,
          statement: statement,
          hypothesis: (ro['hypothesis'] ?? false) == true,
          evidence: ((ro['evidence'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        ));
        break;
      case 'add_evidence':
        final claimId = (ro['claim_id'] as String?) ?? '';
        final sourceId = (ro['source_id'] as String?) ?? '';
        final quote = (ro['quote'] as String?) ?? '';
        if (claimId.isEmpty || sourceId.isEmpty || quote.isEmpty) continue;
        ops.add(PatchOp.addEvidence(
          claimId: claimId,
          sourceId: sourceId,
          sourceVersion: (ro['source_version'] as num?)?.toInt() ?? 1,
          location: ro['location'] as String?,
          quote: quote,
        ));
        break;
      case 'link_pages':
        ops.add(PatchOp.linkPages(
          sourcePageId: (ro['source_page_id'] as String?) ?? '',
          targetPageId: (ro['target_page_id'] as String?) ?? '',
          linkType: LinkType.fromWire((ro['link_type'] as String?) ?? 'related'),
        ));
        break;
      case 'update_claim_status':
        ops.add(PatchOp.updateClaimStatus(
          claimId: (ro['claim_id'] as String?) ?? '',
          newStatus: ClaimStatus.fromWire((ro['new_status'] as String?) ?? ''),
        ));
        break;
      case 'deprecate_claim':
        ops.add(PatchOp.deprecateClaim(
          claimId: (ro['claim_id'] as String?) ?? '',
          reason: ro['reason'] as String?,
        ));
        break;
      case 'add_decision':
        ops.add(PatchOp.addDecision(
          pageId: (ro['page_id'] as String?) ?? '',
          problem: (ro['problem'] as String?) ?? '',
          decision: (ro['decision'] as String?) ?? '',
          rationale: (ro['rationale'] as String?) ?? '',
        ));
        break;
      case 'append_section':
        ops.add(PatchOp.appendSection(
          pageId: (ro['page_id'] as String?) ?? '',
          heading: (ro['heading'] as String?) ?? '',
          content: (ro['content'] as String?) ?? '',
        ));
        break;
      default:
        break; // unknown op → stripped
    }
  }
  return ops;
}

/// Validate a corroboration output.
({bool corroborated, String notes}) normalizeCorroboration(
    Map<String, dynamic> raw) {
  final corroborated = (raw['corroborated'] ?? false) == true;
  final notes = (raw['notes'] as String?) ?? '';
  return (corroborated: corroborated, notes: notes);
}
