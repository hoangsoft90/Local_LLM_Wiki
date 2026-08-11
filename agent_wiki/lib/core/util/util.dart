import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Slugify a title for human-readable filenames.
String slugify(String input) {
  final slug = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'page' : (slug.length > 60 ? slug.substring(0, 60) : slug);
}

/// Stable readable page filename: `<slug>-<id8>.md`
String pageFilename(String title, String id) =>
    '${slugify(title)}-${id.substring(0, 8)}.md';

/// Truncate long text for snippets.
String truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// Generate an FTS5 query: prefix-starred words joined with OR (recall-first,
/// ranked by BM25). Set [requireAll] for AND semantics (precise search).
String ftsQuery(String raw, {bool requireAll = false}) {
  final tokens = raw
      .split(RegExp(r'\s+'))
      .where((t) => t.trim().isNotEmpty)
      .map((t) => t.replaceAll(RegExp(r'[^\w]'), ''))
      .where((t) => t.isNotEmpty)
      .map((t) => '"$t"*')
      .toList();
  return tokens.join(requireAll ? ' ' : ' OR ');
}

/// Rough cost estimate helper for ai_runs logging (USD).
double estimateCostUsd(String model, int inputTokens, int outputTokens) {
  // Rough per-1M token prices; generous estimate.
  final perM = model.contains('gpt-4') || model.contains('claude')
      ? 15.0
      : model.contains('gemini')
          ? 5.0
          : 2.0;
  return (inputTokens / 1e6) * perM + (outputTokens / 1e6) * perM * 3;
}

int _randSeed = 0;

/// Deterministic pseudo-id for mock AI outputs in tests.
String mockId(String prefix) {
  _randSeed++;
  return '$prefix-${_randSeed.toString().padLeft(3, '0')}';
}

double round2(double v) => (v * 100).roundToDouble() / 100;
