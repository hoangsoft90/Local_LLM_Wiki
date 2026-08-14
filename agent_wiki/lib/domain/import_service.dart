import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/models/models.dart';
import '../data/wiki_repository.dart';
import 'file_reader.dart';

/// Source import (openspec: sources capability).
class ImportService {
  final WikiRepository repo;

  ImportService(this.repo);

  /// Import raw text as an immutable, versioned source.
  SourceRecord importFromText(String title, String content) =>
      repo.importSource(title: title, content: content);

  /// Import picked-file bytes (web: file_picker returns bytes, no path).
  SourceRecord importFromBytes(String title, Uint8List bytes) =>
      importFromText(title, utf8.decode(bytes));

  /// Read a file from the filesystem (mobile/desktop only) and import it.
  SourceRecord importFromPath(String path) {
    final content = readFileString(path);
    return repo.importSource(
      title: p.basenameWithoutExtension(path),
      content: content,
    );
  }
}
