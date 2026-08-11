import 'package:yaml/yaml.dart';

/// Parsed markdown file: frontmatter map + body (without frontmatter).
class FrontmatterDoc {
  final Map<String, dynamic> frontmatter;
  final String body;

  const FrontmatterDoc({required this.frontmatter, required this.body});
}

final _fmRegex = RegExp(r'^---\s*\n(.*?)\n---\s*\n?', dotAll: true);

/// Parse markdown with optional YAML frontmatter. Unknown keys are preserved.
FrontmatterDoc parseFrontmatter(String markdown) {
  final m = _fmRegex.firstMatch(markdown);
  if (m == null) {
    return FrontmatterDoc(frontmatter: {}, body: markdown);
  }
  Map<String, dynamic> map = {};
  try {
    final y = loadYaml(m.group(1)!);
    if (y is Map) {
      map = y.map((k, v) => MapEntry('$k', _normalize(v)));
    }
  } catch (_) {
    map = {};
  }
  return FrontmatterDoc(
    frontmatter: map,
    // Canonical stability: the blank line after `---` and trailing newlines
    // are formatting, not content — normalize them so round-trips are
    // lossless for hashing (TEST-006).
    body: markdown.substring(m.end).trim(),
  );
}

/// Render YAML frontmatter + body.
String renderFrontmatter(Map<String, dynamic> frontmatter, String body) {
  final buffer = StringBuffer('---\n');
  frontmatter.forEach((k, v) {
    buffer.write('$k: ');
    buffer.writeln(_yamlScalar(v));
  });
  buffer.writeln('---');
  final b = body.trimLeft();
  if (b.isNotEmpty) buffer.write('\n$b\n');
  return buffer.toString();
}

Object? _normalize(dynamic v) {
  if (v is YamlList) return v.map(_normalize).toList();
  if (v is YamlMap) {
    return v.map((k, vv) => MapEntry('$k', _normalize(vv)));
  }
  return v;
}

String _yamlScalar(dynamic v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return '$v';
  if (v is List) {
    return '[${v.map(_yamlScalar).join(', ')}]';
  }
  final s = '$v';
  if (s.contains(':') ||
      s.contains('#') ||
      s.startsWith('[') ||
      s.startsWith('{') ||
      s.contains('\n') ||
      s != s.trim()) {
    final quoted = s.replaceAll('"', r'\"');
    return '"$quoted"';
  }
  return s;
}
