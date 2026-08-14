import 'fs_interface.dart';

/// localStorage-backed virtual filesystem (web).
///
/// Pure Dart over a `Map<String, String>` so it runs in VM tests with an
/// injected map; the web factory binds it to `window.localStorage`.
///
/// Keys are `awv1:<path>`; directories are implicit (no marker entries), so
/// `exists(dir)` is true when any key lives under it.
class LocalStorageFileSystem implements FileSystem {
  LocalStorageFileSystem(this.storage);

  final Map<String, String> storage;

  static const _prefix = 'awv1:';

  String _key(String path) => '$_prefix$path';

  @override
  bool exists(String path) {
    if (storage.containsKey(_key(path))) return true;
    final dirPrefix = '$_prefix$path/';
    return storage.keys.any((k) => k.startsWith(dirPrefix));
  }

  @override
  void createDir(String path) {
    // Directories are virtual on localStorage — nothing to persist.
  }

  @override
  List<String> listFiles(String path, {bool recursive = false}) {
    final dirPrefix = '$_prefix$path/';
    final out = <String>[];
    for (final k in storage.keys) {
      if (!k.startsWith(dirPrefix)) continue;
      final rel = k.substring(dirPrefix.length);
      if (rel.isEmpty || rel.endsWith('/')) continue;
      if (!recursive && rel.contains('/')) continue;
      out.add(k.substring(_prefix.length));
    }
    out.sort();
    return out;
  }

  @override
  String readAsString(String path) {
    final value = storage[_key(path)];
    if (value == null) {
      throw StateError('File not found: $path');
    }
    return value;
  }

  @override
  void writeAsString(String path, String content) {
    storage[_key(path)] = content;
  }

  @override
  void delete(String path) => storage.remove(_key(path));

  @override
  void deleteRecursive(String path) {
    storage.remove(_key(path));
    final dirPrefix = '$_prefix$path/';
    storage.removeWhere((k, _) => k.startsWith(dirPrefix));
  }
}
