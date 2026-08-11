import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/models/draft_bundle.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/util/frontmatter.dart';
import '../core/util/util.dart';

/// Canonical filesystem store (openspec: canonical-storage).
/// Layout:
///   wiki.yaml | pages/*.md | sources/*.md | `claims/claim_<id>.json` |
///   `inbox/draft_<id>.json` | .ai/runs/*.json | `.agentwiki/index.sqlite`
class WikiStore {
  final String root;

  WikiStore(this.root);

  Directory get pagesDir => Directory(p.join(root, 'pages'));
  Directory get sourcesDir => Directory(p.join(root, 'sources'));
  Directory get claimsDir => Directory(p.join(root, 'claims'));
  Directory get inboxDir => Directory(p.join(root, 'inbox'));
  Directory get aiRunsDir => Directory(p.join(root, '.ai', 'runs'));
  Directory get indexDir => Directory(p.join(root, '.agentwiki'));
  File get wikiMetaFile => File(p.join(root, 'wiki.yaml'));
  File get indexDbFile => File(p.join(indexDir.path, 'index.sqlite'));
  File get settingsFile => File(p.join(root, 'settings.json'));

  void init() {
    for (final d in [pagesDir, sourcesDir, claimsDir, inboxDir, aiRunsDir, indexDir]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
    if (!wikiMetaFile.existsSync()) {
      writeWikiMeta(WikiMeta(name: 'My Wiki', createdAt: _epoch()));
    }
  }

  DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  // ---------- wiki meta ----------

  WikiMeta readWikiMeta() {
    if (!wikiMetaFile.existsSync()) {
      return WikiMeta(name: 'My Wiki', createdAt: _epoch());
    }
    try {
      final j = jsonDecode(_yamlToJson(wikiMetaFile.readAsStringSync()));
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
    wikiMetaFile.writeAsStringSync(yaml);
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
    if (!settingsFile.existsSync()) return {};
    try {
      return jsonDecode(settingsFile.readAsStringSync())
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void writeSettings(Map<String, dynamic> settings) {
    settingsFile.writeAsStringSync(jsonEncode(settings));
  }

  // ---------- pages ----------

  String pagePath(String filename) => p.join(pagesDir.path, filename);

  /// Read a page's canonical file. Returns null if missing.
  PageRecord? readPage(String id, String filename) {
    final f = File(p.join(pagesDir.path, filename));
    if (!f.existsSync()) return null;
    final doc = parseFrontmatter(f.readAsStringSync());
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
    File(p.join(pagesDir.path, page.filename)).writeAsStringSync(content);
  }

  // ---------- claims ----------

  File claimFile(String id) => File(p.join(claimsDir.path, 'claim_$id.json'));

  Claim? readClaim(String id) {
    final f = claimFile(id);
    if (!f.existsSync()) return null;
    try {
      return Claim.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void writeClaim(Claim claim) {
    claimFile(claim.id).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(claim.toJson()));
  }

  // ---------- sources ----------

  File sourceFile(String id) => File(p.join(sourcesDir.path, '$id.md'));

  SourceRecord? readSource(String id) {
    final f = sourceFile(id);
    if (!f.existsSync()) return null;
    final doc = parseFrontmatter(f.readAsStringSync());
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
    sourceFile(source.id).writeAsStringSync(content);
  }

  /// Preserve an older version of a source before it is overwritten.
  void writeSourceHistory(SourceRecord source) {
    final dir = Directory(p.join(sourcesDir.path, 'history'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fm = <String, dynamic>{
      'id': source.id,
      'title': source.title,
      'url': source.url ?? '',
      'content_hash': source.contentHash,
      'version': source.version,
      'imported_at': source.importedAt.toIso8601String(),
    };
    final content = renderFrontmatter(fm, source.content);
    File(p.join(dir.path, '${source.id}-v${source.version}.md'))
        .writeAsStringSync(content);
  }

  List<SourceRecord> listSources() {
    final out = <SourceRecord>[];
    for (final f in sourcesDir.listSync().whereType<File>()) {
      final doc = parseFrontmatter(f.readAsStringSync());
      final fm = doc.frontmatter;
      if (fm['id'] == null) continue;
      out.add(SourceRecord(
        id: fm['id'] as String,
        title: (fm['title'] ?? 'Untitled') as String,
        url: fm['url'] as String?,
        content: doc.body,
        contentHash: (fm['content_hash'] ?? '') as String,
        version: (fm['version'] as num?)?.toInt() ?? 1,
        importedAt: DateTime.tryParse((fm['imported_at'] ?? '') as String) ??
            _epoch(),
      ));
    }
    out.sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return out;
  }

  // ---------- inbox drafts ----------

  List<DraftBundle> listDrafts() {
    final out = <DraftBundle>[];
    for (final f in inboxDir.listSync().whereType<File>()) {
      try {
        out.add(DraftBundle.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  void writeDraft(DraftBundle draft) {
    File(p.join(inboxDir.path, 'draft_${draft.id}.json'))
        .writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(draft.toJson()));
  }

  // ---------- ai runs ----------

  void writeAiRun(Map<String, dynamic> run) {
    final id = run['id'] as String? ?? newId();
    File(p.join(aiRunsDir.path, '$id.json'))
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(run));
  }

  List<Map<String, dynamic>> listAiRuns() {
    final out = <Map<String, dynamic>>[];
    for (final f in aiRunsDir.listSync().whereType<File>()) {
      try {
        out.add(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }
    out.sort((a, b) =>
        (b['ts'] ?? '').toString().compareTo((a['ts'] ?? '').toString()));
    return out;
  }
}
