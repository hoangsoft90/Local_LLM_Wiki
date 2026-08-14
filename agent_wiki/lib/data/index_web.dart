import '../core/models/enums.dart';
import '../core/models/models.dart';
import 'wiki_index.dart';
import 'wiki_store.dart';

/// In-memory derived index for web, rebuilt from the canonical files (which
/// live in localStorage) at open. Mirrors the SQLite contract — including the
/// fact that links/revisions are ephemeral on rebuild, exactly like
/// `IndexDb.rebuild()`.
class LocalStorageIndex implements WikiIndex {
  LocalStorageIndex(this._store);

  final WikiStore _store;

  final Map<String, SourceRecord> _sources = {};
  final Map<String, PageRecord> _pages = {};
  final Map<String, Claim> _claims = {};
  final List<LinkRecord> _links = [];
  final List<Revision> _revisions = [];

  /// Load canonical pages/claims/sources into memory.
  void open() {
    for (final s in _store.listSources()) {
      _sources[s.id] = s;
    }
    for (final page in _store.listPages()) {
      _pages[page.id] = page;
    }
    for (final id in _store.listClaimIds()) {
      final c = _store.readClaim(id);
      if (c != null) _claims[c.id] = c;
    }
  }

  // ---------- sources ----------

  @override
  void upsertSource(SourceRecord s) => _sources[s.id] = s;

  @override
  SourceRecord? getSource(String id) => _sources[id];

  @override
  int latestVersion(String title, String? url) {
    var v = 0;
    for (final s in _sources.values) {
      if (s.title == title && (s.url ?? '') == (url ?? '') && s.version > v) {
        v = s.version;
      }
    }
    return v;
  }

  @override
  List<SourceRecord> listSources() =>
      _sources.values.toList()..sort((a, b) => a.importedAt.compareTo(b.importedAt));

  // ---------- pages ----------

  @override
  void insertPage(PageRecord p) => _pages[p.id] = p;

  @override
  void updatePage(PageRecord p) => _pages[p.id] = p;

  @override
  PageRecord? getPage(String id) => _pages[id];

  @override
  PageRecord? getPageByTitle(String title) {
    for (final p in _pages.values) {
      if (p.title == title) return p;
    }
    return null;
  }

  @override
  List<PageRecord> listPages({PageType? type}) {
    final out = _pages.values
        .where((p) => type == null || p.pageType == type)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  // ---------- claims ----------

  @override
  void insertClaim(Claim c) => _claims[c.id] = c;

  @override
  void updateClaim(Claim c) => _claims[c.id] = c;

  @override
  Claim? getClaim(String id) => _claims[id];

  @override
  List<Claim> claimsForPage(String pageId) {
    final out = _claims.values
        .where((c) => c.pageId == pageId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  @override
  List<Evidence> evidenceForClaim(String claimId) =>
      _claims[claimId]?.evidence ?? const [];

  // ---------- links ----------

  @override
  void insertLink(LinkRecord l) {
    final dup = _links.any((x) =>
        x.sourcePageId == l.sourcePageId &&
        x.targetPageId == l.targetPageId &&
        x.linkType == l.linkType);
    if (!dup) _links.add(l);
  }

  @override
  List<LinkRecord> listLinks(String pageId) => _links
      .where((l) => l.sourcePageId == pageId || l.targetPageId == pageId)
      .toList();

  // ---------- revisions ----------

  @override
  void insertRevision(Revision r) => _revisions.add(r);

  @override
  List<Revision> listRevisions({String? targetId}) {
    final out = _revisions
        .where((r) => targetId == null || r.targetId == targetId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  // ---------- search ----------

  @override
  List<SearchHit> search(String query, {int limit = 20}) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];

    final scored = <(PageRecord, int)>[];
    for (final p in _pages.values) {
      final title = p.title.toLowerCase();
      final content = p.markdown.toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (title.contains(t)) score += 3;
        if (content.contains(t)) score += 1;
      }
      if (score > 0) scored.add((p, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    return scored.take(limit).map((e) {
      final p = e.$1;
      return SearchHit(
        pageId: p.id,
        title: p.title,
        pageType: p.pageType,
        snippet: _snippet(p.markdown, tokens),
        deprecated: p.deprecated,
      );
    }).toList();
  }

  String _snippet(String markdown, List<String> tokens) {
    final lower = markdown.toLowerCase();
    var hit = -1;
    for (final t in tokens) {
      final i = lower.indexOf(t);
      if (i >= 0 && (hit == -1 || i < hit)) hit = i;
    }
    final start = hit < 0 ? 0 : (hit - 60).clamp(0, markdown.length);
    final end = (start + 120).clamp(0, markdown.length);
    final snip = markdown.substring(start, end).trim();
    if (snip.length <= 140) return snip;
    return '${snip.substring(0, 140)}…';
  }

  // ---------- counts ----------

  @override
  int countPages() => _pages.length;

  @override
  int countClaims() => _claims.length;

  @override
  int countSources() => _sources.length;

  @override
  int countRevisions() => _revisions.length;

  // ---------- rebuild ----------

  @override
  void rebuild(List<PageRecord> pages, List<Claim> claims,
      List<SourceRecord> sources) {
    _sources
      ..clear()
      ..addEntries(sources.map((s) => MapEntry(s.id, s)));
    _pages
      ..clear()
      ..addEntries(pages.map((p) => MapEntry(p.id, p)));
    _claims
      ..clear()
      ..addEntries(claims.map((c) => MapEntry(c.id, c)));
    _links.clear();
    _revisions.clear();
  }

  @override
  void close() {
    // Nothing to close — state lives in localStorage canonical files.
  }
}

/// Factory for the web platform (selected by conditional import).
WikiIndex openIndex(WikiStore store) => LocalStorageIndex(store)..open();
