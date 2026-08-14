import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/util/util.dart';
import 'wiki_index.dart';

/// Derived SQLite index (openspec: canonical-storage REQ-3/REQ-4/REQ-5).
/// Fully rebuildable from canonical files — see [rebuild].
/// The io-only implementation of [WikiIndex]; web uses [LocalStorageIndex].
class IndexDb implements WikiIndex {
  static const int schemaVersion = 1;

  final String path;
  late sqlite.Database db;

  IndexDb._(this.path);

  /// Open (or create) the index at [path].
  static IndexDb open(String path) {
    final db = sqlite.sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    final d = IndexDb._(path)..db = db;
    d._createSchemaIfNeeded();
    return d;
  }

  @override
  void close() => db.dispose();

  void _createSchemaIfNeeded() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS wikis(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sources(
        id TEXT PRIMARY KEY,
        wiki_id TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT,
        content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        version INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        metadata TEXT
      );
      CREATE TABLE IF NOT EXISTS pages(
        id TEXT PRIMARY KEY,
        wiki_id TEXT NOT NULL,
        title TEXT NOT NULL,
        filename TEXT NOT NULL,
        page_type TEXT NOT NULL,
        markdown TEXT NOT NULL,
        deprecated INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS claims(
        id TEXT PRIMARY KEY,
        page_id TEXT NOT NULL,
        claim_file_path TEXT NOT NULL,
        statement TEXT NOT NULL,
        claim_status TEXT NOT NULL,
        author TEXT NOT NULL,
        last_reviewed_at TEXT,
        valid_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS evidence(
        id TEXT PRIMARY KEY,
        claim_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        source_version INTEGER NOT NULL,
        location TEXT,
        quote TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS links(
        source_page_id TEXT NOT NULL,
        target_page_id TEXT NOT NULL,
        link_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (source_page_id, target_page_id, link_type)
      );
      CREATE TABLE IF NOT EXISTS revisions(
        id TEXT PRIMARY KEY,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        patch TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS _meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
        page_id UNINDEXED, title, content, summary
      );
    ''');
    db.execute(
        'INSERT OR IGNORE INTO _meta(key, value) VALUES(\'schema_version\', ?)',
        ['$schemaVersion']);
    _ensureWikiRow();
  }

  void _ensureWikiRow() {
    final rows = db.select('SELECT COUNT(*) AS c FROM wikis');
    if ((rows.first['c'] as int) == 0) {
      db.execute(
          'INSERT INTO wikis(id, name, created_at) VALUES(?, ?, ?)',
          [newId(), 'agent-wiki', nowIso()]);
    }
  }

  // ---------- sources ----------

  @override
  void upsertSource(SourceRecord s) {
    db.execute(
        '''
        INSERT INTO sources(id, wiki_id, title, url, content, content_hash, version, imported_at, metadata)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title=excluded.title, url=excluded.url, content=excluded.content,
          content_hash=excluded.content_hash, version=excluded.version,
          imported_at=excluded.imported_at
        ''', [
      s.id,
      _wikiId(),
      s.title,
      s.url,
      s.content,
      s.contentHash,
      s.version,
      s.importedAt.toIso8601String(),
      null,
    ]);
  }

  @override
  SourceRecord? getSource(String id) {
    final rows = db.select('SELECT * FROM sources WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _sourceFromRow(rows.first);
  }

  /// Highest version of the source with the same identity (by title+url).
  @override
  int latestVersion(String title, String? url) {
    final rows = db.select(
        'SELECT MAX(version) AS v FROM sources '
        'WHERE title = ? AND IFNULL(url,\'\') = IFNULL(?,\'\')',
        [title, url]);
    return (rows.first['v'] as int?) ?? 0;
  }

  @override
  List<SourceRecord> listSources() {
    final rows = db.select('SELECT * FROM sources ORDER BY imported_at ASC');
    return rows.map(_sourceFromRow).toList();
  }

  SourceRecord _sourceFromRow(sqlite.Row r) => SourceRecord(
        id: r['id'] as String,
        title: r['title'] as String,
        url: r['url'] as String?,
        content: r['content'] as String,
        contentHash: r['content_hash'] as String,
        version: r['version'] as int,
        importedAt: DateTime.parse(r['imported_at'] as String),
      );

  // ---------- pages ----------

  @override
  void insertPage(PageRecord p) {
    db.execute(
        '''
        INSERT INTO pages(id, wiki_id, title, filename, page_type, markdown, deprecated, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
      p.id,
      _wikiId(),
      p.title,
      p.filename,
      p.pageType.wire,
      p.markdown,
      p.deprecated ? 1 : 0,
      p.createdAt.toIso8601String(),
      p.updatedAt.toIso8601String(),
    ]);
    _upsertFts(p);
  }

  @override
  void updatePage(PageRecord p) {
    db.execute(
        '''
        UPDATE pages SET title=?, filename=?, page_type=?, markdown=?, deprecated=?, updated_at=?
        WHERE id=?
        ''', [
      p.title,
      p.filename,
      p.pageType.wire,
      p.markdown,
      p.deprecated ? 1 : 0,
      p.updatedAt.toIso8601String(),
      p.id,
    ]);
    _upsertFts(p);
  }

  void deletePageRow(String id) {
    db.execute('DELETE FROM pages_fts WHERE page_id = ?', [id]);
    db.execute('DELETE FROM pages WHERE id = ?', [id]);
  }

  @override
  PageRecord? getPage(String id) {
    final rows = db.select('SELECT * FROM pages WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _pageFromRow(rows.first);
  }

  @override
  PageRecord? getPageByTitle(String title) {
    final rows = db.select('SELECT * FROM pages WHERE title = ?', [title]);
    if (rows.isEmpty) return null;
    return _pageFromRow(rows.first);
  }

  @override
  List<PageRecord> listPages({PageType? type}) {
    final sql = 'SELECT * FROM pages'
        '${type != null ? ' WHERE page_type = ?' : ''}'
        ' ORDER BY updated_at DESC';
    final rows = type != null ? db.select(sql, [type.wire]) : db.select(sql);
    return rows.map(_pageFromRow).toList();
  }

  PageRecord _pageFromRow(sqlite.Row r) => PageRecord(
        id: r['id'] as String,
        title: r['title'] as String,
        filename: r['filename'] as String,
        pageType: PageType.fromWire(r['page_type'] as String),
        markdown: r['markdown'] as String,
        deprecated: (r['deprecated'] as int) == 1,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  void _upsertFts(PageRecord p) {
    db.execute('DELETE FROM pages_fts WHERE page_id = ?', [p.id]);
    final summary =
        p.markdown.length > 300 ? p.markdown.substring(0, 300) : p.markdown;
    db.execute(
        'INSERT INTO pages_fts(page_id, title, content, summary) VALUES(?,?,?,?)',
        [p.id, p.title, p.markdown, summary]);
  }

  // ---------- claims ----------

  @override
  void insertClaim(Claim c) {
    db.execute(
        '''
        INSERT INTO claims(id, page_id, claim_file_path, statement, claim_status, author, last_reviewed_at, valid_until, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
      c.id,
      c.pageId,
      'claims/claim_${c.id}.json',
      c.statement,
      c.status.wire,
      c.author.wire,
      c.lastReviewedAt?.toIso8601String(),
      c.validUntil?.toIso8601String(),
      c.createdAt.toIso8601String(),
      c.updatedAt.toIso8601String(),
    ]);
    _syncEvidence(c);
  }

  @override
  void updateClaim(Claim c) {
    db.execute(
        '''
        UPDATE claims SET statement=?, claim_status=?, last_reviewed_at=?, updated_at=?
        WHERE id=?
        ''', [
      c.statement,
      c.status.wire,
      c.lastReviewedAt?.toIso8601String(),
      c.updatedAt.toIso8601String(),
      c.id,
    ]);
    _syncEvidence(c);
  }

  void _syncEvidence(Claim c) {
    db.execute('DELETE FROM evidence WHERE claim_id = ?', [c.id]);
    for (final e in c.evidence) {
      db.execute(
          '''
          INSERT INTO evidence(id, claim_id, source_id, source_version, location, quote)
          VALUES(?, ?, ?, ?, ?, ?)
          ''', [
        e.id,
        e.claimId,
        e.sourceId,
        e.sourceVersion,
        e.location,
        e.quote,
      ]);
    }
  }

  @override
  Claim? getClaim(String id) {
    final rows = db.select('SELECT * FROM claims WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _claimFromRow(rows.first);
  }

  @override
  List<Claim> claimsForPage(String pageId) {
    final rows = db.select(
        'SELECT * FROM claims WHERE page_id = ? ORDER BY created_at ASC',
        [pageId]);
    return rows.map(_claimFromRow).toList();
  }

  Claim _claimFromRow(sqlite.Row r) => Claim(
        id: r['id'] as String,
        pageId: r['page_id'] as String,
        statement: r['statement'] as String,
        status: ClaimStatus.fromWire(r['claim_status'] as String),
        author: Author.fromWire(r['author'] as String),
        lastReviewedAt: r['last_reviewed_at'] == null
            ? null
            : DateTime.parse(r['last_reviewed_at'] as String),
        validUntil: r['valid_until'] == null
            ? null
            : DateTime.parse(r['valid_until'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  @override
  List<Evidence> evidenceForClaim(String claimId) {
    final rows = db.select(
        'SELECT * FROM evidence WHERE claim_id = ? ORDER BY rowid',
        [claimId]);
    return rows.map((r) => Evidence(
          id: r['id'] as String,
          claimId: r['claim_id'] as String,
          sourceId: r['source_id'] as String,
          sourceVersion: r['source_version'] as int,
          location: r['location'] as String?,
          quote: r['quote'] as String,
        )).toList();
  }

  // ---------- links ----------

  @override
  void insertLink(LinkRecord l) {
    db.execute(
        '''
        INSERT OR IGNORE INTO links(source_page_id, target_page_id, link_type, created_at)
        VALUES(?, ?, ?, ?)
        ''', [
      l.sourcePageId,
      l.targetPageId,
      l.linkType.wire,
      l.createdAt.toIso8601String(),
    ]);
  }

  @override
  List<LinkRecord> listLinks(String pageId) {
    final rows = db.select(
        'SELECT * FROM links WHERE source_page_id = ? OR target_page_id = ?',
        [pageId, pageId]);
    return rows.map((r) => LinkRecord(
          sourcePageId: r['source_page_id'] as String,
          targetPageId: r['target_page_id'] as String,
          linkType: LinkType.fromWire(r['link_type'] as String),
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
  }

  // ---------- revisions ----------

  @override
  void insertRevision(Revision r) {
    db.execute(
        '''
        INSERT INTO revisions(id, target_type, target_id, patch, created_at)
        VALUES(?, ?, ?, ?, ?)
        ''', [
      r.id,
      r.targetType.wire,
      r.targetId,
      r.patchJson,
      r.createdAt.toIso8601String(),
    ]);
  }

  @override
  List<Revision> listRevisions({String? targetId}) {
    final sql = 'SELECT * FROM revisions'
        '${targetId != null ? ' WHERE target_id = ?' : ''}'
        ' ORDER BY created_at DESC';
    final rows = targetId != null ? db.select(sql, [targetId]) : db.select(sql);
    return rows.map((r) => Revision(
          id: r['id'] as String,
          targetType: RevisionTargetType.fromWire(r['target_type'] as String),
          targetId: r['target_id'] as String,
          patchJson: r['patch'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
  }

  // ---------- search ----------

  @override
  List<SearchHit> search(String query, {int limit = 20}) {
    final q = ftsQuery(query);
    if (q.isEmpty) return const [];
    try {
      final rows = db.select(
          '''
          SELECT f.page_id, f.title, snippet(pages_fts, 2, '<b>', '</b>', '…', 12) AS snip,
                 p.page_type, p.deprecated
          FROM pages_fts f
          JOIN pages p ON p.id = f.page_id
          WHERE pages_fts MATCH ?
          ORDER BY bm25(pages_fts)
          LIMIT ?
          ''', [q, limit]);
      return rows.map((r) => SearchHit(
            pageId: r['page_id'] as String,
            title: r['title'] as String,
            pageType: PageType.fromWire(r['page_type'] as String),
            snippet: (r['snip'] ?? '') as String,
            deprecated: (r['deprecated'] as int) == 1,
          )).toList();
    } catch (_) {
      // Malformed query (rare) → fall back to LIKE search.
      final like = '%${query.replaceAll(RegExp(r'[%_]'), ' ')}%';
      final rows = db.select(
          '''
          SELECT id, title, page_type, deprecated FROM pages
          WHERE title LIKE ? OR markdown LIKE ?
          ORDER BY updated_at DESC LIMIT ?
          ''', [like, like, limit]);
      return rows.map((r) => SearchHit(
            pageId: r['id'] as String,
            title: r['title'] as String,
            pageType: PageType.fromWire(r['page_type'] as String),
            snippet: '',
            deprecated: (r['deprecated'] as int) == 1,
          )).toList();
    }
  }

  // ---------- counts ----------

  @override
  int countPages() =>
      db.select('SELECT COUNT(*) AS c FROM pages').first['c'] as int;

  @override
  int countClaims() =>
      db.select('SELECT COUNT(*) AS c FROM claims').first['c'] as int;

  @override
  int countSources() =>
      db.select('SELECT COUNT(*) AS c FROM sources').first['c'] as int;

  @override
  int countRevisions() =>
      db.select('SELECT COUNT(*) AS c FROM revisions').first['c'] as int;

  String _wikiId() =>
      db.select('SELECT id FROM wikis LIMIT 1').first['id'] as String;

  // ---------- rebuild ----------

  /// Drop and rebuild the entire derived index from canonical state (TEST-007).
  @override
  void rebuild(List<PageRecord> pages, List<Claim> claims,
      List<SourceRecord> sources) {
    db.dispose();
    File(path).deleteSync();
    db = sqlite.sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    _createSchemaIfNeeded();
    for (final s in sources) {
      upsertSource(s);
    }
    for (final p in pages) {
      insertPage(p);
    }
    for (final c in claims) {
      insertClaim(c);
    }
  }
}
