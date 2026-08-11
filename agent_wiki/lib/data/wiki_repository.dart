import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models/draft_bundle.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/models/patch_op.dart';
import '../core/util/frontmatter.dart';
import '../core/util/util.dart';
import '../domain/patch_engine.dart';
import 'database.dart';
import 'wiki_store.dart';

/// Central repository: canonical store + derived index + patch engine.
class WikiRepository {
  final WikiStore store;
  final IndexDb index;
  late final PatchEngine patch;

  WikiRepository._(this.store, this.index) {
    patch = PatchEngine(this);
  }

  /// Open the wiki. [rootDir] defaults to `<app-documents>/agentwiki`.
  static Future<WikiRepository> open({String? rootDir}) async {
    final root = rootDir ?? await _defaultRoot();
    final store = WikiStore(root)..init();
    final index = IndexDb.open(store.indexDbFile.path);
    return WikiRepository._(store, index);
  }

  static Future<String> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'agentwiki');
  }

  // ---------- meta & settings ----------

  WikiMeta get meta => store.readWikiMeta();

  void updateMeta(WikiMeta meta) => store.writeWikiMeta(meta);

  Map<String, dynamic> get settings => store.readSettings();

  void saveSettings(Map<String, dynamic> s) => store.writeSettings(s);

  // ---------- sources ----------

  /// Import a source. No-op (returns existing) when content hash matches;
  /// version++ when the same title+url changes.
  SourceRecord importSource({
    required String title,
    String? url,
    required String content,
  }) {
    final hash = sha256Hex(content);
    // Dedupe by content hash across the wiki.
    for (final s in store.listSources()) {
      if (s.contentHash == hash) return s;
    }
    final existing = index.latestVersion(title, url);
    if (existing > 0) {
      // Preserve the previous canonical content as history before bumping.
      final current = store.readSource(_sourceIdByTitle(title, url));
      if (current != null) {
        store.writeSourceHistory(current);
      }
      final id = _sourceIdByTitle(title, url);
      final record = SourceRecord(
        id: id,
        title: title,
        url: url,
        content: content,
        contentHash: hash,
        version: existing + 1,
        importedAt: DateTime.parse(nowIso()),
      );
      store.writeSource(record);
      index.upsertSource(record);
      return record;
    }
    final record = SourceRecord(
      id: newId(),
      title: title,
      url: url,
      content: content,
      contentHash: hash,
      version: 1,
      importedAt: DateTime.parse(nowIso()),
    );
    store.writeSource(record);
    index.upsertSource(record);
    return record;
  }

  String _sourceIdByTitle(String title, String? url) {
    for (final s in store.listSources()) {
      if (s.title == title && (s.url ?? '') == (url ?? '')) return s.id;
    }
    return newId();
  }

  List<SourceRecord> listSources() => store.listSources();

  SourceRecord? getSource(String id) {
    final s = store.readSource(id);
    if (s != null) return s;
    return index.getSource(id);
  }

  int latestSourceVersion(String title, String? url) =>
      index.latestVersion(title, url);

  // ---------- pages ----------

  PageRecord? getPage(String id) {
    // Canonical markdown is the source of truth (spec D1) — the derived
    // index is only a fallback for pages whose file is missing.
    for (final f in store.pagesDir.listSync().whereType<File>()) {
      final doc = parseFrontmatter(f.readAsStringSync());
      if (doc.frontmatter['page_id'] == id) {
        return store.readPage(id, p.basename(f.path));
      }
    }
    return index.getPage(id);
  }

  PageRecord? getPageByTitle(String title) {
    final fromDb = index.getPageByTitle(title);
    if (fromDb != null) return fromDb;
    // Fall back to scanning canonical files.
    for (final f in store.pagesDir.listSync().whereType<File>()) {
      final doc = _readPageFile(f.path);
      if (doc != null && doc.title == title) return doc;
    }
    return null;
  }

  PageRecord? _readPageFile(String path) {
    final text = File(path).readAsStringSync();
    final id = parseFrontmatter(text).frontmatter['page_id'] as String?;
    if (id == null) return null;
    return store.readPage(id, p.basename(path));
  }

  List<PageRecord> listPages({PageType? type}) => index.listPages(type: type);

  /// Deprecate a page (never delete — TEST-008): frontmatter status flips,
  /// the file stays on disk, and a revision is recorded.
  void deprecatePage(String id) {
    final page = getPage(id);
    if (page == null || page.deprecated) return;
    final updated = page.copyWith(
      deprecated: true,
      updatedAt: DateTime.parse(nowIso()),
    );
    store.writePage(updated);
    index.updatePage(updated);
    index.insertRevision(Revision(
      id: newId(),
      targetType: RevisionTargetType.page,
      targetId: id,
      patchJson: '{"op":"deprecate_page"}',
      createdAt: DateTime.parse(nowIso()),
    ));
  }

  // ---------- claims & evidence ----------

  Claim? getClaim(String id) {
    // Canonical claim JSON is the source of truth (full fields + evidence).
    final fromFile = store.readClaim(id);
    if (fromFile != null) return fromFile;
    final c = index.getClaim(id);
    if (c != null) return _withEvidence(c);
    return null;
  }

  Claim _withEvidence(Claim c) {
    final evidence = index.evidenceForClaim(c.id);
    if (evidence.isEmpty) return c;
    return c.copyWith(evidence: evidence);
  }

  List<Claim> claimsForPage(String pageId) =>
      index.claimsForPage(pageId).map(_withEvidence).toList();

  List<Evidence> evidenceForClaim(String claimId) =>
      index.evidenceForClaim(claimId);

  // ---------- links & revisions ----------

  List<LinkRecord> linksFor(String pageId) => index.listLinks(pageId);

  List<Revision> listRevisions({String? targetId}) =>
      index.listRevisions(targetId: targetId);

  // ---------- search ----------

  List<SearchHit> search(String query, {int limit = 20}) =>
      index.search(query, limit: limit);

  // ---------- drafts ----------

  List<DraftBundle> listDrafts() => store.listDrafts();

  void saveDraft(DraftBundle draft) => store.writeDraft(draft);

  void updateDraft(DraftBundle draft) => store.writeDraft(draft);

  int pendingDraftCount() =>
      store.listDrafts().where((d) => d.isPending).length;

  // ---------- patch ----------

  Revision applyOp(PatchOp op, {required Author actor}) =>
      patch.applyOp(op, actor: actor);

  List<Revision> applyOps(List<PatchOp> ops, {required Author actor}) {
    final out = <Revision>[];
    for (final op in ops) {
      out.add(patch.applyOp(op, actor: actor));
    }
    return out;
  }

  // ---------- ai runs ----------

  void logAiRun(Map<String, dynamic> run) {
    store.writeAiRun({'id': newId(), 'ts': nowIso(), ...run});
  }

  List<Map<String, dynamic>> listAiRuns() => store.listAiRuns();

  // ---------- counts ----------

  int get pageCount => index.countPages();
  int get claimCount => index.countClaims();
  int get sourceCount => index.countSources();
  int get revisionCount => index.countRevisions();

  // ---------- rebuild & export ----------

  /// Drop + rebuild the derived index from canonical files (TEST-007).
  void rebuild() {
    final pages = <PageRecord>[];
    for (final f in store.pagesDir.listSync().whereType<File>()) {
      final page = _readPageFile(f.path);
      if (page != null) pages.add(page);
    }
    final claims = <Claim>[];
    for (final f in store.claimsDir.listSync().whereType<File>()) {
      try {
        final c = store.readClaim(p.basenameWithoutExtension(f.path)
            .replaceFirst('claim_', ''));
        if (c != null) claims.add(c);
      } catch (_) {}
    }
    index.rebuild(pages, claims, store.listSources());
  }

  /// Export the whole wiki (canonical) to [destDir] (TEST-006).
  void exportTo(String destDir) {
    final dest = Directory(destDir);
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    dest.createSync(recursive: true);
    _copyDir(store.pagesDir, Directory(p.join(dest.path, 'pages')));
    _copyDir(store.sourcesDir, Directory(p.join(dest.path, 'sources')));
    _copyDir(store.claimsDir, Directory(p.join(dest.path, 'claims')));
    File(store.wikiMetaFile.path)
        .copySync(p.join(dest.path, 'wiki.yaml'));
    _writeExportManifest(dest);
  }

  void _writeExportManifest(Directory dest) {
    final buf = StringBuffer('---\nname: "agent-wiki-export"\nexported_at: ${nowIso()}\n---\n');
    File(p.join(dest.path, 'EXPORT.md')).writeAsStringSync(buf.toString());
  }
}

void _copyDir(Directory src, Directory dest) {
  if (!src.existsSync()) return;
  dest.createSync(recursive: true);
  for (final e in src.listSync(recursive: true)) {
    if (e is File) {
      final rel = p.relative(e.path, from: src.path);
      File(p.join(dest.path, rel)).createSync(recursive: true);
      e.copySync(p.join(dest.path, rel));
    }
  }
}
