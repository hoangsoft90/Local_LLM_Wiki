import 'package:agent_wiki/core/models/draft_bundle.dart';
import 'package:agent_wiki/core/models/enums.dart';
import 'package:agent_wiki/core/models/patch_op.dart';
import 'package:agent_wiki/core/util/util.dart';
import 'package:agent_wiki/data/fs/local_storage_fs.dart';
import 'package:agent_wiki/data/index_web.dart';
import 'package:agent_wiki/data/wiki_repository.dart';
import 'package:agent_wiki/data/wiki_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the full web storage stack (canonical store + in-memory index)
/// on the VM via an injectable Map — no browser, no SQLite needed.
void main() {
  group('LocalStorageFileSystem', () {
    test('write / read / list (non-recursive & recursive) / delete / exists',
        () {
      final fs = LocalStorageFileSystem(<String, String>{});
      fs.writeAsString('wiki/pages/a.md', '# A');
      fs.writeAsString('wiki/pages/b.md', '# B');
      fs.writeAsString('wiki/sources/history/x-v1.md', 'old');
      fs.writeAsString('wiki/sources/x.md', 'new');

      expect(fs.exists('wiki/pages'), isTrue); // dir implied by children
      expect(fs.exists('wiki/pages/a.md'), isTrue);
      expect(fs.exists('wiki/nope'), isFalse);

      final pages = fs.listFiles('wiki/pages');
      expect(pages, containsAll(['wiki/pages/a.md', 'wiki/pages/b.md']));

      // Non-recursive: sources/history is a subdir → excluded.
      final sources = fs.listFiles('wiki/sources');
      expect(sources, ['wiki/sources/x.md']);

      // Recursive: history included.
      final all = fs.listFiles('wiki/sources', recursive: true);
      expect(all, contains('wiki/sources/history/x-v1.md'));

      expect(fs.readAsString('wiki/pages/a.md'), '# A');

      fs.delete('wiki/pages/a.md');
      expect(fs.exists('wiki/pages/a.md'), isFalse);

      fs.deleteRecursive('wiki/sources');
      expect(fs.exists('wiki/sources'), isFalse);
    });
  });

  group('Web wiki stack (localStorage backend)', () {
    late Map<String, String> storage;
    late LocalStorageFileSystem fs;
    late WikiStore store;
    late WikiRepository repo;

    setUp(() {
      storage = <String, String>{};
      fs = LocalStorageFileSystem(storage);
      store = WikiStore('testwiki', fs: fs)..init();
      repo = WikiRepository(store, LocalStorageIndex(store)..open());
    });

    test('import source → canonical file + index', () {
      final src = repo.importSource(
          title: 'Guide', content: 'AgentWiki is a hosted LLM wiki.');
      expect(repo.sourceCount, 1);
      expect(fs.exists('testwiki/sources/${src.id}.md'), isTrue);
      expect(repo.getSource(src.id)?.contentHash, isNotEmpty);
      // Dedupe by content hash → no-op.
      final again = repo.importSource(
          title: 'Guide', content: 'AgentWiki is a hosted LLM wiki.');
      expect(again.id, src.id);
      expect(repo.sourceCount, 1);
    });

    test('patch ops → page searchable, claim evidence verbatim', () {
      final src = repo.importSource(
          title: 'Doc', content: 'The agent reuses past results.');

      repo.applyOp(
        PatchOp.createPage(
          title: 'AgentWiki',
          pageType: PageType.concept,
          body: 'The agent reuses past results.',
        ),
        actor: Author.agent,
      );
      final page = repo.getPageByTitle('AgentWiki')!;
      expect(page, isNotNull);

      final rev = repo.applyOp(
        PatchOp.addClaim(
          pageId: page.id,
          statement: 'The agent reuses past results.',
          evidence: [
            {
              'source_id': src.id,
              'source_version': 1,
              'location': '',
              'quote': 'reuses past results',
            },
          ],
        ),
        actor: Author.agent,
      );
      expect(rev.targetType, RevisionTargetType.claim);

      final claim = repo.getClaim(rev.targetId)!;
      expect(claim.status, ClaimStatus.supported);
      expect(claim.evidence.single.sourceId, src.id);

      // Fictitious quote → rejected, nothing written.
      expect(
        () => repo.applyOp(
          PatchOp.addClaim(
            pageId: page.id,
            statement: 'X',
            evidence: [
              {
                'source_id': src.id,
                'quote': 'not in the source at all',
              },
            ],
          ),
          actor: Author.agent,
        ),
        throwsA(isA<Exception>()),
      );
      expect(repo.claimCount, 1);

      // Search finds the page (search contract identical to SQLite path).
      final hits = repo.search('reuse');
      expect(hits, isNotEmpty);
      expect(hits.first.pageId, page.id);

      // Agent can never set cross_checked/human_verified.
      expect(
        () => repo.applyOp(
          PatchOp.updateClaimStatus(
              claimId: claim.id, newStatus: ClaimStatus.humanVerified),
          actor: Author.agent,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('draft → accept-equivalent (actor human) → revision + canonical', () {
      final src = repo.importSource(title: 'S', content: 'Everything is fine.');
      repo.applyOp(
        PatchOp.createPage(title: 'Status', pageType: PageType.note),
        actor: Author.agent,
      );
      final page = repo.getPageByTitle('Status')!;

      final draft = DraftBundle(
        id: newId(),
        originOp: 'ask_save',
        ops: [
          PatchOp.addClaim(
            pageId: page.id,
            statement: 'Everything is fine.',
            evidence: [
              {'source_id': src.id, 'quote': 'Everything is fine.'},
            ],
          ),
        ],
        createdAt: DateTime.parse(nowIso()),
      );
      repo.saveDraft(draft);
      expect(repo.pendingDraftCount(), 1);
      expect(fs.exists('testwiki/inbox/draft_${draft.id}.json'), isTrue);

      // Accept = apply ops with actor human (the real promote service also
      // runs corroboration first — out of scope for the storage contract).
      repo.applyOps(draft.ops, actor: Author.human);
      // Claims live in canonical claim JSON (rendered as claim cards on the
      // page), not inside the page markdown — same contract as SQLite.
      final statements =
          repo.claimsForPage(page.id).map((c) => c.statement).toList();
      expect(statements, contains('Everything is fine.'));
      expect(repo.listRevisions(targetId: page.id), isNotEmpty);
    });

    test('rebuild() re-indexes from canonical → search unchanged', () {
      final src = repo.importSource(
          title: 'R', content: 'Compounding knowledge works.');
      repo.applyOp(
        PatchOp.createPage(
          title: 'Loop',
          pageType: PageType.concept,
          body: 'Compounding knowledge works.',
        ),
        actor: Author.agent,
      );
      final page = repo.getPageByTitle('Loop')!;
      repo.applyOp(
        PatchOp.addClaim(
          pageId: page.id,
          statement: 'Compounding knowledge works.',
          evidence: [
            {'source_id': src.id, 'quote': 'Compounding knowledge'},
          ],
        ),
        actor: Author.agent,
      );

      final before = repo.search('compounding');
      expect(before, isNotEmpty);

      repo.rebuild();
      final after = repo.search('compounding');
      expect(after.map((h) => h.pageId), before.map((h) => h.pageId));
      expect(repo.getPage(page.id)?.markdown, contains('Compounding'));
    });

    test('reload: new index instance loads canonical data from localStorage',
        () {
      repo.importSource(title: 'A', content: 'Persisted source content.');
      repo.applyOp(
        PatchOp.createPage(title: 'Persisted', pageType: PageType.note),
        actor: Author.agent,
      );

      // Simulate a fresh app load over the SAME localStorage map.
      final freshFs = LocalStorageFileSystem(storage);
      final freshStore = WikiStore('testwiki', fs: freshFs)..init();
      final freshRepo =
          WikiRepository(freshStore, LocalStorageIndex(freshStore)..open());

      expect(freshRepo.sourceCount, 1);
      expect(freshRepo.pageCount, 1);
      expect(freshRepo.getPageByTitle('Persisted'), isNotNull);
      expect(freshRepo.search('persisted'), isNotEmpty);
    });
  });
}
