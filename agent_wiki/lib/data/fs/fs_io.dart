import 'dart:io';

import 'fs_interface.dart';

/// Real filesystem backed by `dart:io` — used on Android/iOS/desktop.
class IoFileSystem implements FileSystem {
  @override
  bool exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  @override
  void createDir(String path) => Directory(path).createSync(recursive: true);

  @override
  List<String> listFiles(String path, {bool recursive = false}) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const [];
    final entries = dir
        .listSync(recursive: recursive)
        .whereType<File>()
        .map((f) => f.path)
        .toList()
      ..sort();
    return entries;
  }

  @override
  String readAsString(String path) => File(path).readAsStringSync();

  @override
  void writeAsString(String path, String content) =>
      File(path).writeAsStringSync(content);

  @override
  void delete(String path) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  @override
  void deleteRecursive(String path) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      return;
    }
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }
}

/// Factory for the io platform (selected by conditional import).
FileSystem createFileSystem() => IoFileSystem();
