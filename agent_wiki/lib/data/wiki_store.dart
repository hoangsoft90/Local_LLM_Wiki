import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/models/draft_bundle.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/util/frontmatter.dart';
import '../core/util/util.dart';
import 'fs/fs_factory.dart';
import 'fs/fs_interface.dart';

/// Canonical store (openspec: canonical-storage).
/// Layout:
///   wiki.yaml | pages/*.md | sources/*.md | `claims/claim_<id>.json` |
///   `inbox/draft_<id>.json` | .ai/runs/*.json | `.agentwiki/index.sqlite`
///
/// Backed by a [FileSystem] so it runs on real files (mobile/desktop) and on
/// localStorage (web) with identical behavior.
class WikiStore {
  final String root;
  final FileSystem fs;

  WikiStore(this.root, {FileSystem? fs}) : fs = fs ?? createFileSystem();

  String get pagesDir => p.join(root, 'pages');
  String get sourcesDir => p.join(root, 'sources');
  String get claimsDir => p.join(root, 'claims');
  String get inboxDir => p.join(root, 'inbox');
  String get aiRunsDir => p.join(root, '.ai', 'runs');
  String get indexDir => p.join(root, '.agentwiki');
  String get wikiMetaPath => p.join(root, 'wiki.yaml');
  String get indexDbPath => p.join(indexDir, 'index.sqlite');
  String get settingsPath => p.join(root, 'settings.json');

  void init() {
    for (final d in [pagesDir, sourcesDir, claimsDir, inboxDir, aiRunsDir, indexDir]) {
      if (!fs.exists(d)) fs.createDir(d);
    }
    if (!fs.exists(wikiMetaPath)) {
      writeWikiMeta(WikiMeta(name: 'My Wiki', createdAt: _epoch()));
    }
  }

  DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  // ---------- wiki meta ----------

