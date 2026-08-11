import 'dart:convert';

import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/models/patch_op.dart';
import '../core/util/util.dart';
import '../data/wiki_repository.dart';

class PatchException implements Exception {
  final String message;
  PatchException(this.message);

  @override
  String toString() => 'PatchException: $message';
}

/// The semantic patch engine — the ONLY way pages/claims mutate
/// (openspec: patch-engine capability).
class PatchEngine {
  final WikiRepository repo;

  PatchEngine(this.repo);

  /// Validate + apply one op. Returns the recorded revision.
  Revision applyOp(PatchOp op, {required Author actor}) {
    switch (op.op) {
      case 'create_page':
        return _createPage(op, actor);
      case 'add_claim':
        return _addClaim(op, actor);
      case 'add_evidence':
        return _addEvidence(op);
      case 'link_pages':
        return _linkPages(op);
      case 'update_claim_status':
        return _updateClaimStatus(op, actor);
      case 'deprecate_claim':
        return _deprecateClaim(op);
      case 'add_decision':
        return _addDecision(op);
      case 'append_section':
        return _appendSection(op);
      default:
        throw PatchException('Unknown op: ${op.op}');
    }
  }

  // ---------- ops ----------

  Revision _createPage(PatchOp op, Author actor) {
    final title = _reqStr(op, 'title');
    final type = PageType.fromWire(_reqStr(op, 'page_type'));
    final id = (op.data['page_id'] as String?) ?? newId();
    if (repo.getPage(id) != null) {
      throw PatchException('Page already exists: $id');
    }
    if (repo.getPageByTitle(title) != null) {
      throw PatchException('Page with title already exists: $title');
    }
    var body = (op.data['body'] as String?)?.trim() ?? '';
    // Seed + guarantee template headings (REQ-2/REQ-4).
    for (final h in templateHeadings(type)) {
      final name = h.replaceFirst(RegExp(r'^#+\s*'), '');
      if (!_hasHeading(body, name)) {
        body = body.isEmpty ? h : '$body\n\n$h';
      }
    }
    final now = nowIso();
    final page = PageRecord(
      id: id,
      title: title,
      filename: pageFilename(title, id),
      pageType: type,
      markdown: body.trim(),
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
    repo.store.writePage(page);
    repo.index.insertPage(page);
    return _record(RevisionTargetType.page, id, op);
  }

  Revision _addClaim(PatchOp op, Author actor) {
    final pageId = _reqStr(op, 'page_id');
    final statement = _reqStr(op, 'statement');
    final page = _requirePage(pageId);
    final hypothesis = (op.data['hypothesis'] ?? false) as bool;
    final rawEvidence = (op.data['evidence'] as List?) ?? const [];

    final evidence = <Evidence>[];
    for (final e in rawEvidence) {
      final m = e as Map<String, dynamic>;
      final sourceId = m['source_id'] as String;
      final quote = (m['quote'] ?? '') as String;
      if (quote.trim().isEmpty) continue;
      final src = repo.getSource(sourceId);
      if (src == null) {
        throw PatchException('Unknown source: $sourceId');
      }
      // Knowledge Contract: evidence quotes must be verbatim substrings of
      // the referenced source (both Flow A and Flow B — TEST-011 semantics).
      if (!src.content.contains(quote)) {
        throw PatchException(
            'Evidence quote is not a verbatim substring of source $sourceId');
      }
      evidence.add(Evidence(
        id: newId(),
        claimId: '',
        sourceId: sourceId,
        sourceVersion: (m['source_version'] as num?)?.toInt() ?? src.version,
        location: m['location'] as String?,
        quote: quote,
      ));
    }

    final status = hypothesis
        ? ClaimStatus.unverified
        : (evidence.isNotEmpty
            ? ClaimStatus.supported
            : throw PatchException(
                'add_claim requires evidence unless hypothesis=true'));

    final now = nowIso();
    final claimId = newId();
    final claim = Claim(
      id: claimId,
      pageId: pageId,
      statement: statement,
      status: status,
      author: actor,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
      evidence: evidence
          .map((e) => Evidence(
                id: e.id,
                claimId: claimId,
                sourceId: e.sourceId,
                sourceVersion: e.sourceVersion,
                location: e.location,
                quote: e.quote,
              ))
          .toList(),
    );

    repo.store.writeClaim(claim);
    repo.index.insertClaim(claim);
    // Keep page frontmatter claim_ids in sync.
    final updatedPage = page.copyWith(
      claimIds: [...page.claimIds, claim.id],
      updatedAt: DateTime.parse(now),
    );
    repo.store.writePage(updatedPage);
    repo.index.updatePage(updatedPage);
    return _record(RevisionTargetType.claim, claim.id, op);
  }

  Revision _addEvidence(PatchOp op) {
    final claimId = _reqStr(op, 'claim_id');
    final claim = _requireClaim(claimId);
    final sourceId = _reqStr(op, 'source_id');
    final quote = _reqStr(op, 'quote');
    final source = repo.getSource(sourceId);
    if (source == null) {
      throw PatchException('Unknown source: $sourceId');
    }
    if (!source.content.contains(quote)) {
      throw PatchException(
          'Evidence quote is not a verbatim substring of source $sourceId');
    }
    final version = (op.data['source_version'] as num?)?.toInt() ??
        source.version;
    final evidence = Evidence(
      id: newId(),
      claimId: claimId,
      sourceId: sourceId,
      sourceVersion: version,
      location: op.data['location'] as String?,
      quote: quote,
    );
    final updated = claim.copyWith(
      evidence: [...claim.evidence, evidence],
      updatedAt: DateTime.parse(nowIso()),
    );
    repo.store.writeClaim(updated);
    repo.index.updateClaim(updated);
    return _record(RevisionTargetType.claim, claimId, op);
  }

  Revision _linkPages(PatchOp op) {
    final sourcePage = _requirePage(_reqStr(op, 'source_page_id'));
    final targetPage = _requirePage(_reqStr(op, 'target_page_id'));
    final linkType = LinkType.fromWire(_reqStr(op, 'link_type'));
    repo.index.insertLink(LinkRecord(
      sourcePageId: sourcePage.id,
      targetPageId: targetPage.id,
      linkType: linkType,
      createdAt: DateTime.parse(nowIso()),
    ));
    return _record(RevisionTargetType.page, sourcePage.id, op);
  }

  Revision _updateClaimStatus(PatchOp op, Author actor) {
    final claim = _requireClaim(_reqStr(op, 'claim_id'));
    final newStatus = ClaimStatus.fromWire(_reqStr(op, 'new_status'));
    if (newStatus == claim.status) {
      throw PatchException('Claim already has status ${newStatus.wire}');
    }
    // Trust rules: agent can never set cross_checked / human_verified.
    if (actor == Author.agent &&
        (newStatus == ClaimStatus.crossChecked ||
            newStatus == ClaimStatus.humanVerified)) {
      throw PatchException(
          'Agent cannot set ${newStatus.wire} — Flow B + human required');
    }
    final updated = claim.copyWith(
      status: newStatus,
      lastReviewedAt:
          newStatus == ClaimStatus.humanVerified ? DateTime.parse(nowIso()) : claim.lastReviewedAt,
      updatedAt: DateTime.parse(nowIso()),
    );
    repo.store.writeClaim(updated);
    repo.index.updateClaim(updated);
    return _record(RevisionTargetType.claim, claim.id, op);
  }

  Revision _deprecateClaim(PatchOp op) {
    final claim = _requireClaim(_reqStr(op, 'claim_id'));
    final reason = op.data['reason'] as String?;
    if (claim.status == ClaimStatus.deprecated) {
      throw PatchException('Claim already deprecated');
    }
    final updated = claim.copyWith(
      status: ClaimStatus.deprecated,
      deprecatedReason: reason,
      updatedAt: DateTime.parse(nowIso()),
    );
    repo.store.writeClaim(updated);
    repo.index.updateClaim(updated);
    return _record(RevisionTargetType.claim, claim.id, op);
  }

  Revision _addDecision(PatchOp op) {
    final page = _requirePage(_reqStr(op, 'page_id'));
    if (page.pageType != PageType.decision) {
      throw PatchException(
          'add_decision requires a decision page, got ${page.pageType.wire}');
    }
    final problem = _reqStr(op, 'problem');
    final decision = _reqStr(op, 'decision');
    final rationale = _reqStr(op, 'rationale');
    final markdown = setSections(page.markdown, {
      'Problem': problem,
      'Decision': decision,
      'Rationale': rationale,
    });
    final updated = page.copyWith(
      markdown: markdown,
      updatedAt: DateTime.parse(nowIso()),
    );
    repo.store.writePage(updated);
    repo.index.updatePage(updated);
    return _record(RevisionTargetType.page, page.id, op);
  }

  Revision _appendSection(PatchOp op) {
    final page = _requirePage(_reqStr(op, 'page_id'));
    final heading = _reqStr(op, 'heading');
    final content = _reqStr(op, 'content');
    final markdown = appendToSection(page.markdown, heading, content);
    final updated = page.copyWith(
      markdown: markdown,
      updatedAt: DateTime.parse(nowIso()),
    );
    repo.store.writePage(updated);
    repo.index.updatePage(updated);
    return _record(RevisionTargetType.page, page.id, op);
  }

  // ---------- helpers ----------

  Revision _record(RevisionTargetType type, String targetId, PatchOp op) {
    final r = Revision(
      id: newId(),
      targetType: type,
      targetId: targetId,
      patchJson: _jsonEncode(op.toJson()),
      createdAt: DateTime.parse(nowIso()),
    );
    repo.index.insertRevision(r);
    return r;
  }

  PageRecord _requirePage(String id) {
    final p = repo.getPage(id);
    if (p == null) throw PatchException('Unknown page: $id');
    return p;
  }

  Claim _requireClaim(String id) {
    final c = repo.getClaim(id);
    if (c == null) throw PatchException('Unknown claim: $id');
    return c;
  }

  String _reqStr(PatchOp op, String key) {
    final v = op.data[key];
    if (v == null || (v as String).trim().isEmpty) {
      throw PatchException('Missing required field: $key (op ${op.op})');
    }
    return v;
  }
}

// ---------- markdown section editing ----------

final _headingRe = RegExp(r'^(#{1,6})\s+(.*)$');

bool _hasHeading(String markdown, String name) {
  for (final line in markdown.split('\n')) {
    final m = _headingRe.firstMatch(line);
    if (m != null && m.group(2)!.trim() == name.trim()) return true;
  }
  return false;
}

/// Replace the content of the given `## Heading` sections (creating them at
/// the end if missing). Non-listed sections and leading content are preserved.
String setSections(String markdown, Map<String, String> updates) {
  final lines = markdown.split('\n');
  final out = <String>[];
  final done = <String>{};
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final m = _headingRe.firstMatch(line);
    if (m != null) {
      final name = m.group(2)!.trim();
      if (updates.containsKey(name)) {
        out.add(line);
        out.addAll(updates[name]!.split('\n'));
        done.add(name);
        i++;
        while (i < lines.length && !_headingRe.hasMatch(lines[i])) {
          i++;
        }
        continue;
      }
    }
    out.add(line);
    i++;
  }
  updates.forEach((name, content) {
    if (!done.contains(name)) {
      out.add('');
      out.add('## $name');
      out.addAll(content.split('\n'));
    }
  });
  var result = out.join('\n');
  while (result.contains('\n\n\n')) {
    result = result.replaceAll('\n\n\n', '\n\n');
  }
  return result.trim();
}

/// Append [content] under `## heading` (creating the section at the end if
/// missing).
String appendToSection(String markdown, String heading, String content) {
  final lines = markdown.split('\n');
  final out = <String>[];
  var i = 0;
  var found = false;
  while (i < lines.length) {
    final line = lines[i];
    final m = _headingRe.firstMatch(line);
    out.add(line);
    if (!found && m != null && m.group(2)!.trim() == heading.trim()) {
      found = true;
      // advance past current section content
      i++;
      while (i < lines.length && !_headingRe.hasMatch(lines[i])) {
        out.add(lines[i]);
        i++;
      }
      out.add('');
      out.addAll(content.split('\n'));
      continue;
    }
    i++;
  }
  if (!found) {
    out.add('');
    out.add('## $heading');
    out.addAll(content.split('\n'));
  }
  return out.join('\n').trim();
}

String _jsonEncode(Map<String, dynamic> m) => jsonEncode(m);
