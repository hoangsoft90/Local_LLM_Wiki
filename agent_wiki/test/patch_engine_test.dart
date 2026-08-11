import 'package:agent_wiki/core/models/enums.dart';
import 'package:agent_wiki/core/models/patch_op.dart';
import 'package:agent_wiki/domain/patch_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_util.dart';

void main() {
  late dynamic repo; // WikiRepository

  setUp(() async {
    repo = await tempRepo();
  });

  test('create_page seeds fixed template headings per page_type', () {
    final rev = repo.applyOp(
      PatchOp.createPage(
        title: 'Ship decision',
        pageType: PageType.decision,
      ),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('Ship decision');
    expect(page, isNotNull);
    expect(page.markdown, contains('## Problem'));
    expect(page.markdown, contains('## Decision'));
    expect(page.markdown, contains('## Rationale'));
    expect(rev.targetType, RevisionTargetType.page);
  });

  test('add_decision writes into the fixed decision sections', () {
    repo.applyOp(
      PatchOp.createPage(title: 'D1', pageType: PageType.decision),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('D1')!;
    repo.applyOp(
      PatchOp.addDecision(
        pageId: page.id,
        problem: 'Latency too high',
        decision: 'Move to streaming',
        rationale: 'P95 drops by 4x',
      ),
      actor: Author.agent,
    );
    final updated = repo.getPage(page.id)!;
    expect(updated.markdown, contains('Latency too high'));
    expect(updated.markdown, contains('Move to streaming'));
    expect(updated.markdown, contains('P95 drops by 4x'));
  });

  test('add_decision rejects non-decision pages', () {
    repo.applyOp(
      PatchOp.createPage(title: 'N1', pageType: PageType.note),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('N1')!;
    expect(
      () => repo.applyOp(
        PatchOp.addDecision(
            pageId: page.id,
            problem: 'p',
            decision: 'd',
            rationale: 'r'),
        actor: Author.agent,
      ),
      throwsA(isA<PatchException>()),
    );
  });

  test('append_section appends to existing heading or creates it', () {
    repo.applyOp(
      PatchOp.createPage(
        title: 'C1',
        pageType: PageType.concept,
        body: '## Summary\n\nFirst.',
      ),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('C1')!;
    repo.applyOp(
      PatchOp.appendSection(
          pageId: page.id, heading: 'Summary', content: 'Second.'),
      actor: Author.agent,
    );
    var updated = repo.getPage(page.id)!;
    expect(updated.markdown, contains('First.'));
    expect(updated.markdown, contains('Second.'));

    repo.applyOp(
      PatchOp.appendSection(
          pageId: page.id, heading: 'Details', content: 'New section.'),
      actor: Author.agent,
    );
    updated = repo.getPage(page.id)!;
    expect(updated.markdown, contains('## Details'));
    expect(updated.markdown, contains('New section.'));
  });

  test('unknown op throws, nothing written', () {
    expect(
      () => repo.applyOp(const PatchOp('hack_page', {}), actor: Author.agent),
      throwsA(isA<PatchException>()),
    );
    expect(repo.pageCount, 0);
  });

  test('add_claim requires evidence unless hypothesis', () {
    repo.applyOp(
      PatchOp.createPage(title: 'P1', pageType: PageType.note),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('P1')!;
    expect(
      () => repo.applyOp(
        PatchOp.addClaim(pageId: page.id, statement: 'no evidence'),
        actor: Author.agent,
      ),
      throwsA(isA<PatchException>()),
    );
    // Hypothesis is allowed without evidence → unverified.
    final rev = repo.applyOp(
      PatchOp.addClaim(
        pageId: page.id,
        statement: 'Maybe X',
        hypothesis: true,
      ),
      actor: Author.agent,
    );
    expect(rev.targetType, RevisionTargetType.claim);
    final claim = repo.getClaim(rev.targetId)!;
    expect(claim.status, ClaimStatus.unverified);
    expect(claim.author, Author.agent);
  });

  test('deprecate_claim sets deprecated + reason', () {
    repo.applyOp(
      PatchOp.createPage(title: 'P2', pageType: PageType.note),
      actor: Author.agent,
    );
    final page = repo.getPageByTitle('P2')!;
    final rev = repo.applyOp(
      PatchOp.addClaim(pageId: page.id, statement: 'Old fact', hypothesis: true),
      actor: Author.agent,
    );
    repo.applyOp(
      PatchOp.deprecateClaim(claimId: rev.targetId, reason: 'outdated'),
      actor: Author.human,
    );
    final claim = repo.getClaim(rev.targetId)!;
    expect(claim.status, ClaimStatus.deprecated);
    expect(claim.deprecatedReason, 'outdated');
  });

  test('link_pages records a link', () {
    repo.applyOp(PatchOp.createPage(title: 'A', pageType: PageType.note),
        actor: Author.agent);
    repo.applyOp(PatchOp.createPage(title: 'B', pageType: PageType.note),
        actor: Author.agent);
    final a = repo.getPageByTitle('A')!;
    final b = repo.getPageByTitle('B')!;
    repo.applyOp(
      PatchOp.linkPages(
          sourcePageId: a.id, targetPageId: b.id, linkType: LinkType.related),
      actor: Author.agent,
    );
    expect(repo.linksFor(a.id).length, 1);
  });
}
