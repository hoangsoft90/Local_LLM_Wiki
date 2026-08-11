import 'enums.dart';

/// Page record. `markdown` is the page body WITHOUT frontmatter.
class PageRecord {
  final String id;
  final String title;
  final String filename;
  final PageType pageType;
  final String markdown;
  final bool deprecated;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> claimIds;

  const PageRecord({
    required this.id,
    required this.title,
    required this.filename,
    required this.pageType,
    required this.markdown,
    this.deprecated = false,
    required this.createdAt,
    required this.updatedAt,
    this.claimIds = const [],
  });

  PageRecord copyWith({
    String? title,
    String? markdown,
    bool? deprecated,
    DateTime? updatedAt,
    List<String>? claimIds,
  }) =>
      PageRecord(
        id: id,
        title: title ?? this.title,
        filename: filename,
        pageType: pageType,
        markdown: markdown ?? this.markdown,
        deprecated: deprecated ?? this.deprecated,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        claimIds: claimIds ?? this.claimIds,
      );
}

/// Immutable versioned source (openspec: sources capability).
class SourceRecord {
  final String id;
  final String title;
  final String? url;
  final String content;
  final String contentHash;
  final int version;
  final DateTime importedAt;

  const SourceRecord({
    required this.id,
    required this.title,
    this.url,
    required this.content,
    required this.contentHash,
    required this.version,
    required this.importedAt,
  });

  String shortHash() => contentHash.length > 10
      ? contentHash.substring(0, 10)
      : contentHash;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'content': content,
        'content_hash': contentHash,
        'version': version,
        'imported_at': importedAt.toIso8601String(),
      };

  static SourceRecord fromJson(Map<String, dynamic> j) => SourceRecord(
        id: j['id'] as String,
        title: (j['title'] ?? 'Untitled') as String,
        url: j['url'] as String?,
        content: (j['content'] ?? '') as String,
        contentHash: (j['content_hash'] ?? '') as String,
        version: (j['version'] as num?)?.toInt() ?? 1,
        importedAt:
            DateTime.tryParse((j['imported_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class Evidence {
  final String id;
  final String claimId;
  final String sourceId;
  final int sourceVersion;
  final String? location;
  final String quote;

  const Evidence({
    required this.id,
    required this.claimId,
    required this.sourceId,
    required this.sourceVersion,
    this.location,
    required this.quote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'claim_id': claimId,
        'source_id': sourceId,
        'source_version': sourceVersion,
        'location': location,
        'quote': quote,
      };

  static Evidence fromJson(Map<String, dynamic> j) => Evidence(
        id: (j['id'] ?? '') as String,
        claimId: (j['claim_id'] ?? '') as String,
        sourceId: (j['source_id'] ?? '') as String,
        sourceVersion: (j['source_version'] as num?)?.toInt() ?? 1,
        location: j['location'] as String?,
        quote: (j['quote'] ?? '') as String,
      );
}

/// Canonical claim record (mirrors `claims/claim_<id>.json`).
class Claim {
  final String id;
  final String pageId;
  final String statement;
  final ClaimStatus status;
  final Author author;
  final DateTime? lastReviewedAt;
  final DateTime? validUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Evidence> evidence;
  final String? deprecatedReason;

  const Claim({
    required this.id,
    required this.pageId,
    required this.statement,
    required this.status,
    required this.author,
    this.lastReviewedAt,
    this.validUntil,
    required this.createdAt,
    required this.updatedAt,
    this.evidence = const [],
    this.deprecatedReason,
  });

  Claim copyWith({
    ClaimStatus? status,
    DateTime? lastReviewedAt,
    DateTime? updatedAt,
    List<Evidence>? evidence,
    String? deprecatedReason,
  }) =>
      Claim(
        id: id,
        pageId: pageId,
        statement: statement,
        status: status ?? this.status,
        author: author,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        validUntil: validUntil,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        evidence: evidence ?? this.evidence,
        deprecatedReason: deprecatedReason ?? this.deprecatedReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_id': pageId,
        'statement': statement,
        'status': status.wire,
        'author': author.wire,
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deprecated_reason': deprecatedReason,
        'evidence': evidence.map((e) => e.toJson()).toList(),
      };

  static Claim fromJson(Map<String, dynamic> j) => Claim(
        id: (j['id'] ?? '') as String,
        pageId: (j['page_id'] ?? '') as String,
        statement: (j['statement'] ?? '') as String,
        status: ClaimStatus.fromWire((j['status'] ?? 'unverified') as String),
        author: Author.fromWire((j['author'] ?? 'agent') as String),
        lastReviewedAt: j['last_reviewed_at'] == null
            ? null
            : DateTime.tryParse(j['last_reviewed_at'] as String),
        validUntil: j['valid_until'] == null
            ? null
            : DateTime.tryParse(j['valid_until'] as String),
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt:
            DateTime.tryParse((j['updated_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        deprecatedReason: j['deprecated_reason'] as String?,
        evidence: (j['evidence'] as List<dynamic>? ?? [])
            .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LinkRecord {
  final String sourcePageId;
  final String targetPageId;
  final LinkType linkType;
  final DateTime createdAt;

  const LinkRecord({
    required this.sourcePageId,
    required this.targetPageId,
    required this.linkType,
    required this.createdAt,
  });
}

class Revision {
  final String id;
  final RevisionTargetType targetType;
  final String targetId;
  final String patchJson;
  final DateTime createdAt;

  const Revision({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.patchJson,
    required this.createdAt,
  });
}

class WikiMeta {
  final String name;
  final DateTime createdAt;
  final String? primaryModel;
  final String? corroborationModel;

  const WikiMeta({
    required this.name,
    required this.createdAt,
    this.primaryModel,
    this.corroborationModel,
  });

  WikiMeta copyWith({
    String? name,
    String? primaryModel,
    String? corroborationModel,
  }) =>
      WikiMeta(
        name: name ?? this.name,
        createdAt: createdAt,
        primaryModel: primaryModel ?? this.primaryModel,
        corroborationModel: corroborationModel ?? this.corroborationModel,
      );
}

/// One full-text search hit.
class SearchHit {
  final String pageId;
  final String title;
  final PageType pageType;
  final String snippet;
  final bool deprecated;

  const SearchHit({
    required this.pageId,
    required this.title,
    required this.pageType,
    required this.snippet,
    this.deprecated = false,
  });
}