  WikiMeta readWikiMeta() {
    if (!fs.exists(wikiMetaPath)) {
      return WikiMeta(name: 'My Wiki', createdAt: _epoch());
    }
    try {
      final j = jsonDecode(_yamlToJson(fs.readAsString(wikiMetaPath)));
      return WikiMeta(
        name: (j['name'] ?? 'My Wiki') as String,
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '') as String) ?? _epoch(),
        primaryModel: j['primary_model'] as String?,
        corroborationModel: j['corroboration_model'] as String?,
      );
    } catch (_) {
      return WikiMeta(name: 'My Wiki', createdAt: _epoch());
    }
  }

  void writeWikiMeta(WikiMeta meta) {
    final yaml =
        '---\nname: "${meta.name.replaceAll('"', r'\"')}"\n'
        'created_at: ${meta.createdAt.toIso8601String()}\n'
        'primary_model: ${meta.primaryModel ?? ''}\n'
        'corroboration_model: ${meta.corroborationModel ?? ''}\n---\n';
    fs.writeAsString(wikiMetaPath, yaml);
  }

  String _yamlToJson(String yamlText) {
    final y = loadYaml(yamlText);
    if (y is! Map) return '{}';
    final map = y.map((k, v) {
      final val = switch (v) {
        String s => s.startsWith('"') && s.endsWith('"')
            ? s.substring(1, s.length - 1)
            : s,
        // YAML 1.1 parses ISO timestamps into DateTime — normalize to text.
        DateTime d => d.toIso8601String(),
        _ => v,
      };
      return MapEntry('$k', val);
    });
    return jsonEncode(map);
  }

  // ---------- settings (non-canonical; fallback for API key) ----------

  Map<String, dynamic> readSettings() {
    if (!fs.exists(settingsPath)) return {};
    try {
      return jsonDecode(fs.readAsString(settingsPath)) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void writeSettings(Map<String, dynamic> settings) {
    fs.writeAsString(settingsPath, jsonEncode(settings));
  }

  // ---------- pages ----------

  /// Filenames of all canonical page files (e.g. `my-page-abc12345.md`).
  List<String> listPageFiles() =>
      fs.listFiles(pagesDir).map((f) => p.basename(f)).toList();

  /// Raw markdown (frontmatter + body) of a page file. Throws if missing.
  String readPageFile(String filename) =>
      fs.readAsString(p.join(pagesDir, filename));

  /// All canonical pages, parsed from files.
  List<PageRecord> listPages() {
    final out = <PageRecord>[];
    for (final f in listPageFiles()) {
      try {
        final id = parseFrontmatter(readPageFile(f)).frontmatter['page_id']
            as String?;
        if (id == null) continue;
        final page = readPage(id, f);
        if (page != null) out.add(page);
      } catch (_) {}
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// Read a page's canonical file. Returns null if missing.
  PageRecord? readPage(String id, String filename) {
    final path = p.join(pagesDir, filename);
    if (!fs.exists(path)) return null;
    final doc = parseFrontmatter(fs.readAsString(path));
    final fm = doc.frontmatter;
    return PageRecord(
      id: (fm['page_id'] ?? id) as String,
      title: (fm['title'] ?? 'Untitled') as String,
      filename: filename,
      pageType: PageType.fromWire((fm['page_type'] ?? 'note') as String),
      markdown: doc.body,
      deprecated: (fm['status'] ?? 'active') == 'deprecated',
      createdAt:
          DateTime.tryParse((fm['created_at'] ?? '') as String) ?? _epoch(),
      updatedAt:
          DateTime.tryParse((fm['updated_at'] ?? '') as String) ?? _epoch(),
      claimIds: ((fm['claim_ids'] ?? const []) as List).cast<String>(),
    );
  }

  void writePage(PageRecord page) {
    final fm = <String, dynamic>{
      'page_id': page.id,
      'title': page.title,
      'page_type': page.pageType.wire,
      'status': page.deprecated ? 'deprecated' : 'active',
      'created_at': page.createdAt.toIso8601String(),
      'updated_at': page.updatedAt.toIso8601String(),
      'claim_ids': page.claimIds,
    };
    final content = renderFrontmatter(fm, page.markdown);
    fs.writeAsString(p.join(pagesDir, page.filename), content);
  }

  // ---------- claims ----------

  String claimPath(String id) => p.join(claimsDir, 'claim_$id.json');

  /// Ids of all canonical claims (parsed from `claim_<id>.json` filenames).
  List<String> listClaimIds() => fs
      .listFiles(claimsDir)
      .map((f) => p.basenameWithoutExtension(f).replaceFirst('claim_', ''))
      .toList();

  Claim? readClaim(String id) {
    final path = claimPath(id);
    if (!fs.exists(path)) return null;
    try {
      return Claim.fromJson(jsonDecode(fs.readAsString(path))
          as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void writeClaim(Claim claim) {
    fs.writeAsString(claimPath(claim.id),
        const JsonEncoder.withIndent('  ').convert(claim.toJson()));
  }

  // ---------- sources ----------

  String sourcePath(String id) => p.join(sourcesDir, '$id.md');

  /// Filenames of all source files (non-recursive — excludes `history/`).
  List<String> listSourceFiles() =>
      fs.listFiles(sourcesDir).map((f) => p.basename(f)).toList();

  SourceRecord? readSource(String id) {
    final path = sourcePath(id);
    if (!fs.exists(path)) return null;
    final doc = parseFrontmatter(fs.readAsString(path));
    final fm = doc.frontmatter;
    return SourceRecord(
      id: (fm['id'] ?? id) as String,
      title: (fm['title'] ?? 'Untitled') as String,
      url: fm['url'] as String?,
      content: doc.body,
      contentHash: (fm['content_hash'] ?? '') as String,
      version: (fm['version'] as num?)?.toInt() ?? 1,
      importedAt:
          DateTime.tryParse((fm['imported_at'] ?? '') as String) ?? _epoch(),
    );
  }

  void writeSource(SourceRecord source) {
    final fm = <String, dynamic>{
      'id': source.id,
      'title': source.title,
      'url': source.url ?? '',
      'content_hash': source.contentHash,
      'version': source.version,
      'imported_at': source.importedAt.toIso8601String(),
    };
    final content = renderFrontmatter(fm, source.content);
    fs.writeAsString(sourcePath(source.id), content);
  }

  /// Preserve an older version of a source before it is overwritten.
  void writeSourceHistory(SourceRecord source) {
    final dir = p.join(sourcesDir, 'history');
    if (!fs.exists(dir)) fs.createDir(dir);
    final fm = <String, dynamic>{
      'id': source.id,
      'title': source.title,
      'url': source.url ?? '',
      'content_hash': source.contentHash,
      'version': source.version,
      'imported_at': source.importedAt.toIso8601String(),
    };
    final content = renderFrontmatter(fm, source.content);
    fs.writeAsString(p.join(dir, '${source.id}-v${source.version}.md'), content);
  }

  List<SourceRecord> listSources() {
    final out = <SourceRecord>[];
    for (final f in listSourceFiles()) {
      final doc = parseFrontmatter(fs.readAsString(p.join(sourcesDir, f)));
      final fm = doc.frontmatter;
      if (fm['id'] == null) continue;
      out.add(SourceRecord(
        id: fm['id'] as String,
        title: (fm['title'] ?? 'Untitled') as String,
        url: fm['url'] as String?,
        content: doc.body,
        contentHash: (fm['content_hash'] ?? '') as String,
        version: (fm['version'] as num?)?.toInt() ?? 1,
        importedAt:
            DateTime.tryParse((fm['imported_at'] ?? '') as String) ?? _epoch(),
      ));
    }
    out.sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return out;
  }

  // ---------- inbox drafts ----------

  List<DraftBundle> listDrafts() {
    final out = <DraftBundle>[];
    for (final f in fs.listFiles(inboxDir)) {
      try {
        out.add(DraftBundle.fromJson(
            jsonDecode(fs.readAsString(f)) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  void writeDraft(DraftBundle draft) {
    fs.writeAsString(p.join(inboxDir, 'draft_${draft.id}.json'),
        const JsonEncoder.withIndent('  ').convert(draft.toJson()));
  }

  // ---------- ai runs ----------

  void writeAiRun(Map<String, dynamic> run) {
    final id = run['id'] as String? ?? newId();
    fs.writeAsString(p.join(aiRunsDir, '$id.json'),
        const JsonEncoder.withIndent('  ').convert(run));
  }

  List<Map<String, dynamic>> listAiRuns() {
    final out = <Map<String, dynamic>>[];
    for (final f in fs.listFiles(aiRunsDir)) {
      try {
        out.add(jsonDecode(fs.readAsString(f)) as Map<String, dynamic>);
      } catch (_) {}
    }
    out.sort((a, b) =>
        (b['ts'] ?? '').toString().compareTo((a['ts'] ?? '').toString()));
    return out;
  }
}
