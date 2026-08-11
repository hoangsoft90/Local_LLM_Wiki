import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/models/models.dart';
import '../data/wiki_repository.dart';

/// Source import (openspec: sources capability).
class ImportService {
  final WikiRepository repo;

  ImportService(this.repo);

  /// Read a file and import it as an immutable, versioned source.
  /// Returns the source record (existing no-op when content is unchanged).
  SourceRecord importFromPath(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('File not found: $path');
    }
    final content = file.readAsStringSync();
    return repo.importSource(
      title: p.basenameWithoutExtension(file.path),
      content: content,
    );
  }
}
