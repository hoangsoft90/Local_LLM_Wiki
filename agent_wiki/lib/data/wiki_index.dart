import '../core/models/enums.dart';
import '../core/models/models.dart';

/// Derived knowledge index (openspec: canonical-storage REQ-3/4/5).
///
/// The exact contract `WikiRepository` and `PatchEngine` rely on. Implemented
/// by SQLite (`IndexDb`, mobile/desktop) and an in-memory index rebuilt from
/// canonical files (`LocalStorageIndex`, web). Fully rebuildable from
/// canonical state — see [rebuild].
abstract class WikiIndex {
  // ---------- sources ----------

  void upsertSource(SourceRecord s);

  SourceRecord? getSource(String id);

  /// Highest version of the source with the same identity (title+url).
  int latestVersion(String title, String? url);

  List<SourceRecord> listSources();

  // ---------- pages ----------

  void insertPage(PageRecord p);

  void updatePage(PageRecord p);

  PageRecord? getPage(String id);

  PageRecord? getPageByTitle(String title);

  List<PageRecord> listPages({PageType? type});

  // ---------- claims ----------

  void insertClaim(Claim c);

  void updateClaim(Claim c);

  Claim? getClaim(String id);

  List<Claim> claimsForPage(String pageId);

  List<Evidence> evidenceForClaim(String claimId);

  // ---------- links ----------

  void insertLink(LinkRecord l);

  List<LinkRecord> listLinks(String pageId);

  // ---------- revisions ----------

  void insertRevision(Revision r);

  List<Revision> listRevisions({String? targetId});

  // ---------- search ----------

  List<SearchHit> search(String query, {int limit = 20});

  // ---------- counts ----------

  int countPages();

  int countClaims();

  int countSources();

  int countRevisions();

  // ---------- lifecycle ----------

  /// Drop and rebuild the entire index from canonical state (TEST-007).
  void rebuild(List<PageRecord> pages, List<Claim> claims,
      List<SourceRecord> sources);

  void close();
}
